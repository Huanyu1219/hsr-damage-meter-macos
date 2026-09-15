#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
"$root/scripts/cargo.sh" test --locked
"$root/scripts/cargo.sh" build --locked --bin fixture-roundtrip
swift test --package-path "$root/macos/HSRDamageMeter"
python_bin=${HSR_VALIDATION_PYTHON:-"$root/.tools/validation-venv/bin/python"}
"$python_bin" "$root/scripts/validate-fixtures.py"
