# my-repository-template

## 初期設定

このリポジトリを使用する前に、以下のコマンドを実行してください。

```bash
REPO_NAME="my-awesome-project"
sed -i "s/my-repository-template/$REPO_NAME/g" \
  .devcontainer/devcontainer.json

bun install --frozen-lockfile
prek install
```

## 前提条件

### Windowsの場合

Docker Desktop をインストールし、WSL2 が有効化されている必要があります。

また、自分の環境と同じ opencode の設定を自動で反映したい場合は、以下のディレクトリにある設定ファイルを WSL2 側にコピーしておく必要があります。

- `$HOME/.local/share/opencode/auth.json`
- `$HOME/.config/opencode/oh-my-opencode.json`
- `$HOME/.config/opencode/opencode.json`
- `$HOME/.config/opencode/tui.json`

### OpenCodeの設定

このリポジトリでは OpenCode を使うことを前提としているので、`$HOME/.local/share/opencode/auth.json`が存在しないと DevContainer の作成に失敗します。
Windows は WSL2 上、Mac の場合は通常の環境にて`opencode auth login`による認証を1回以上行ってください。

もし OpenCode にて認証をしなくても使えるモデルのみを使用する場合は、空ファイルとして作成してください。

### MCPサーバーのセットアップ

環境変数`CONTEXT7_API_KEY`に Context7の API キーを設定してください。

### Dev Containerについて

このリポジトリをデフォルトの名前で clone することを想定しています。
名前を変えると動作しなくなる可能性があります。

Dev Container 起動時には、`initializeCommand` で host 側の Git worktree メタデータを検証し、コンテナ専用の `.git` / `gitdir` オーバーレイファイルを `.devcontainer/` 配下に生成します。
host 側の実際の `.git` 管理ファイルは書き換えないため、worktree は先に host 側で正しく作成してから VS Code で開いてください。

具体的には以下の条件を満たしている必要があります。

- host 側で `bash` が利用できること
- worktree を `../<repo>.worktrees/<branch-name>` に配置すること
- worktree 管理ディレクトリ名と workspace ディレクトリ名が一致していること

#### git worktreeについて

このリポジトリは`git worktree`を使用して Dev Container 環境を構築できます。

但し、VSCode 仕様の worktree ディレクトリ構造を作成してください。構造は以下の通りです。

```txt
..
├── my-repository-template
└── my-repository-template.worktrees
    ├── feat-branch1
    └── fix-branch2
```

`fix-branch2/.git` は Git worktree の管理ファイルです。Dev Container ではこの実ファイルを直接書き換えず、コンテナ内だけで使うオーバーレイファイルを mount して current worktree を参照させます。

過去バージョンの設定で `/workspace` を指す壊れた worktree メタデータが残っている場合は、main リポジトリ側で以下を実行して掃除してください。

```bash
git -C ../my-repository-template worktree prune --expire now
```

#### worktrunkを使用する場合

以下の設定を`~/.config/worktrunk`に追加します。

```txt
worktree-path = "{{ repo_path }}/../{{ repo }}.worktrees/{{ branch | sanitize }}"
```

```bash
wt switch --create feat-branch1
```
