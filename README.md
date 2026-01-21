# my-repository-template

## 初期設定

このリポジトリを使用する前に、以下のコマンドを実行してください。

```bash
bun install --frozen-lockfile
pre-commit install
```

### OpenCodeの設定

このリポジトリでは OpenCode を使うことを前提としているので、`$HOME/.local/share/opencode/auth.json`が存在しないと DevContainer の作成に失敗します。
Windows は WSL2 上、Mac の場合は通常の環境にて`opencode auth login`による認証を1回以上行ってください。

もし OpenCode にて認証をしなくても使えるモデルのみを使用する場合は、空ファイルとして作成してください。

### MCPサーバーのセットアップ

環境変数`CONTEXT7_API_KEY`に Context7の API キーを設定してください。

### Dev Containerについて

このリポジトリをデフォルトの名前で clone することを想定しています。
名前を変えると動作しなくなる可能性があります。

#### git worktreeについて

このリポジトリは`git worktree`を使用して Dev Container 環境を構築できます。

但し、VSCode 仕様の worktree ディレクトリ構造で作成する必要があります。構造は以下の通りです。

```txt
..
├── my-repository-template
└── my-repository-template.worktree
    ├── feat-branch1
    └── fix-branch2
```
