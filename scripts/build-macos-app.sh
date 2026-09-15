#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
package="$root/macos/HSRDamageMeter"
swift build --package-path "$package" --product HSRDamageMeter -c release -j 2
bin=$(swift build --package-path "$package" -c release --show-bin-path)
destination="$root/dist/HSR Damage Meter.app"
mkdir -p "$root/dist"
staging=$(mktemp -d "$root/dist/.app-build.XXXXXX")
trap 'rm -rf "$staging"' EXIT HUP INT TERM
app="$staging/HSR Damage Meter.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
sh "$root/scripts/build-app-icon.sh" "$app/Contents/Resources/AppIcon.icns"
cp "$root/macos/Assets/MenuBarIcon.png" "$root/macos/Assets/MenuBarIcon@2x.png" "$app/Contents/Resources/"
cp "$bin/HSRDamageMeter" "$app/Contents/MacOS/HSRDamageMeter"
# SwiftPM bundle lookup includes Bundle.main.resourceURL.
for resource in "$bin"/*.bundle; do
    [ -d "$resource" ] || continue
    cp -R "$resource" "$app/Contents/Resources/"
done
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>HSRDamageMeter</string>
<key>CFBundleIdentifier</key><string>local.hsr.damage-meter</string>
<key>CFBundleName</key><string>HSR Damage Meter</string>
<key>CFBundleIconFile</key><string>AppIcon.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST
# Increment the last installed build number before signing the complete staged bundle.
/usr/bin/python3 - "$destination" "$app" <<'PYTHON'
import pathlib, plistlib, sys
old, new = (pathlib.Path(p) / "Contents/Info.plist" for p in sys.argv[1:])
number = 0
if old.exists():
    with old.open("rb") as file:
        number = int(plistlib.load(file)["CFBundleVersion"])
with new.open("rb") as file:
    info = plistlib.load(file)
info["CFBundleVersion"] = str(number + 1)
with new.open("wb") as file:
    plistlib.dump(info, file)
PYTHON
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
# Atomic exchange on macOS: a failed build never changes the installed bundle.
/usr/bin/python3 - "$app" "$destination" <<'PYTHON'
import ctypes, os, sys
source, destination = sys.argv[1:]
if os.path.exists(destination):
    libc = ctypes.CDLL(None, use_errno=True)
    rename = libc.renamex_np
    rename.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
    rename.restype = ctypes.c_int
    if rename(os.fsencode(source), os.fsencode(destination), 2) != 0:
        code = ctypes.get_errno()
        raise OSError(code, os.strerror(code))
else:
    os.rename(source, destination)
PYTHON
printf '%s\n' "$destination"
