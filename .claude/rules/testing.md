# テスト運用

## `run-all.sh`のスキップ/失敗判定

`run-all.sh`は各言語ディレクトリごとに、対応するランタイムが`PATH`上に
あるかを`command -v`（ODBCのみ`isql`＋`odbcinst -q -d`＋
`python3 -c 'import pyodbc'`の3点セット、Rubyのみ`ruby -e "require 'pg'"`）
で確認する。**無ければ`skip -`行を出して次の言語へ進むだけで、スクリプト
全体を失敗させない。** チェック自体が失敗した場合のみ`FAIL -`を出して
`status=1`を立て、最後にその値で`exit`する。新しい言語を追加する際も
この「ランタイム不在は握りつぶす」判定を踏襲すること——CIも手元の
devcontainerも8言語すべて入っている前提だが、それでもこの判定を外さない
（`README.md`「Why these aren't wired into a Go test suite」参照）。

## 新しい言語チェックを追加する型

既存8言語はすべて同じ構造を踏襲している。新しい言語を足す場合もこれに
合わせる:

- `<lang>/run.sh` — 依存の取得・ビルド（初回のみ、2回目以降はキャッシュ
  済みなのでスキップ）と、実際のチェックスクリプトの起動を担う。
  引数は接続文字列/DSN 1つだけを受け取る。
- `<lang>/check.<ext>` — 実際に接続し、型付き`SELECT`・DDL拒否
  （SQLSTATE `42501`）・`t(a INTEGER)`へのINSERT+COMMIT+SELECT往復を行う。
  成功したら標準出力へ`OK`を出す（`run-all.sh`はこれを見ていないが、
  他言語との対称性のために揃えている）。
- `run-all.sh`側に、ランタイム検出→実行→`ok -`/`FAIL -`/`skip -`という
  3行パターンのブロックを1つ追加する。

## gitignoreの対象

`node/node_modules/`・`java/lib/`・`java/out/`・`dotnet/bin/`・
`dotnet/obj/`・`rust/target/`はすべてオンデマンドで取得されるビルド出力・
依存で、コミットしない（`README.md`「Why these aren't wired into a Go
test suite」参照）。新しい言語を追加した際、同種の生成物が出るなら
`.gitignore`にも追記すること。

## CIとローカル実行は同じコードパス

`.github/workflows/test.yml`の`drivers`ジョブは、ランタイム一式を
セットアップしたうえで`./run-all.sh`を引数なしで呼ぶだけ——ローカルで
`go install .../execdb@latest`してから`./run-all.sh`を叩くのと完全に
同じコードパスを通る（サーバー起動・シード・各言語呼び出しのロジックを
CI用に別途持たない）。CIで何か落ちたら、まずローカルで同じコマンドを
再現できることを確認する。

## 各ドライバの技術的な発見について

Npgsqlの接続文字列オプション、psqlODBCのpg_catalog互換ビュー、PHP/Ruby
がlibpqの薄いラッパーである点、Rustの`postgres`/`tokio-postgres`crateが
見つけた2つのExecDB本体のバグ、といった技術的な深掘りは、利用者向けの
`README.md`/`README_ja.md`にすでに書いてある（このリポジトリでは
READMEが技術解説を兼ねる主要ドキュメント）。ExecDB本体側の実装に関する
記録としては
[execdbの`.claude/rules/pgwire.md`](https://github.com/amisonnet8/execdb/blob/main/.claude/rules/pgwire.md)
にも詳しく書き起こしてある。ここで重複させず、変更する際は両方を確認
すること。
