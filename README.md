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

### 注意: devcontainer.json の手動設定

`.devcontainer/devcontainer.json` の `mounts` セクションには、リポジトリ名が含まれたパスが3箇所あります。Dev Container Spec の制限により、これらは自動的に置換できないため、上記の `sed` コマンドで手動置換が必要です。

置換対象の行:

- `"source=${localWorkspaceFolder}/../../my-repository-template,target=/workspaces/my-repository-template,..."`
- `"source=${localWorkspaceFolder}/..,target=/workspaces/my-repository-template.worktrees,..."`
- `"source=${localWorkspaceFolder}/.devcontainer/.gitdir-container,target=/workspaces/my-repository-template/.git/worktrees/..."`

その他のファイル（`docker-compose.yml`, `post-start.sh` など）は、起動時に自動的に `.env` ファイル経由で設定されます。

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

前提条件:

- host 側で `bash` が利用できること
- worktree 配置が `../<repo>.worktrees/<branch-name>` であること
- worktree 管理ディレクトリ名と workspace ディレクトリ名が一致していること

#### git worktreeについて

このリポジトリは`git worktree`を使用して Dev Container 環境を構築できます。

但し、VSCode 仕様の worktree ディレクトリ構造で作成する必要があります。構造は以下の通りです。

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
