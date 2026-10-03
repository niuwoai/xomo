#!/bin/bash

set -euo pipefail

readonly root_dir="$(cd "$(dirname "$0")/.." && pwd)"
readonly package_dir="${root_dir}/xomo-cli"
readonly output_dir="${root_dir}/dist"
readonly output_path="${output_dir}/xomo-macos-universal"

readonly build_arguments=(
  --package-path "${package_dir}"
  --configuration release
  --arch arm64
  --arch x86_64
)
swift build "${build_arguments[@]}"

binary_directory="$(swift build "${build_arguments[@]}" --show-bin-path)"
readonly binary_directory
readonly binary_path="${binary_directory}/xomo"
if [[ ! -x "${binary_path}" ]]; then
  printf 'Missing built CLI: %s\n' "${binary_path}" >&2
  exit 1
fi
source_version="$(sed -n 's/^private let xomoCLIVersion = "\([^"]*\)"$/\1/p' "${package_dir}/Sources/XomoCLI/main.swift")"
built_version="$("${binary_path}" version)"
readonly source_version built_version
if [[ -z "${source_version}" || "${built_version}" != "${source_version}" ]]; then
  printf 'CLI version mismatch: expected %s, got %s\n' "${source_version}" "${built_version}" >&2
  exit 1
fi
lipo "${binary_path}" -verify_arch arm64
lipo "${binary_path}" -verify_arch x86_64

mkdir -p "${output_dir}"
staged_output="$(mktemp "${output_dir}/.xomo-cli.XXXXXX")"
readonly staged_output
trap 'rm -f -- "${staged_output}"' EXIT
cp "${binary_path}" "${staged_output}"
chmod 755 "${staged_output}"
mv -f "${staged_output}" "${output_path}"
file "${output_path}"
"${output_path}" version
