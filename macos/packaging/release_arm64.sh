#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/../.." && pwd)"

# Release metadata. Change these values for the next release, or override them
# for one invocation with APP_NAME, APP_VERSION, and APP_BUILD_NUMBER.
app_name="${APP_NAME:-FlClash}"
build_name="${APP_VERSION:-0.8.95}"
build_number="${APP_BUILD_NUMBER:-2026072102}"
archive_dir="${ARCHIVE_DIR:-$project_dir/dist/macos-arm64}"

app_path=""
custom_app_path=false
signing_identity="${SIGNING_IDENTITY:--}"
skip_build=false
use_timestamp=true

usage() {
  cat <<'EOF'
Usage: bash macos/packaging/release_arm64.sh [options]

Build, thin, sign, and verify the Apple Silicon macOS app bundle.

Options:
  --app-name <name>         Product and display name. Defaults to APP_NAME.
  --identity <identity>     Code-signing identity. Defaults to SIGNING_IDENTITY
                            or '-' for local ad-hoc signing.
  --build-name <version>    Marketing version. Defaults to APP_VERSION.
  --build-number <number>  Build number. Defaults to APP_BUILD_NUMBER.
  --app <path>              App bundle to process (requires --skip-build).
  --output-dir <path>       Directory for the preserved, versioned app archive.
  --skip-build              Do not invoke Flutter; sign an existing app bundle.
  --no-timestamp            Do not request a secure timestamp for Developer ID signing.
  -h, --help                Show this help text.

Examples:
  # Local Apple Silicon build with ad-hoc signing. Change the metadata above
  # or set APP_NAME, APP_VERSION, and APP_BUILD_NUMBER before running.
  bash macos/packaging/release_arm64.sh

  # Release signing with a Developer ID certificate.
  bash macos/packaging/release_arm64.sh \
    --identity 'Developer ID Application: Example, Inc. (TEAMID)'

  # Build a separately preserved custom-branded package.
  APP_NAME=FlClash_Muyu APP_VERSION=0.8.941 APP_BUILD_NUMBER=2026072101 \
    bash macos/packaging/release_arm64.sh
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-name)
      [[ $# -ge 2 ]] || fail '--app-name requires a value'
      app_name="$2"
      shift 2
      ;;
    --identity)
      [[ $# -ge 2 ]] || fail '--identity requires a value'
      signing_identity="$2"
      shift 2
      ;;
    --build-name)
      [[ $# -ge 2 ]] || fail '--build-name requires a value'
      build_name="$2"
      shift 2
      ;;
    --build-number)
      [[ $# -ge 2 ]] || fail '--build-number requires a value'
      build_number="$2"
      shift 2
      ;;
    --app)
      [[ $# -ge 2 ]] || fail '--app requires a value'
      app_path="$2"
      custom_app_path=true
      shift 2
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || fail '--output-dir requires a value'
      archive_dir="$2"
      shift 2
      ;;
    --skip-build)
      skip_build=true
      shift
      ;;
    --no-timestamp)
      use_timestamp=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

[[ "$app_name" =~ ^[A-Za-z0-9._-]+$ ]] || fail 'app name may only contain letters, numbers, dot, underscore, and hyphen'
[[ "$build_name" =~ ^[0-9]+(\.[0-9]+){1,2}([+-][0-9A-Za-z.-]+)?$ ]] || fail 'build name must be a semantic version'
[[ "$build_number" =~ ^[0-9]+$ ]] || fail 'build number must contain only digits'

default_app_path="$project_dir/build/macos/Build/Products/Release/$app_name.app"
if [[ "$custom_app_path" == false ]]; then
  app_path="$default_app_path"
fi

if [[ "$skip_build" == false && "$custom_app_path" == true ]]; then
  fail '--app can only be used together with --skip-build'
fi

sync_project_metadata() {
  perl -0pi -e "s|^version: .*$|version: $build_name+$build_number|m" \
    "$project_dir/pubspec.yaml"
  perl -0pi -e "s|^PRODUCT_NAME = .*$|PRODUCT_NAME = $app_name|m" \
    "$project_dir/macos/Runner/Configs/AppInfo.xcconfig"
  perl -0pi -e "s|FlClash_Muyu\\.app|$app_name.app|g; s|FlClash\\.app|$app_name.app|g" \
    "$project_dir/macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme"
  perl -0pi -e "s|FlClash_Muyu\\.app|$app_name.app|g; s|FlClash\\.app|$app_name.app|g; s|INFOPLIST_KEY_CFBundleDisplayName = FlClash_Muyu;|INFOPLIST_KEY_CFBundleDisplayName = $app_name;|g; s|INFOPLIST_KEY_CFBundleDisplayName = FlClash;|INFOPLIST_KEY_CFBundleDisplayName = $app_name;|g" \
    "$project_dir/macos/Runner.xcodeproj/project.pbxproj"
  perl -0pi -e "s|^app_name: .*$|app_name: '$app_name'|m" \
    "$project_dir/distribute_options.yaml"
  perl -0pi -e "s|^title: .*$|title: $app_name|m; s|path: FlClash_Muyu\\.app|path: $app_name.app|g; s|path: FlClash\\.app|path: $app_name.app|g" \
    "$project_dir/macos/packaging/dmg/make_config.yaml"
}

run_flutter_build() {
  local -a flutter_command
  local -a build_arguments=(
    build macos --release
    --build-name "$build_name"
    --build-number "$build_number"
    --dart-define=APP_ENV=stable
  )

  if [[ -x "$project_dir/.fvm/flutter_sdk/bin/flutter" ]]; then
    flutter_command=("$project_dir/.fvm/flutter_sdk/bin/flutter")
  elif command -v fvm >/dev/null 2>&1; then
    flutter_command=(fvm flutter)
  elif command -v flutter >/dev/null 2>&1; then
    flutter_command=(flutter)
  else
    fail 'Flutter was not found. Run fvm use, or install Flutter first.'
  fi

  (
    cd "$project_dir"
    "${flutter_command[@]}" "${build_arguments[@]}"
  )
}

sign_code() {
  local target="$1"
  local -a sign_arguments=(--force --sign "$signing_identity")

  if [[ "$signing_identity" != '-' && "$use_timestamp" == true ]]; then
    sign_arguments+=(--timestamp)
  else
    sign_arguments+=(--timestamp=none)
  fi

  codesign "${sign_arguments[@]}" "$target"
}

sign_nested_code() {
  local path

  # Sign files before their containing bundles, from deepest to shallowest.
  while IFS= read -r -d '' path; do
    if file -b "$path" | grep -q 'Mach-O'; then
      sign_code "$path"
    fi
  done < <(find "$app_path/Contents" -type f -print0)

  while IFS= read -r -d '' path; do
    sign_code "$path"
  done < <(
    find "$app_path/Contents" -depth -type d \
      \( -name '*.framework' -o -name '*.app' -o -name '*.xpc' -o -name '*.appex' \) \
      -print0
  )
}

sign_app() {
  local -a sign_arguments=(--force --sign "$signing_identity")

  if [[ "$signing_identity" == '-' ]]; then
    sign_arguments+=(--timestamp=none)
  else
    sign_arguments+=(--options runtime)
    if [[ "$use_timestamp" == true ]]; then
      sign_arguments+=(--timestamp)
    else
      sign_arguments+=(--timestamp=none)
    fi
  fi

  codesign "${sign_arguments[@]}" \
    --entitlements "$project_dir/macos/Runner/Release.entitlements" \
    "$app_path"
}

archive_app() {
  local archive_zip="$archive_dir/$app_name-$build_name.app.zip"

  if [[ -e "$archive_zip" ]]; then
    rm -f "$archive_zip"
  fi

  mkdir -p "$archive_dir"
  ditto -c -k --keepParent "$app_path" "$archive_zip"
  echo "Archived app: $archive_zip"
}

sync_project_metadata
if [[ "$skip_build" == false ]]; then
  run_flutter_build
fi

[[ -d "$app_path/Contents" ]] || fail "macOS app bundle not found: $app_path"

bash "$script_dir/thin_arm64.sh" "$app_path"
sign_nested_code
sign_app

codesign --verify --deep --strict --verbose=2 "$app_path"

if find "$app_path/Contents" -type f -print0 | xargs -0 file | grep -q 'x86_64'; then
  fail 'Intel slices remain in the app bundle'
fi

echo "Release app is ready: $app_path"
echo "Signing identity: $signing_identity"
archive_app
