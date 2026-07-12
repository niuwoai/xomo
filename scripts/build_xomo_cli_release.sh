#!/bin/bash

set -euo pipefail

readonly root_dir="$(cd "$(dirname "$0")/.." && pwd)"
readonly package_dir="${root_dir}/xomo-cli"
readonly output_dir="${root_dir}/dist"
readonly output_path="${output_dir}/xomo-macos-universal"

mkdir -p "${output_dir}"
swift build \
  --package-path "${package_dir}" \
  --configuration release \
  --arch arm64 \
  --arch x86_64

readonly binary_path="${package_dir}/.build/apple/Products/Release/xomo"
cp "${binary_path}" "${output_path}"
chmod 755 "${output_path}"
file "${output_path}"
"${output_path}" version
