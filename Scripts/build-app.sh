#!/usr/bin/env bash
#
# Assembles Islet.app from the SwiftPM build product.
#
# Islet is built with SwiftPM rather than an .xcodeproj so the whole project stays reviewable
# as plain text and builds from a terminal with nothing but the Xcode command line tools. The
# cost is that SwiftPM emits a bare executable, so the .app wrapper is assembled here.
#
# Usage:  Scripts/build-app.sh [debug|release]

set -euo pipefail

CONFIGURATION="${1:-release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Islet"
DIST="${ROOT}/dist"
APP="${DIST}/${APP_NAME}.app"

echo "==> Building ${APP_NAME} (${CONFIGURATION})"
swift build --package-path "${ROOT}" -c "${CONFIGURATION}"

BINARY="$(swift build --package-path "${ROOT}" -c "${CONFIGURATION}" --show-bin-path)/${APP_NAME}"
if [[ ! -x "${BINARY}" ]]; then
	echo "error: built executable not found at ${BINARY}" >&2
	exit 1
fi

echo "==> Assembling ${APP}"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

cp "${BINARY}" "${APP}/Contents/MacOS/${APP_NAME}"
cp "${ROOT}/Resources/Info.plist" "${APP}/Contents/Info.plist"

# Ad-hoc signature. Enough for the app to launch locally; a real Developer ID signature and
# notarisation are only needed for distributing builds to other people.
echo "==> Signing (ad-hoc)"
codesign --force --sign - --timestamp=none "${APP}" >/dev/null 2>&1

echo "==> Done: ${APP}"
