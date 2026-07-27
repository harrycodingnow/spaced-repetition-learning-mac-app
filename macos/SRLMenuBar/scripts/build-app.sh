#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIRECTORY="$(cd "${SCRIPT_DIRECTORY}/.." && pwd)"
CONFIGURATION="${1:-release}"
APP_NAME="SRL Menu Bar"
APP_BUNDLE="${PACKAGE_DIRECTORY}/dist/${APP_NAME}.app"

if [[ "${CONFIGURATION}" != "debug" && "${CONFIGURATION}" != "release" ]]; then
    echo "Usage: $0 [debug|release]" >&2
    exit 2
fi

swift build --package-path "${PACKAGE_DIRECTORY}" -c "${CONFIGURATION}"
BUILD_DIRECTORY="$(swift build --package-path "${PACKAGE_DIRECTORY}" -c "${CONFIGURATION}" --show-bin-path)"

EXPECTED_APP_BUNDLE="${PACKAGE_DIRECTORY}/dist/${APP_NAME}.app"
if [[ "${APP_BUNDLE}" != "${EXPECTED_APP_BUNDLE}" ]]; then
    echo "Refusing to replace an unexpected app path: ${APP_BUNDLE}" >&2
    exit 1
fi

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIRECTORY}/SRLMenuBar" "${APP_BUNDLE}/Contents/MacOS/SRLMenuBar"
cp "${PACKAGE_DIRECTORY}/Packaging/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
cp "${PACKAGE_DIRECTORY}/Packaging/AppIcon.icns" \
    "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
cp "${PACKAGE_DIRECTORY}/Packaging/AppIcon.png" \
    "${APP_BUNDLE}/Contents/Resources/AppIcon.png"
for route_resource in blind_75_route neetcode_150_route neetcode_250_route; do
    cp "${PACKAGE_DIRECTORY}/Sources/SRLMenuBar/Resources/${route_resource}.csv" \
        "${APP_BUNDLE}/Contents/Resources/${route_resource}.csv"
done

chmod +x "${APP_BUNDLE}/Contents/MacOS/SRLMenuBar"
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Built ${APP_BUNDLE}"
