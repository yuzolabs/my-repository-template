---
applyTo: "**/*.md"
---

# Markdownファイル用カスタムインストラクション

Markdown ファイルを編集した後は、以下のツールで検証と修正すること。

## textlint

Markdown ファイルの日本語表記やスタイルをチェックします。

```bash
bunx textlint "<markdown-file-path>"
```

問題が指摘された場合は、即座に修正し、エラーがなくなるまで繰り返し実行すること。
但し、修正が困難な場合はユーザーに報告すること。

## markdownlint

Markdown の構文とフォーマットをチェックします。

```bash
bunx markdownlint-cli2 --fix "<markdown-file-path>"
```

自動修正可能な問題は`--fix`オプションで自動的に修正されます。
