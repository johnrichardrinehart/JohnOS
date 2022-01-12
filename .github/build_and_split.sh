#!/usr/bin/env bash

# exit if any step fails
#set -e

GITHUB_WORKSPACE=${GITHUB_WORKSPACE:-$(pwd)}

REPO_DIR=${REPO_DIR:-${GITHUB_WORKSPACE}/repo}
NIX_BUILD_RESULT_ISO_DIR="${REPO_DIR}/result/iso"

SPLIT_DIR=${1:-${GITHUB_WORKSPACE}/split}

# substring extraction: https://tldp.org/LDP/abs/html/string-manipulation.html
# 12 characters should be more than enough - Linus recommends this for the
# developers of the Linux kernel
SHORT_SHA=${GITHUB_SHA:0:12}
CHECKSUM_FILE="${SPLIT_DIR}/checksums-${GITHUB_REF_NAME}-${SHORT_SHA}.sha256"
ISO_PIECE_BASENAME_PREFIX="JohnOS-${GITHUB_REF_NAME}-${SHORT_SHA}.iso."

mkdir -p "${SPLIT_DIR}"

# build ISO - output in ./result/iso/
cd "${REPO_DIR}" || exit 1

echo "checking dirty working tree"
git --no-pager diff # see why it's dirty
git --no-pager status # see why it's dirty

echo "building the ISO"
nix build .#flash-drive-iso

echo "splitting the ISO into pieces"
cd "${NIX_BUILD_RESULT_ISO_DIR}" || exit 1

NIX_BUILD_RESULT_ISO_NAME="" # default empty
for iso in *.iso; do
  if [[ "${NIX_BUILD_RESULT_ISO_NAME}" != "" ]]; then
    tree -l L 8 "${GITHUB_WORKSPACE}"
    echo "we have more than one built ISO. we shouldn't..."
    exit 1
  fi
  NIX_BUILD_RESULT_ISO_NAME="${iso}"
done

NIX_BUILD_RESULT_ISO="${NIX_BUILD_RESULT_ISO_DIR}/${NIX_BUILD_RESULT_ISO_NAME}"
split -d -b 128MiB \
  "${NIX_BUILD_RESULT_ISO}" \
  "${SPLIT_DIR}/${ISO_PIECE_BASENAME_PREFIX}"

echo "generating checksum file"
# generate SHA256 checksums of all pieces
cd "${SPLIT_DIR}" || exit 1
for i in JohnOS-*.iso.*; do sha256sum "$i" >> "${CHECKSUM_FILE}"; done

# generate SHA256 checksum of pre-split ISO
cd "${NIX_BUILD_RESULT_ISO_DIR}" || exit 1 # keep only basename in checksum file
JOHNOS_ISO_FILENAME="JohnOS-${GITHUB_REF_NAME}-${SHORT_SHA}.iso"
ln -s "${NIX_BUILD_RESULT_ISO}" "${JOHNOS_ISO_FILENAME}"
sha256sum "${JOHNOS_ISO_FILENAME}"  >> "${CHECKSUM_FILE}"

tree -l -L 8 "${GITHUB_WORKSPACE}"

