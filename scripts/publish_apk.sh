#!/usr/bin/env bash
# Build the release APK and publish it for in-app updates and share-link downloads.
#
#   scripts/publish_apk.sh            # build + publish the version currently in mobile/pubspec.yaml
#   scripts/publish_apk.sh --bump     # increment the build number (+N) first, then build + publish
#
# The app compares its build number with backend/media/apk/version.json and offers the update
# when the published one is higher, so every published build needs a new build number.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE="$ROOT/mobile"
OUT="$ROOT/backend/media/apk"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

if [[ "${1:-}" == "--bump" ]]; then
  python3 - "$MOBILE/pubspec.yaml" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
m = re.search(r'^version:\s*([\d.]+)\+(\d+)\s*$', s, re.M)
s = s[:m.start()] + f"version: {m.group(1)}+{int(m.group(2)) + 1}" + s[m.end():]
open(p, 'w').write(s)
PY
fi

VERSION_LINE="$(grep -E '^version:' "$MOBILE/pubspec.yaml" | head -1)"
VERSION_NAME="$(echo "$VERSION_LINE" | sed -E 's/version:\s*([0-9.]+)\+([0-9]+).*/\1/')"
VERSION_CODE="$(echo "$VERSION_LINE" | sed -E 's/version:\s*([0-9.]+)\+([0-9]+).*/\2/')"
echo "Building PlateFlow $VERSION_NAME ($VERSION_CODE)…"

(cd "$MOBILE" && flutter build apk --release)

APK="$MOBILE/build/app/outputs/flutter-apk/app-release.apk"
mkdir -p "$OUT"
cp "$APK" "$OUT/plateflow.apk.tmp"
SHA="$(sha256sum "$OUT/plateflow.apk.tmp" | cut -d' ' -f1)"
mv "$OUT/plateflow.apk.tmp" "$OUT/plateflow.apk"
cat > "$OUT/version.json" <<JSON
{"version_code": $VERSION_CODE, "version_name": "$VERSION_NAME", "sha256": "$SHA", "published_at": "$(date -u +%FT%TZ)"}
JSON
echo "Published $VERSION_NAME ($VERSION_CODE) -> $OUT/plateflow.apk"
cat "$OUT/version.json"
