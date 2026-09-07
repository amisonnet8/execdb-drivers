# CLAUDE.md

このファイルは execdb-drivers プロジェクトで作業する際、Claude Code が
常に踏まえるべき前提を示す。

## execdb-driversとは

[ExecDB](https://github.com/amisonnet8/execdb)向けの、言語横断ドライバ
テストスイート。psycopg2/node-postgres/pgJDBC/Npgsql/psqlODBC/
PDO_PGSQL/`pg` gem/Rust `postgres`crateの8ドライバが、それぞれ自身の
デフォルト設定のままExecDBのpgwire実装へ接続できることを検証する。
元はexecdb本体の`tests/drivers/`だったが、別リポジトリへ分離した
（詳細は`README.md`の「History」節、execdb側の
`.claude/rules/testing.md`参照）。

## 参照すべきファイル

作業を始める前に、以下を確認すること。

- **`README.md`/`README_ja.md`** — このリポジトリの主要ドキュメント。
  各ドライバの実行方法・技術的な深掘り（Npgsqlの接続文字列オプション、
  psqlODBCのpg_catalog対応、Rustが見つけた2つのExecDB本体のバグ等）を
  兼ねる。execdb本体のような別建ての仕様書は無い——このリポジトリの
  スコープが「8言語分のチェックスクリプト＋`run-all.sh`」に閉じており、
  READMEで説明しきれる規模のため。
- **`PLAN.md`** — 実装ログ・現在地・保留事項。セッションをまたぐたびに
  「現在地」を確認・更新すること。
- **`.claude/rules/testing.md`** — `run-all.sh`のスキップ/失敗判定、
  新しい言語チェックを追加する際の型、gitignoreの対象、CIとローカル
  実行が同じコードパスを通ることについて。

## 開発の進め方

- 新しい言語のチェックを追加する場合は、`.claude/rules/testing.md`
  「新しい言語チェックを追加する型」に従い、既存8言語と同じ構造
  （`<lang>/run.sh`＋`<lang>/check.<ext>`）を踏襲する。
- 変更後は`./run-all.sh`（`go install github.com/amisonnet8/execdb/cmd/execdb@latest`
  で取得したバイナリ、またはローカルでビルドしたexecdbバイナリのパスを
  明示的に渡してもよい）で実際に動作確認すること。判断に迷ったら
  実行する側に倒す。

## 権限・自動化について

`.claude/settings.json`により、`git push`/`pull`/`fetch`/`clone`、
`curl`/`wget`、パッケージインストール系コマンド（`*install*`, `go get`）は
実行前に確認を求める設定になっている。**このリポジトリは`run-all.sh`の
通常実行だけでnpm/pip/gem/cargo/dotnet/curlによる依存取得が頻繁に走るが、
それでも確認なしでの一括許可はしない**（execdb本体と同じ方針、
ユーザーとの相談で確定）。確認を求められた場合、無理に実行しようとせず、
指示を仰ぐこと。

## ルール・スキルの提案

作業を進める中で、新しいルールにした方がよさそうな知見（同じ種類の
判断や落とし穴に複数回遭遇した等）に気づいたら、都度こちらから提案する
こと（提案するだけで、勝手に作成・適用はしない）。このリポジトリは
規模が小さいため、`.claude/rules/testing.md`1本に集約する方針を当面は
維持し、内容が肥大化・性質が明確に分かれてきた場合にのみファイル分割を
提案する。
