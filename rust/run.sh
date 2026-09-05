#!/usr/bin/env bash
# Builds (fetching the postgres crate from crates.io on first run -- cached
# under ~/.cargo/registry, not inside this directory) and runs check via
# `cargo run --release`. Reused whether run-all.sh is invoked directly or
# via this repo's CI, so both paths share one build step.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cargo run --quiet --release --manifest-path "$DIR/Cargo.toml" -- "$1"
