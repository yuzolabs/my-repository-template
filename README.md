# my-repository-template

開発効率を最大化するための、Dev Container、git worktree、および OpenCode を活用した開発リポジトリ用テンプレートです。

## テンプレートの使い始め方

新しいプロジェクトを開始する際は、以下の手順でこのテンプレートを使用します。

1. **GitHub でテンプレートを使用**:
   - リポジトリ画面の「Use this template」ボタンをクリックし、「Create a new repository」を選択します。
   - リポジトリ名（例: `my-app`）を入力して作成します。

2. **リポジトリのクローン**:

   ```bash
   git clone https://github.com/your-org/my-app.git
   cd my-app
   ```

3. **初期設定コマンドの実行**:
   クローンしたディレクトリで以下のコマンドを実行し、テンプレート固有の名称をプロジェクト名に置き換え、依存関係をインストールします。

   ```bash
   # リポジトリ名を取得し、devcontainer.json 内の名称を置換する
   REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
   sed -i "s/my-repository-template/$REPO_NAME/g" .devcontainer/devcontainer.json

   # 依存関係のインストール
   bun install --frozen-lockfile
   prek install
   ```

   `sed` コマンドにより、`.devcontainer/devcontainer.json` の `"name"` フィールドが `"my-repository-template"` から `"my-app"` へと自動的に更新されます。

## VS Codeでの開き方

### worktree ブランチを開く

1. 後述の「git worktree を使った並列開発の手順」に従い、worktree を作成します。
2. 作成したディレクトリ（例: `../my-app.worktrees/feat-login`）を VS Code で開きます。
3. メインリポジトリと同様に「Reopen in Container」を実行します。

> [!WARNING]
> このリポジトリにおけるDev Containerは、git worktree を前提として構成されています。そのため、main ブランチで起動しても Dev Container を起動することは出来ません。

## アプリの起動とポートアクセス

コンテナ内でアプリケーションを起動すると、VS Code が自動的にポートをホスト側へ転送します。

1. **アプリの起動**:
   コンテナ内のターミナルで開発サーバーを起動します（例: Vite を使用する場合）。

   ```bash
   bun run dev
   ```

   ターミナルには以下のような出力が表示されます。

   ```text
     VITE v5.0.0  ready in 300 ms

     ➜  Local:   http://localhost:5173/
     ➜  Network: http://172.18.0.2:5173/
   ```

2. **ポートへのアクセス**:
   - VS Code が自動的に「Open in Browser」の通知を出すので、クリックして開きます。
   - または、VS Code の「Ports」ビュー（通常はターミナルの隣）を開き、`5173` ポートの「Forwarded Address」にある地球儀アイコンをクリックするか、URL（`http://localhost:5173`）に直接アクセスします。

## git worktreeを使った並列開発の手順

複数のブランチを同時に開発する場合、`git worktree` を使うことでブランチごとに独立した Dev Container 環境を構築できます。

### 1. 新しいブランチの worktree を作成する

ホスト側のターミナル（WSL2 や macOS/Linux）で以下を実行します。

```bash
# my-app ディレクトリ内で実行
git worktree add ../my-app.worktrees/feat-login -b feat-login
```

これにより、ディレクトリ構造は以下のようになります。

```text
..
├── my-app            # メインリポジトリ（mainブランチなど）
└── my-app.worktrees
    └── feat-login    # 作成したworktree（feat-loginブランチ）
```

### 2. VS Code で worktree を開く

別の VS Code ウィンドウで `../my-app.worktrees/feat-login` を開き、「Reopen in Container」を実行します。

### 3. それぞれの環境でアプリを起動する

- メイン環境では `5173` ポートで起動して、ホスト側の `localhost:5173` でアクセスします。
- feat-login 環境でも同じく `5173` ポートで起動します。このとき VS Code が自動で競合を検知し、ホスト側では `localhost:5174` などの空いているポートへ自動転送します。

これにより、両方のコンテナ内で `bun run dev` を実行したまま、ブラウザでそれぞれの動作を並行して確認できます。

## セキュリティスキャン

危険なコードやシークレット漏洩が紛れ込むリスクを機械的に検出するため、[Semgrep](https://semgrep.dev/)（SAST）、[gitleaks](https://github.com/gitleaks/gitleaks)（シークレットスキャン）、[zizmor](https://github.com/zizmorcore/zizmor)（GitHub Actions 静的解析）を導入しています。

- **Semgrep**（コードの静的解析 / SAST）: `subprocess.call(cmd, shell=True)`、SQL インジェクションになりうる文字列結合などの危険な実装パターンを検出
- **gitleaks**（シークレットスキャン）: AWS キー、Slack トークン、Stripe の secret key などのハードコードを検出
- **zizmor**（GitHub Actions の静的解析）: `pull_request_target` による Pwn Request、キャッシュ汚染、`permissions` の過剰付与、テンプレートインジェクションといったワークフロー固有のサプライチェーンリスクを検出

> [!NOTE]
> Semgrepは`--config auto`でリポジトリの言語構成に合わせてコミュニティルールを自動選択します。gitleaksの誤検知が出た場合は `.gitleaks.toml` の `allowlist` に追記して運用してください。
> zizmorは`--persona pedantic`で厳しめの慣習・スタイル指摘まで出力します。必要に応じて変更してください。

## 前提条件

### Windowsの場合

Docker Desktop と WSL2 が必要です。

自分の環境と同じ opencode の設定を自動で反映したい場合は、以下のディレクトリにある設定ファイルを WSL2 側にコピーしておく必要があります。

- `$HOME/.local/share/opencode/auth.json`
- `$HOME/.config/opencode/oh-my-opencode.json`
- `$HOME/.config/opencode/opencode.json`
- `$HOME/.config/opencode/tui.json`

### macOS, Linuxの場合

Docker（Docker Desktop または Docker Engine）が必要です。

opencode の設定ファイルについては、ホスト側の設定をそのまま使用できます。

### OpenCodeの設定

このリポジトリでは OpenCode を使うことを前提としているので、`$HOME/.local/share/opencode/auth.json`が存在しないと Dev Container の作成に失敗します。
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

#### ポートアクセス方針

このテンプレートでは、Dev Container 内のアプリにホスト PC からアクセスする場合、Docker Compose の `ports` による固定公開ではなく、`devcontainer.json` の `forwardPorts` と VS Code の自動ポート転送を標準ルートとして扱います。

`git worktree` で複数の Dev Container を並列起動した場合でも、競合するのはホスト側のポート番号だけです。各コンテナ内では同じ `5173` や `3000` をそのまま使い、ホスト側では空いているポートへ転送することで衝突を避けます。このテンプレートでは `requireLocalPort: false` を前提にしているため、同じローカルポートを確保できない場合でも別ポートへ退避できます。

そのため、通常の開発ではアプリをコンテナ内で `0.0.0.0` に bind して起動し、VS Code の Ports ビューまたは自動転送されたローカル URL からアクセスしてください。

現在のテンプレートでは、既定でホストポートの固定公開は行いません。`.devcontainer/docker-compose.override.yml` は空の override として置いてあり、通常の開発では `forwardPorts` と VS Code の自動ポート転送だけを使います。

固定のホストポートが必要なプロダクトだけ、`.devcontainer/docker-compose.override.yml` に `ports` を追加してください。既定の `docker-compose.yml` に固定公開を入れないのは、Vite の `5173` や API の `8000` のような共通ポートが worktree 間で衝突しやすいためです。

```yaml
services:
  devcontainer:
    ports:
      - "127.0.0.1:8000:8000"
```

例えば `feat-login` worktree だけホスト側の `8001` に公開したい場合は、起動前に override の `ports` を `127.0.0.1:8001:8000` に変更してください。

```bash
# 例: 固定公開を使う場合の override
cat > .devcontainer/docker-compose.override.yml <<'EOF'
services:
  devcontainer:
    ports:
      - "127.0.0.1:8001:8000"
EOF
```

その状態で Dev Container を再作成すると、ホスト側では `http://127.0.0.1:8001` でアクセスできます。固定公開を使わない通常の開発では、複数 worktree を同時に起動しても host 側の固定ポート競合は発生しません。

#### git worktreeについて

このリポジトリは`git worktree`を使用して Dev Container 環境を構築できます。

但し、VS Code 仕様の worktree ディレクトリ構造を作成してください。構造は以下の通りです。

```txt
..
├── my-app
└── my-app.worktrees
    ├── feat-branch1
    └── fix-branch2
```

`fix-branch2/.git` は Git worktree の管理ファイルです。Dev Container ではこの実ファイルを直接書き換えず、コンテナ内だけで使うオーバーレイファイルを mount して current worktree を参照させます。

過去バージョンの設定で `/workspace` を指す壊れた worktree メタデータが残っている場合は、main リポジトリ側で以下を実行して掃除してください。

```bash
git -C ../my-app worktree prune --expire now
```

#### worktrunkを使用する場合

以下の設定を`~/.config/worktrunk`に追加します。

```txt
worktree-path = "{{ repo_path }}/../{{ repo }}.worktrees/{{ branch | sanitize }}"
```

```bash
wt switch --create feat-branch1
```

### DevContainer CLIの使い方

DevContainer CLI を使用することで、VS Code 経由の Dev Container よりも軽量かつ高速にコンテナの準備ができます。
Vibe Coding にはこちらがおすすめです。

#### Windowsの場合

Docker Desktop を起動し、以下のコマンドで Dev Container 環境を作成します。
コンテナがない場合は自動で作成します。

```batch
.\.devcontainer\scripts\devcontainer-exec.bat
```

#### macOS, Linuxの場合

```bash
.devcontainer/scripts/devcontainer-exec.sh
```
