---
description: Markdownファイルが新規作成、編集された時に整形を行う
mode: subagent
permissions:
  read: allow
  list: allow
  bash: {
    "*": "deny",
    "ls": "allow",
    "pnpm install": "allow",
    "pnpm install --frozen-lockfile": "allow",
    "pnpm exec markdownlint-cli2": "allow",
    "pnpm exec textlint": "allow",
  }
  edit: allow
---

指定された Markdown ファイルに対して、markdown-format スキルを使用してフォーマットを実行します。
