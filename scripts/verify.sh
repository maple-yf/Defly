#!/usr/bin/env bash

set -euo pipefail

repository_path="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
)"
verification_path="$(mktemp -d /tmp/defly-verify.XXXXXX)"

cleanup() {
    rm -rf "$verification_path"
}
trap cleanup EXIT

cd "$repository_path"

command -v xcodegen >/dev/null
xcodegen generate
jq empty Sources/DeflyApp/Resources/Localizable.xcstrings
git diff --check

xcodebuild build \
    -quiet \
    -project Defly.xcodeproj \
    -target DeflyCoreTests \
    -configuration Debug \
    SYMROOT="$verification_path/test-products" \
    OBJROOT="$verification_path/test-objects" \
    ARCHS="$(uname -m)" \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_ALLOWED=NO

test_bundle="$verification_path/test-products/Debug/DeflyCoreTests.xctest"
test -d "$test_bundle"
DYLD_FRAMEWORK_PATH="$verification_path/test-products/Debug" \
    xcrun xctest "$test_bundle"

xcodebuild build \
    -quiet \
    -project Defly.xcodeproj \
    -target DeflyUITests \
    -configuration Debug \
    SYMROOT="$verification_path/ui-products" \
    OBJROOT="$verification_path/ui-objects" \
    ARCHS="$(uname -m)" \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_ALLOWED=NO

xcodebuild build \
    -quiet \
    -project Defly.xcodeproj \
    -scheme Defly \
    -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$verification_path/app-derived" \
    CODE_SIGNING_ALLOWED=NO

echo "Defly verification passed."
