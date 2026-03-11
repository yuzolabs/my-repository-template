#!/bin/bash
set -e

WORKSPACE_ROOT=${WORKSPACE_ROOT:-/workspace}
WT_NAME=${1:-$localWorkspaceFolderBasename}
MAIN_REPO_PATH=${MAIN_REPO_PATH:-/workspaces/my-repository-template}

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

    # .gitファイルの内容を確認
    GITDIR_CONTENT=$(cat "$WORKSPACE_ROOT/.git")
    echo "Original .git content: $GITDIR_CONTENT"

    # worktree名を取得（コンテナ内のディレクトリ名）
    WT_BASENAME=$(basename "$WORKSPACE_ROOT")

    # Windowsパス（C:：など）が含まれているかチェック
    NEEDS_FIX=false
    if echo "$GITDIR_CONTENT" | grep -qE '^gitdir: [A-Za-z]:'; then
        echo "Windows path detected, fixing..."
        NEEDS_FIX=true
    else
        # Linuxパスの場合でも、指しているworktreeが実際に存在するか確認
        CURRENT_WT=$(echo "$GITDIR_CONTENT" | sed 's/^gitdir: //' | xargs basename)
        if [ ! -d "$MAIN_REPO_PATH/.git/worktrees/$CURRENT_WT" ]; then
            echo "Worktree '$CURRENT_WT' not found, fixing to use existing worktree..."
            NEEDS_FIX=true
        fi
    fi

    if [ "$NEEDS_FIX" = true ]; then
        # 実際に存在するworktreeを探す
        EXISTING_WT=$(ls -1 "$MAIN_REPO_PATH/.git/worktrees/" 2>/dev/null | head -1)

        if [ -n "$EXISTING_WT" ]; then
            # 正しいパスに修正
            echo "gitdir: $MAIN_REPO_PATH/.git/worktrees/$EXISTING_WT" > "$WORKSPACE_ROOT/.git"
            echo "Fixed .git content:"
            cat "$WORKSPACE_ROOT/.git"
            WT_BASENAME="$EXISTING_WT"
        else
            echo "WARNING: No existing worktree found in $MAIN_REPO_PATH/.git/worktrees/"
        fi
    fi

    # メインリポジトリ側のgitdirファイルも修正
    WT_BASENAME=$(cat "$WORKSPACE_ROOT/.git" 2>/dev/null | sed 's/^gitdir: //' | xargs basename 2>/dev/null || echo "")
    if [ -n "$WT_BASENAME" ]; then
        GITDIR_FILE="$MAIN_REPO_PATH/.git/worktrees/$WT_BASENAME/gitdir"

        if [ -f "$GITDIR_FILE" ]; then
            GITDIR_CONTENT=$(cat "$GITDIR_FILE")
            if echo "$GITDIR_CONTENT" | grep -qE ':\\\\'; then
                echo "Fixing gitdir file: $GITDIR_FILE"
                echo "$WORKSPACE_ROOT/.git" > "$GITDIR_FILE"
            fi
        fi
    fi

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
    echo "WARNING: Git status check failed, attempting repair..."
    git -C "$MAIN_REPO_PATH" worktree repair "$WORKSPACE_ROOT" 2>/dev/null || true
fi

# フックディレクトリの権限設定
if [ -d "$MAIN_REPO_PATH/.git/hooks" ]; then
    sudo chown -R node:node "$MAIN_REPO_PATH/.git/hooks" 2>/dev/null || true
fi

# pre-commitフックのインストール
if [ ! -f "$MAIN_REPO_PATH/.git/hooks/pre-commit" ]; then
    echo "Installing pre-commit hooks..."
    if git -C "$WORKSPACE_ROOT" rev-parse --git-dir > /dev/null 2>&1; then
        uv run --active prek install 2>/dev/null || echo "pre-commit install skipped"
    else
        echo "Skipping pre-commit install: Git not properly configured"
    fi
else
    echo "pre-commit hook already installed"
fi

echo "=== Dev Container Setup Complete ==="
