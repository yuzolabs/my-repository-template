#!/usr/bin/env bash
set -eu

WORKSPACE_DIR=${1:-}
WORKSPACE_NAME=${2:-}
CONTAINER_MAIN_REPO_PATH=${3:-}
CONTAINER_WORKSPACE_PATH=${4:-/workspace}

if [ -z "$WORKSPACE_DIR" ]; then
    echo "ERROR: workspace path is required" >&2
    exit 1
fi

if [ -z "$WORKSPACE_NAME" ]; then
    WORKSPACE_NAME=$(basename "$WORKSPACE_DIR")
fi

WORKSPACE_GIT_FILE="$WORKSPACE_DIR/.git"

if [ -d "$WORKSPACE_GIT_FILE" ]; then
    exit 0
fi

if [ ! -f "$WORKSPACE_GIT_FILE" ]; then
    exit 0
fi

CURRENT_HOST_GIT_FILE_CONTENT=$(tr -d '\r' < "$WORKSPACE_GIT_FILE")
CURRENT_HOST_GITDIR=${CURRENT_HOST_GIT_FILE_CONTENT#gitdir: }
CURRENT_HOST_GITDIR_NORMALIZED=${CURRENT_HOST_GITDIR//\\//}

WORKSPACE_PARENT=$(dirname "$WORKSPACE_DIR")
WORKTREE_ROOT_NAME=$(basename "$WORKSPACE_PARENT")

if [ "${WORKTREE_ROOT_NAME#*.worktrees}" = "$WORKTREE_ROOT_NAME" ]; then
    echo "ERROR: worktree workspace must live under a '*.worktrees' directory: $WORKSPACE_DIR" >&2
    exit 1
fi

REPO_NAME=${WORKTREE_ROOT_NAME%.worktrees}
MAIN_REPO_DIR=$(dirname "$WORKSPACE_PARENT")/$REPO_NAME
MAIN_REPO_GIT_DIR="$MAIN_REPO_DIR/.git"
WORKTREE_ADMIN_DIR_NAME=$(basename "$CURRENT_HOST_GITDIR_NORMALIZED")

if [ "$WORKTREE_ADMIN_DIR_NAME" != "$WORKSPACE_NAME" ]; then
    echo "ERROR: worktree admin dir '$WORKTREE_ADMIN_DIR_NAME' does not match workspace directory '$WORKSPACE_NAME'." >&2
    echo "This Dev Container configuration requires matching names for deterministic Git overlays." >&2
    exit 1
fi

EXPECTED_WORKTREE_GITDIR="$MAIN_REPO_GIT_DIR/worktrees/$WORKTREE_ADMIN_DIR_NAME"

if [ -z "$CONTAINER_MAIN_REPO_PATH" ]; then
    CONTAINER_MAIN_REPO_PATH="/workspaces/$REPO_NAME"
fi

if [ ! -d "$MAIN_REPO_GIT_DIR" ]; then
    echo "ERROR: expected main repository git directory was not found: $MAIN_REPO_GIT_DIR" >&2
    echo "Ensure worktrees are located at ../$REPO_NAME.worktrees/<branch-name>." >&2
    exit 1
fi

if command -v git >/dev/null 2>&1; then
    git -C "$MAIN_REPO_DIR" worktree repair "$WORKSPACE_DIR" >/dev/null 2>&1 || true
fi

if [ ! -d "$EXPECTED_WORKTREE_GITDIR" ]; then
    echo "ERROR: expected worktree metadata directory was not found: $EXPECTED_WORKTREE_GITDIR" >&2
    echo "Create the worktree from the main repository before reopening in Dev Container." >&2
    exit 1
fi

GENERATED_GIT_FILE="$WORKSPACE_DIR/.devcontainer/.git-container"
GENERATED_GITDIR_FILE="$WORKSPACE_DIR/.devcontainer/.gitdir-container"
EXPECTED_CONTAINER_GIT_FILE_CONTENT="gitdir: $CONTAINER_MAIN_REPO_PATH/.git/worktrees/$WORKTREE_ADMIN_DIR_NAME"
EXPECTED_CONTAINER_GITDIR_FILE_CONTENT="$CONTAINER_WORKSPACE_PATH/.git"

CURRENT_CONTAINER_GIT_FILE_CONTENT=""
if [ -f "$GENERATED_GIT_FILE" ]; then
    CURRENT_CONTAINER_GIT_FILE_CONTENT=$(tr -d '\r' < "$GENERATED_GIT_FILE")
fi

if [ "$CURRENT_CONTAINER_GIT_FILE_CONTENT" != "$EXPECTED_CONTAINER_GIT_FILE_CONTENT" ]; then
    printf '%s\n' "$EXPECTED_CONTAINER_GIT_FILE_CONTENT" > "$GENERATED_GIT_FILE"
fi

CURRENT_CONTAINER_GITDIR_FILE_CONTENT=""
if [ -f "$GENERATED_GITDIR_FILE" ]; then
    CURRENT_CONTAINER_GITDIR_FILE_CONTENT=$(tr -d '\r' < "$GENERATED_GITDIR_FILE")
fi

if [ "$CURRENT_CONTAINER_GITDIR_FILE_CONTENT" != "$EXPECTED_CONTAINER_GITDIR_FILE_CONTENT" ]; then
    printf '%s\n' "$EXPECTED_CONTAINER_GITDIR_FILE_CONTENT" > "$GENERATED_GITDIR_FILE"
fi

ENV_FILE="$WORKSPACE_DIR/.devcontainer/.env"
CONTAINER_WORKTREES_PATH="/workspaces/${REPO_NAME}.worktrees"
COMPOSE_PROJECT_NAME="$(echo "$REPO_NAME" | tr '[:upper:]' '[:lower:]')-${WORKSPACE_NAME}"

is_valid_api_host_port() {
    local port="$1"

    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        return 1
    fi

    return 0
}

list_sibling_api_host_ports() {
    local worktrees_dir="$1"
    local current_workspace_name="$2"
    local sibling_dir

    for sibling_dir in "$worktrees_dir"/*; do
        [ -d "$sibling_dir" ] || continue

        local sibling_name
        sibling_name=$(basename "$sibling_dir")
        if [ "$sibling_name" = "$current_workspace_name" ]; then
            continue
        fi

        local sibling_env_file="$sibling_dir/.devcontainer/.env"
        [ -f "$sibling_env_file" ] || continue

        local sibling_port
        sibling_port=$(tr -d '\r' < "$sibling_env_file" | sed -n 's/^API_HOST_PORT=//p' | head -n 1)

        if is_valid_api_host_port "$sibling_port"; then
            printf '%s\n' "$sibling_port"
        fi
    done
}

port_is_used_by_siblings() {
    local candidate_port="$1"
    local used_port

    while IFS= read -r used_port; do
        if [ "$used_port" = "$candidate_port" ]; then
            return 0
        fi
    done <<EOF
$2
EOF

    return 1
}

allocate_api_host_port() {
    local worktrees_dir="$1"
    local current_workspace_name="$2"
    local used_ports
    used_ports=$(list_sibling_api_host_ports "$worktrees_dir" "$current_workspace_name")

    local candidate_port=8000
    while [ "$candidate_port" -le 8999 ]; do
        if ! port_is_used_by_siblings "$candidate_port" "$used_ports"; then
            printf '%s\n' "$candidate_port"
            return 0
        fi
        candidate_port=$((candidate_port + 1))
    done

    echo "ERROR: no available API_HOST_PORT found in range 8000-8999" >&2
    exit 1
}

EXISTING_API_HOST_PORT=""
if [ -f "$ENV_FILE" ]; then
    EXISTING_API_HOST_PORT=$(tr -d '\r' < "$ENV_FILE" | sed -n 's/^API_HOST_PORT=//p' | head -n 1)
fi

SIBLING_API_HOST_PORTS=$(list_sibling_api_host_ports "$WORKSPACE_PARENT" "$WORKSPACE_NAME")

if is_valid_api_host_port "${API_HOST_PORT:-}"; then
    API_HOST_PORT_VALUE="$API_HOST_PORT"
elif is_valid_api_host_port "$EXISTING_API_HOST_PORT" && ! port_is_used_by_siblings "$EXISTING_API_HOST_PORT" "$SIBLING_API_HOST_PORTS"; then
    API_HOST_PORT_VALUE="$EXISTING_API_HOST_PORT"
else
    API_HOST_PORT_VALUE=$(allocate_api_host_port "$WORKSPACE_PARENT" "$WORKSPACE_NAME")
fi

EXPECTED_ENV_CONTENT="MAIN_REPO_PATH=${CONTAINER_MAIN_REPO_PATH}
WORKTREES_PATH=${CONTAINER_WORKTREES_PATH}
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}
API_HOST_PORT=${API_HOST_PORT_VALUE}"

CURRENT_ENV_CONTENT=""
if [ -f "$ENV_FILE" ]; then
    CURRENT_ENV_CONTENT=$(cat "$ENV_FILE" 2>/dev/null || true)
fi

if [ "$CURRENT_ENV_CONTENT" != "$EXPECTED_ENV_CONTENT" ]; then
    printf '%s\n' "$EXPECTED_ENV_CONTENT" > "$ENV_FILE"
fi

convert_wsl_path_to_windows() {
    local wsl_path="$1"
    if [[ "$wsl_path" =~ ^/mnt/([a-z])/(.*)$ ]]; then
        local drive="${BASH_REMATCH[1]}"
        local rest="${BASH_REMATCH[2]}"
        echo "${drive^^}:/${rest}"
    else
        echo "$wsl_path"
    fi
}

repair_host_git_file() {
    local git_file="$WORKSPACE_DIR/.git"

    if [ ! -f "$git_file" ] || [ -d "$git_file" ]; then
        return 0
    fi

    local current_content
    current_content=$(tr -d '\r' < "$git_file")

    if echo "$current_content" | grep -q "^gitdir: /mnt/"; then
        echo "[INFO] Repairing host .git file (converting WSL path to Windows path)..."

        local wsl_path
        wsl_path=$(echo "$current_content" | sed 's/^gitdir: //')

        local windows_path
        windows_path=$(convert_wsl_path_to_windows "$wsl_path")

        printf 'gitdir: %s\n' "$windows_path" > "$git_file"
        echo "[INFO] Host .git file repaired: $windows_path"
    fi
}

repair_host_git_file
