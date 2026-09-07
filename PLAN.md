# PLAN.md

execdb-driversの実装ログ・進捗管理。セッションをまたぐたびに「現在地」を
確認・更新すること。

## 経緯

[ExecDB](https://github.com/amisonnet8/execdb)本体の`tests/drivers/`
配下にあった、8言語（Python/Node.js/Java/.NET/ODBC/PHP/Ruby/Rust）分の
PostgreSQLドライバ接続チェックを、独立したリポジトリとして分離した
（2026-09-05）。execdb本体は「Goツールチェーンだけで完結する」という
単純さを保ち、8言語ぶんのランタイム導入・保守はこちらへ切り出す、という
判断（詳細な経緯はexecdb側の`PLAN.md`「多言語ドライバ検証を別リポジトリ
`execdb-drivers`へ分離」節、技術的な移植内容は本リポジトリ
`README.md`の「History」節を参照）。

## これまでの作業ログ

- **初回分離（2026-09-05）**: `tests/drivers/`の中身を1階層フラット化
  してコピー。`run-all.sh`のバイナリ解決を`$ROOT/bin/execdb`
  （execdb本体を`make build`した前提）から
  `$(go env GOPATH)/bin/execdb`（`go install
  github.com/amisonnet8/execdb/cmd/execdb@latest`が生成する場所）へ
  変更。各スクリプト・コメント中の自己参照パス（`tests/drivers/`
  プレフィックス、`tests/e2e.sh`への言及）を除去・書き換え。独自の
  `README.md`/`README_ja.md`（トップレベルのプロジェクト説明として
  全面書き直し）・`.gitignore`・`.github/workflows/test.yml`
  （`go install`ベース）を新設。
- **MIT license追加（2026-09-05）**: execdb本体（`amisonnet8`, 2026）と
  同じ著作権表記で`LICENSE`を追加。README.md/README_ja.mdへ
  「License」節を追記。
- **`node/package-lock.json`の同期（2026-09-05）**: `node/run.sh`の
  `npm install`実行により、ロックファイルのルートパッケージ名が
  `package.json`（`execdb-node-driver-check`）と同期された
  （旧ロックは`tests/drivers/`時代の`"node"`という古い名前・不要な
  `"license": "ISC"`のまま残っていた）。依存バージョン自体は不変。

## 今回の変更: devcontainer/Claude Codeプロジェクト設定の完全独立化（2026-09-05）

分離当初は`.devcontainer/`をexecdb側の3ファイル構成
（`devcontainer.execdb.json`/`devcontainer.drivers.json`を手動で
`devcontainer.json`へコピーしてスワップする運用）に間借りしていたが、
これをやめ、このリポジトリに完全に独立したClaude Codeプロジェクト一式
を新設した:

- `.devcontainer/devcontainer.json`・`devcontainer-lock.json`
  （execdb側の`devcontainer.drivers.json`/`devcontainer.drivers-lock.json`
  の内容をそのまま採用。Goベースイメージ＋dotnet/rustフィーチャー＋
  8言語ぶんの`postCreateCommand`）
- `.claude/settings.json`（execdbと同じ権限方針——install系・
  `curl`/`wget`・`git push`/`pull`/`fetch`/`clone`はすべて確認必須。
  run-all.shの通常実行で頻繁にinstallが走るリポジトリだが、それでも
  一括許可はしない、とユーザーと確認済み）
- `.claude/rules/testing.md`（新規）・`CLAUDE.md`（新規）

以後、execdbとexecdb-driversは完全に独立した2つのコンテナ／プロジェクト
として運用する（execdb側の`.devcontainer/`も単一構成へ戻し、
`devcontainer.drivers.json`等のdrivers用ファイルを削除済み）。

## 現在地

- 8ドライバ全チェックがローカルで動作確認済み（execdb本体の`bin/execdb`
  に対して、`devcontainer.drivers.json`ベースの環境・`devcontainer.
  execdb.json`ベースの環境どちらでも実行——後者はexecdb側のテストのみ
  対象）。
- GitHubへpush済み（`amisonnet8/execdb-drivers`）。CI
  （`.github/workflows/test.yml`）は実行トリガー済みだが、結果は
  このセッションでは未確認。

## 保留事項

- CI（GitHub Actions）の初回実行結果の確認。
- push・タグ運用（バージョニング）の方針はまだ決めていない——execdb
  本体のようなリリースタグ運用が必要かどうかは、必要になった時点で
  改めて検討する。
