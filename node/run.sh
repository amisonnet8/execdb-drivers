#!/usr/bin/env bash
# Installs node-postgres into node_modules/ (gitignored, see README.md)
# on first run, then executes check.js. Reused whether run-all.sh is
# invoked directly or via this repo's CI, so both paths share one
# install step.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -d "$DIR/node_modules/pg" ]; then
  npm --prefix "$DIR" install --no-audit --no-fund >/dev/null
fi

node "$DIR/check.js" "$1"
