#!/bin/sh
# Reproduce UI-only A/B variants from the vendored 0.2.52 source.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
variant=${1:-no-ui}
case "$variant" in no-ui|no-ui-info|control) ;; *) echo 'Usage: build-collector.sh no-ui|no-ui-info|control' >&2; exit 2;; esac
export CARGO_HOME="$root/.tools/cargo"
export RUSTUP_HOME="$root/.tools/rustup"
export PATH="$root/.tools/cross-bin:$CARGO_HOME/bin:/opt/homebrew/bin:$PATH"
export CC_x86_64_pc_windows_gnu="$root/.tools/cross-bin/clang-windows"
export AR_x86_64_pc_windows_gnu=x86_64-w64-mingw32-ar
export CARGO_TARGET_DIR="$root/.tools/veritas-build-target"
work="$root/.tools/veritas-build-$variant"
if [ -e "$work" ]; then
    echo "Build staging already exists: $work. Inspect and choose a fresh staging directory before rebuilding." >&2
    exit 1
fi
mkdir -p "$root/.tools/cross-bin"
cat > "$CC_x86_64_pc_windows_gnu" <<'CLANG'
#!/bin/sh
exec /usr/bin/clang --target=x86_64-w64-windows-gnu -fms-extensions -D_M_X64=100 -isystem /opt/homebrew/opt/mingw-w64/toolchain-x86_64/x86_64-w64-mingw32/include "$@"
CLANG
chmod +x "$CC_x86_64_pc_windows_gnu"
ln -sf /opt/homebrew/bin/x86_64-w64-mingw32-windres "$root/.tools/cross-bin/windres"
ln -sf /opt/homebrew/bin/x86_64-w64-mingw32-ar "$root/.tools/cross-bin/ar"
cp -R "$root/collector/upstream-veritas" "$work"
if [ "$variant" != control ]; then
    git -C "$work" apply "$root/collector/patches/0002-disable-overlay-initialization.patch"
fi
if [ "$variant" = no-ui-info ]; then
    git -C "$work" apply "$root/collector/patches/0001-default-info-logging.patch"
fi
cargo +nightly-2025-05-17 build --manifest-path "$work/Cargo.toml" --locked --release --target x86_64-pc-windows-gnu -j 2
mkdir -p "$root/dist/collector-$variant"
cp "$CARGO_TARGET_DIR/x86_64-pc-windows-gnu/release/veritas.dll" "$root/dist/collector-$variant/xluau.dll"
cp "$work/LICENSE" "$root/dist/collector-$variant/LICENSE"
shasum -a 256 "$root/dist/collector-$variant/xluau.dll"
