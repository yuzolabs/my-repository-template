---
applyTo: "**/*.md"
---

# Markdownファイル用カスタムインストラクション

Markdownファイルを編集した後は、以下のツールで検証と修正を行うこと。

## textlint

Markdownファイルの日本語表記やスタイルをチェックします。

```bash
pnpm exec textlint "<markdown-file-path>"
```

問題が指摘された場合は必要な修正を行い、エラーがなくなるまで繰り返し実行すること。
但し、修正が困難な場合はユーザーに報告すること。

## markdownlint

Markdownの構文とフォーマットをチェックします。

```bash
pnpm exec markdownlint-cli2 --fix "<markdown-file-path>"
```

自動修正可能な問題は`--fix`オプションで自動的に修正されます。
