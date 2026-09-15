#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ -x "$root/.tools/cargo/bin/cargo" ]; then
    export CARGO_HOME="$root/.tools/cargo"
    export RUSTUP_HOME="$root/.tools/rustup"
    export PATH="$CARGO_HOME/bin:$PATH"
fi
cd "$root/collector"
exec cargo "$@"
