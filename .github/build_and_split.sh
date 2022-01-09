#!/usr/bin/env bash

# exit if any step fails
set -e

GITHUB_WORKSPACE=${GITHUB_WORKSPACE:-$(pwd)}

REPO_DIR=${REPO_DIR:-${GITHUB_WORKSPACE}/repo}
NIX_BUILD_RESULT_ISO_DIR="${REPO_DIR}/result/iso"
NIX_BUILD_RESULT_ISO_NAME="JohnOS-${GITHUB_SHA}.iso"
NIX_BUILD_RESULT_ISO="${NIX_BUILD_RESULT_ISO_DIR}/${NIX_BUILD_RESULT_ISO_NAME}"

SPLIT_DIR=${1:-${GITHUB_WORKSPACE}/split}

# substring extraction: https://tldp.org/LDP/abs/html/string-manipulation.html
# 12 characters should be more than enough - Linus recommends this for the
# developers of the Linux kernel
SHORT_SHA=${GITHUB_SHA:0:12}
CHECKSUM_FILE="${SPLIT_DIR}/checksums-${SHORT_SHA}.sha256"

mkdir -p "${SPLIT_DIR}"

# build ISO - output in ./result/iso/
cd "${REPO_DIR}"

echo "checking dirty working tree"
git --no-pager diff # see why it's dirty
git --no-pager status # see why it's dirty

nix build .#flash-drive-iso

tree -l -L8 ${GITHUB_WORKSPACE}

split -d -b 128MiB \
	"${NIX_BUILD_RESULT_ISO}" \
	"${SPLIT_DIR}/JohnOS-${GITHUB_REF_NAME}-${SHORT_SHA}.iso."

# generate SHA256 checksums of all relevant files
cd "${SPLIT_DIR}"
for i in $(ls *.iso.*); do sha256sum $i >> "${CHECKSUM_FILE}"; done

cd "${NIX_BUILD_RESULT_ISO_DIR}"
sha256sum "${NIX_BUILD_RESULT_ISO_NAME}"  >> "${CHECKSUM_FILE}"
