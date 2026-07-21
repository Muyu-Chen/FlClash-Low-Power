#!/usr/bin/env bash
set -euo pipefail

app_name="${APP_NAME:-FlClash}"
app_path="${1:-build/macos/Build/Products/Release/$app_name.app}"

if [[ ! -d "$app_path/Contents" ]]; then
  echo "macOS app bundle not found: $app_path" >&2
  exit 1
fi

while IFS= read -r -d '' binary; do
  archs="$(lipo -archs "$binary" 2>/dev/null || true)"
  if [[ -z "$archs" || "$archs" != *arm64* || "$archs" != *x86_64* ]]; then
    continue
  fi

  temp_path="${binary}.arm64"
  lipo "$binary" -thin arm64 -output "$temp_path"
  mv "$temp_path" "$binary"
  echo "Thinned x86_64 slice: $binary"
done < <(find "$app_path/Contents" -type f -print0)

# Thinning invalidates signatures on changed frameworks. The local release
# configuration uses ad-hoc signing; distribution builds should sign again
# with their configured Developer ID after this step.
codesign --force --deep --sign - "$app_path"
