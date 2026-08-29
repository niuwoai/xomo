#!/usr/bin/env bash

set -euo pipefail

readonly app_extension='app'
readonly debug_configuration='Debug'
readonly codesign_binary='/usr/bin/codesign'
readonly entitlements_path="${SRCROOT}/veilpic/Debug.entitlements"
readonly product_path="${CODESIGNING_FOLDER_PATH}"
readonly ui_test_bundle_identifier='im.some.xomoUITests'

resign_containing_test_host() {
  local nested_product_path="$1"
  local host_app_path

  if [[ "${nested_product_path}" != *.app/* ]]; then
    return
  fi

  host_app_path="${nested_product_path%%.app/*}.app"
  if [[ ! -d "${host_app_path}" ]]; then
    echo "Missing test host app: ${host_app_path}" >&2
    exit 1
  fi

  "${codesign_binary}" \
    --force \
    --deep \
    --sign - \
    --entitlements "${entitlements_path}" \
    "${host_app_path}"
  "${codesign_binary}" --verify --deep --strict "${host_app_path}"
}

if [[ "${CONFIGURATION}" != "${debug_configuration}" ]]; then
  exit 0
fi

# The UI test runner is assembled outside the .xctest product directory. Its
# target phase runs before that outer .app is complete, so signing it here can
# only produce an invalid partial bundle. Xcode owns runner signing.
if [[ "${PRODUCT_BUNDLE_IDENTIFIER:-}" == "${ui_test_bundle_identifier}" ]]; then
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
  shopt -s nullglob
  test_bundles=("${product_path}"/Contents/PlugIns/*.xctest)
  if (( ${#test_bundles[@]} > 0 )); then
    # XCTest has already copied test bundles into its host. Xcode and the test
    # target own their signing; signing the host at this point invalidates that
    # transient assembly before the runner can launch it.
    exit 0
  fi
fi

if [[ "${WRAPPER_EXTENSION}" == "${app_extension}" ]]; then
  # XCTest copies its .xctest bundle into the host app before this phase.  Do
  # not deep-sign the host: codesign rejects that transient test plug-in as an
  # app subcomponent. The test target signs the bundle in its own phase.
  "${codesign_binary}" --force --sign - --entitlements "${entitlements_path}" "${product_path}"
else
  "${codesign_binary}" --force --deep --sign - "${product_path}"
  # Unit and UI test products live inside a host app. Re-signing only the
  # nested .xctest leaves the host's resource seal stale, so macOS terminates
  # the runner before XCTest can connect.
  resign_containing_test_host "${product_path}"
fi

"${codesign_binary}" --verify --strict "${product_path}"
