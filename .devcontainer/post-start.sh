#!/bin/bash
set -e

MAIN=/workspaces/my-repository-template
WT_NAME=${1:-$localWorkspaceFolderBasename}
WT=/workspaces/my-repository-template.worktrees/$WT_NAME

# 検証と早期終了
[ -n "$WT_NAME" ] || { echo "Error: Worktree name not provided" >&2; exit 1; }
[ -d "$MAIN/.git" ] && [ -d "$WT" ] || exit 0

# safe.directory設定
git config --global --add safe.directory "$MAIN" 2>/dev/null || true
git config --global --add safe.directory "$WT" 2>/dev/null || true

# Windowsパス修正（メインリポジトリ側）
GITDIR_FILE="$MAIN/.git/worktrees/$WT_NAME/gitdir"
[ -f "$GITDIR_FILE" ] && grep -q ':\\' "$GITDIR_FILE" 2>/dev/null && echo "$WT/.git" > "$GITDIR_FILE"

# Windowsパス修正（worktree側）
WT_DOTGIT="$WT/.git"
[ -f "$WT_DOTGIT" ] && grep -q ':\\' <(cut -d' ' -f2 "$WT_DOTGIT") 2>/dev/null && echo "gitdir: $MAIN/.git/worktrees/$WT_NAME" > "$WT_DOTGIT"

# worktree修復（Git 2.47+前提で--relative-paths直接使用）
git -C "$MAIN" worktree repair --relative-paths "$WT" 2>/dev/null || git -C "$MAIN" worktree repair "$WT"

# フック設定
[ -d "$MAIN/.git/hooks" ] && sudo chown -R node:node "$MAIN/.git/hooks"
[ ! -f "$MAIN/.git/hooks/pre-commit" ] && uv run --active pre-commit install 2>/dev/null || true

echo "Setup complete"
