#!/bin/bash
set -e

WORKSPACE_ROOT=${WORKSPACE_ROOT:-/workspace}
WT_NAME=${1:-$(basename "$WORKSPACE_ROOT")}
MAIN_REPO_PATH=${MAIN_REPO_PATH}

echo "=== Dev Container Setup Start ==="
echo "Workspace: $WORKSPACE_ROOT"
echo "Worktree name: $WT_NAME"
echo "Main repo: $MAIN_REPO_PATH"

# メインリポジトリが正しくマウントされているか確認
if [ ! -d "$MAIN_REPO_PATH/.git" ] && [ ! -f "$MAIN_REPO_PATH/.git" ]; then
    echo "ERROR: Main repository not found at $MAIN_REPO_PATH"
    echo "Please ensure the repository is cloned at the expected location."
    exit 1
fi

# worktreeの検出（/workspace/.gitファイルが存在するか）
if [ -f "$WORKSPACE_ROOT/.git" ]; then
    echo "Detected worktree at: $WORKSPACE_ROOT"
    GITDIR_CONTENT=$(cat "$WORKSPACE_ROOT/.git")
    echo "Current .git content: $GITDIR_CONTENT"

    # safe.directory設定
    git config --global --add safe.directory "$WORKSPACE_ROOT" 2>/dev/null || true
fi

# メインリポジトリのsafe.directory設定
git config --global --add safe.directory "$MAIN_REPO_PATH" 2>/dev/null || true

# Gitが正しく機能するか確認
echo "Verifying git configuration..."
if git -C "$WORKSPACE_ROOT" status > /dev/null 2>&1; then
    echo "Git status: OK"
else
    echo "ERROR: Git status check failed. initializeCommand did not produce a valid container worktree mapping." >&2
    echo "Reopen the Dev Container after running the worktree from the expected ../<repo>.worktrees/<branch> layout." >&2
    exit 1
fi

# フックディレクトリの権限設定
if [ -d "$MAIN_REPO_PATH/.git/hooks" ]; then
    sudo chown -R node:node "$MAIN_REPO_PATH/.git/hooks" 2>/dev/null || true
fi

# pre-commit hook installation (async - runs in background)
if [ ! -f "$MAIN_REPO_PATH/.git/hooks/pre-commit" ]; then
    echo "Installing pre-commit hooks in background..."
    (
        if git -C "$WORKSPACE_ROOT" rev-parse --git-dir > /dev/null 2>&1; then
            cd "$WORKSPACE_ROOT"
            uv run --active prek install 2>&1 | tee /tmp/prek-install.log
            echo "pre-commit hooks installed successfully" >> /tmp/prek-install.log
        else
            echo "Skipping pre-commit install: Git not properly configured" >> /tmp/prek-install.log
        fi
    ) &
    disown
else
    echo "pre-commit hook already installed"
fi

echo "=== Dev Container Setup Complete ==="
