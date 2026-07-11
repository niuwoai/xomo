#!/usr/bin/env bash

set -euo pipefail

readonly app_extension='app'
readonly debug_configuration='Debug'
readonly codesign_binary='/usr/bin/codesign'
readonly entitlements_path="${SRCROOT}/veilpic/Debug.entitlements"
readonly product_path="${CODESIGNING_FOLDER_PATH}"

if [[ "${CONFIGURATION}" != "${debug_configuration}" ]]; then
  exit 0
fi

if [[ "${QPIC_SKIP_ADHOC_SIGN:-NO}" == "YES" ]]; then
  exit 0
fi

if [[ "${CODE_SIGNING_ALLOWED:-NO}" == "YES" ]]; then
  exit 0
fi

if [[ ! -d "${product_path}" ]]; then
  echo "Missing built product: ${product_path}" >&2
  exit 1
fi

if [[ "${WRAPPER_EXTENSION}" == "${app_extension}" ]]; then
  "${codesign_binary}" --force --deep --sign - --entitlements "${entitlements_path}" "${product_path}"
else
  "${codesign_binary}" --force --deep --sign - "${product_path}"
fi

"${codesign_binary}" --verify --deep --strict "${product_path}"
