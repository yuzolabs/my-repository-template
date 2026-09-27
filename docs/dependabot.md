# Dependabot の自動更新

## 更新方針

`.github/dependabot.yml` で、次の依存関係を毎週確認します。
通常のバージョン更新には、公開直後の取り込みを避けるため、7 日間の cooldown を設定しています。
この待機期間はセキュリティ更新には適用されません。

- Bun: `package.json` と `bun.lock`
- uv: `pyproject.toml` と `uv.lock`
- GitHub Actions: `.github/workflows/` のアクション参照
- Docker: `.devcontainer/Dockerfile` のベースイメージ
- pre-commit: `.pre-commit-config.yaml` のフック参照

patch・minor 更新は、必須 CI の成功後に squash merge します。
major 更新も PR を作成しますが、自動マージは有効化せず、所有者が手動で確認します。
更新種別が不明な場合も手動確認が必要です。PR のタイトルやラベルは判定に使いません。
Dockerfile 内のインストールコマンドなど、Dependabot が認識しないバージョン指定は対象外です。

## 自動マージの権限

個人所有の public リポジトリで、所有者だけが Write 以上の権限を持つことを前提としています。
GitHub の標準権限では、Write 権限から自動マージの有効化だけを禁止できません。
所有者以外の共同作業者、GitHub App、デプロイキーに書き込み権限を付与しないでください。
所有者の PAT なども、ほかの利用者やワークフローに渡さないでください。

書き込み権限を持つワークフローは、`.github/workflows/dependabot-auto-merge.yml` だけです。
それ以外の CI は読み取り専用です。Actions の既定トークン権限も読み取り専用を維持します。
第三者の fork にあるワークフローへ書き込みトークンやシークレットを渡してはいけません。

`github-actions[bot]` という名前だけでは、実行元ワークフローを識別できません。
ワークフローの追加・変更時には `permissions` とトリガーを所有者が確認してください。
リポジトリを Organization に移す場合や Write 権限を追加する場合は、権限設計の見直しが必要です。
Organization 所有のリポジトリでは、今回の自動マージ用ジョブは実行しません。

## 安全性の確認

自動マージ用ワークフローは `pull_request_target` で起動し、GitHub API だけを操作します。
PR のコードの checkout、依存関係のインストール、キャッシュの復元は行いません。
使用するアクションはコミット SHA に固定しています。

有効化の前に、次の条件を確認します。

- PR 作成者が `dependabot[bot]` で、head と base がこのリポジトリにある。
- 全コミットの作成者が Dependabot で、GitHub による署名検証が成功している。
- 検証した末尾のコミットとイベントの head SHA が一致している。
- Dependabot のメタデータが patch または minor を示している。
- GitHub Actions 発行の `dependency-update-ci` を必須とする Ruleset が有効になっている。
- Ruleset で、マージ前に main の最新状態を取り込むことが必須になっている。

API の失敗や設定不足があれば、有効化せずに失敗します。
`--match-head-commit` によって古いイベントからのマージ操作を防ぎ、`--admin` は使いません。
所有者が手動で有効化した自動マージを、このワークフローが取り消すことはありません。

## 必須 CI

`dependency-update-ci` は、以下のすべてが成功した場合だけ成功します。
失敗・キャンセル・スキップされたジョブがあれば、マージを許可しません。

- `gitleaks`: シークレットスキャン
- `semgrep`: 静的解析
- `zizmor`: Actions の静的解析
- `dependency-validation`: ロックファイルの整合性、ツールの起動、自動マージのガードのテスト

Dependabot の PR でもセキュリティスキャンを省略しません。
機能テストやコンテナのビルドテストは含まれないため、プロジェクト固有のテストは別途追加してください。
追加した必須ジョブは、集約ジョブの `needs` にも含めてください。

## GitHub 側の設定

リポジトリの設定は、テンプレートから作成したリポジトリには引き継がれません。
新しいリポジトリでは、所有者が以下を設定してください。

1. 所有者以外に Write 以上の権限がないことを確認する。Settings の Collaborators、Deploy keys、GitHub Apps も確認する。
2. Settings → Actions → General で、既定の Workflow permissions を読み取り専用にする。
3. Settings → General で、Allow auto-merge と Allow squash merging を有効にする。
4. main への変更に PR を必須とする Ruleset を設定する。
5. 必須 CI 用の Ruleset を、次のコマンドで追加する。

   ```bash
   gh api --method POST repos/OWNER/REPO/rulesets \
     --input .github/rulesets/dependency-update-ci.json
   ```

必須 CI 用の Ruleset にはバイパス対象を設定しません。
既存の `dont-push-main` Ruleset は変更せず、両方を適用します。
必須チェックの発行元は GitHub Actions App（ID: `15368`）に限定しています。

設定は GitHub.com の main ブランチを対象としています。
同名 Ruleset がある場合は重複作成せず、既存 Ruleset を更新してください。
新しい必須チェックがない PR は、この設定を追加した時点からマージできなくなります。
導入 PR 自体で `dependency-update-ci` を成功させてから、main にマージしてください。
マージ後、Dependabot の PR で CI と自動マージの動作を確認します。

既存のレビュー必須ルールは解除しません。
CODEOWNERS などによる承認が必要な場合は、その条件も満たしてからマージされます。

## ローカルでの検証

```bash
uv run --no-project --with pyyaml==6.0.3 python -B -m unittest discover -s .github/tests -v
uvx zizmor --persona pedantic .github/workflows
```

テストは `gh` をモック化するため、GitHub の認証情報やリポジトリ設定を変更しません。
Bash と jq が必要です。
