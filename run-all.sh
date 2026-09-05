#!/usr/bin/env bash
# run-all.sh -- runs every available driver check
# (README.md: python/node/java/dotnet/odbc/php/ruby/rust) against a throwaway
# ExecDB server seeded with table t(a INTEGER), skipping any driver whose
# runtime isn't installed. Invoked identically whether run locally or from
# this repo's own CI (.github/workflows/test.yml), so the server-setup
# logic only lives in one place.
#
# Usage: run-all.sh [BIN] [PORT]
#   BIN  path to an ExecDB binary to copy and seed (default: the one
#        `go install github.com/amisonnet8/execdb/cmd/execdb@latest`
#        produces, i.e. "$(go env GOPATH)/bin/execdb"). The original is
#        never touched -- this script always operates on a scratch copy
#        (anything involving .overwrite does, per execdb's own
#        .claude/rules/testing.md).
#   PORT TCP port for the throwaway server (default: 15538).
set -euo pipefail

DRIVERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${1:-$(go env GOPATH)/bin/execdb}"
PORT="${2:-15538}"

[ -x "$BIN" ] || { echo "run-all.sh: $BIN not found or not executable; run 'go install github.com/amisonnet8/execdb/cmd/execdb@latest' first" >&2; exit 1; }

WORK="$(mktemp -d)"
pid=""
cleanup() {
  [ -n "$pid" ] && kill "$pid" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

cp "$BIN" "$WORK/pgdrivers"
printf 'CREATE TABLE t(a INTEGER);\n.overwrite\n' | "$WORK/pgdrivers" >/dev/null

(cd "$WORK" && exec "$WORK/pgdrivers" -n -p "127.0.0.1:$PORT" -q) >/dev/null 2>&1 &
pid=$!

tries=100
while ! (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; do
  tries=$((tries - 1))
  [ "$tries" -gt 0 ] || { echo "run-all.sh: timed out waiting for 127.0.0.1:$PORT to accept connections" >&2; exit 1; }
  sleep 0.1
done
# Braced so 2>/dev/null (silencing a possible "Bad file descriptor" from
# closing fd 3) scopes to just this fd-close attempt -- a bare
# "exec 3>&- 3<&- 2>/dev/null" (no braces) would apply that redirect to
# the *current shell* for the rest of the script, permanently swallowing
# every later stderr message (every driver's own FAIL echo, and any
# crash output a driver process itself writes to stderr) without any
# error of its own (discovered in phase 4 Step 7 via the .NET/Npgsql
# check: its "Unhandled exception" trace, needed to diagnose the missing
# ServerCompatibilityMode workaround below, was silently disappearing).
{ exec 3>&- 3<&-; } 2>/dev/null || true

status=0

if command -v python3 >/dev/null 2>&1 && python3 -c 'import psycopg2' >/dev/null 2>&1; then
  if python3 "$DRIVERS_DIR/python/check.py" "host=127.0.0.1 port=$PORT user=any dbname=any"; then
    echo "ok - python (psycopg2)"
  else
    echo "FAIL - python (psycopg2)" >&2
    status=1
  fi
else
  echo "skip - python (python3/psycopg2 not available)"
fi

if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  if bash "$DRIVERS_DIR/node/run.sh" "postgres://any@127.0.0.1:$PORT/any"; then
    echo "ok - node (node-postgres)"
  else
    echo "FAIL - node (node-postgres)" >&2
    status=1
  fi
else
  echo "skip - node (node/npm not available)"
fi

if command -v java >/dev/null 2>&1 && command -v javac >/dev/null 2>&1; then
  if bash "$DRIVERS_DIR/java/run.sh" "jdbc:postgresql://127.0.0.1:$PORT/any?user=any"; then
    echo "ok - java (pgJDBC)"
  else
    echo "FAIL - java (pgJDBC)" >&2
    status=1
  fi
else
  echo "skip - java (java/javac not available)"
fi

# Server Compatibility Mode=NoTypeLoading: unlike the other three drivers
# above, Npgsql's default connection flow is not just "connect and query"
# -- it first bootstraps a type catalog via a batch of SELECTs against
# pg_type/pg_namespace/pg_class/pg_proc/pg_range/pg_attribute/pg_enum plus
# a bare "SELECT version()" (README.md's Npgsql caveat).
# SQLite has none of those, so the batch fails outright and the connection
# itself never completes without this. It is a standard, Npgsql-native
# connection-string option (not an ExecDB-specific patch) for exactly this
# situation -- the same one CockroachDB/Redshift-style "wire-compatible
# but not real Postgres" backends document for Npgsql users.
if command -v dotnet >/dev/null 2>&1; then
  if bash "$DRIVERS_DIR/dotnet/run.sh" "Host=127.0.0.1;Port=$PORT;Username=any;Database=any;Server Compatibility Mode=NoTypeLoading"; then
    echo "ok - dotnet (Npgsql)"
  else
    echo "FAIL - dotnet (Npgsql)" >&2
    status=1
  fi
else
  echo "skip - dotnet (dotnet not available)"
fi

# psqlODBC (via pyodbc) needs both a driver manager (unixODBC's "isql" is
# its own presence check here) and the PostgreSQL ODBC driver itself
# registered with it (odbcinst -q -d lists installed drivers by name).
if command -v isql >/dev/null 2>&1 && odbcinst -q -d 2>/dev/null | grep -qi postgresql && python3 -c 'import pyodbc' >/dev/null 2>&1; then
  if python3 "$DRIVERS_DIR/odbc/check.py" "Driver=PostgreSQL Unicode;Server=127.0.0.1;Port=$PORT;Database=any;Uid=any;Pwd=;"; then
    echo "ok - odbc (psqlODBC)"
  else
    echo "FAIL - odbc (psqlODBC)" >&2
    status=1
  fi
else
  echo "skip - odbc (unixODBC/psqlODBC/pyodbc not available)"
fi

if command -v php >/dev/null 2>&1 && php -m | grep -qi '^pdo_pgsql$'; then
  if php "$DRIVERS_DIR/php/check.php" "pgsql:host=127.0.0.1;port=$PORT;dbname=any;user=any"; then
    echo "ok - php (PDO_PGSQL)"
  else
    echo "FAIL - php (PDO_PGSQL)" >&2
    status=1
  fi
else
  echo "skip - php (php/pdo_pgsql not available)"
fi

if command -v ruby >/dev/null 2>&1 && ruby -e "require 'pg'" >/dev/null 2>&1; then
  if ruby "$DRIVERS_DIR/ruby/check.rb" "host=127.0.0.1 port=$PORT dbname=any user=any"; then
    echo "ok - ruby (pg gem)"
  else
    echo "FAIL - ruby (pg gem)" >&2
    status=1
  fi
else
  echo "skip - ruby (ruby/pg gem not available)"
fi

if command -v cargo >/dev/null 2>&1; then
  if bash "$DRIVERS_DIR/rust/run.sh" "host=127.0.0.1 port=$PORT dbname=any user=any"; then
    echo "ok - rust (postgres crate)"
  else
    echo "FAIL - rust (postgres crate)" >&2
    status=1
  fi
else
  echo "skip - rust (cargo not available)"
fi

exit "$status"
