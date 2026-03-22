#!/bin/bash
# DevContainer 自動セットアップスクリプト
# postCreateCommand と手動実行の両方で使用

set -e

echo "=== DevContainer Auto Setup ==="
echo "Workspace: /workspace"

# bun install（冪等性チェック：node_modules が空なら実行）
if [ -d /workspace/node_modules ] && [ -n "$(ls -A /workspace/node_modules 2>/dev/null)" ]; then
    echo "✓ node_modules already populated, skipping bun install"
else
    echo "→ Installing bun dependencies..."
    cd /workspace
    # Fix ownership of node_modules volume (created as root by Docker)
    sudo chown -R node:node /workspace/node_modules 2>/dev/null || true
    if [ -f bun.lock ] || [ -f bun.lockb ]; then
        bun install --frozen-lockfile
    else
        bun install
    fi
    echo "✓ bun install completed"
fi

# uv cache 権限修正
if [ -d /home/node/.cache/uv ]; then
    sudo chown -R node:node /home/node/.cache/uv 2>/dev/null || true
fi

# uv sync
echo "→ Setting up Python environment (uv sync)..."
cd /workspace
uv sync
echo "✓ uv sync completed"

echo "=== Auto Setup Complete ==="
