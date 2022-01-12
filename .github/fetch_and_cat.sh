#!/usr/bin/env bash

OUTDIR=${OUTDIR:-$(pwd)}
GITHUB_API_BASE="https://api.github.com"
OWNER=${OWNER:-johnrichardrinehart}
REPO=${REPO:-JohnOS}
VERSION=${1:-latest}
TMPDIR=${TMPDIR:-"/tmp/JohnOS-${VERSION}"}

if [[ "$GITHUB_API_TOKEN" != "" ]]; then
    GITHUB_API_AUTH_HEADER="Authorization: token ${GITHUB_API_TOKEN}"
fi

mkdir -p "${TMPDIR}"
cd "${TMPDIR}" || exit 1

fetch_url() {
   if [[ "$3" -gt 2 ]]; then
	   echo "failed to download $1"
	   return
   fi

   printf "fetching url %s\n" "$1"

   if [[ "$2" != "" ]]; then
       printf "expect sha256 %s\n" "$2"
   fi

   curl -H "${GITHUB_API_AUTH_HEADER}" -s -L -O "$1" 

   if [[ "$2" != "" ]]; then
       sumgot=$(sha256sum "$(basename "$1")" | tr -s ' ' | cut -d' ' -f1)
       sumexp="$2"
       if [[ "$sumgot" != "$sumexp" ]]; then
           printf "checksum failed for $1...\ngot: %s\nexp: %s\nattempt $n\n" "$sumgot" "$sumexp" "$3"
	   fetch_url "$1" "$2" $(("$3"+1))
       fi
   fi
}

if [ "$VERSION" = "latest" ]; then
    RELEASE_API_URL="${GITHUB_API_BASE}/repos/${OWNER}/${REPO}/releases/latest"
else
    RELEASE_API_URL="${GITHUB_API_BASE}/repos/${OWNER}/${REPO}/releases/tags/${VERSION}"
fi

echo "making GitHub API request to discover assets: ${RELEASE_API_URL}"
RELEASE_API_RESPONSE=$(curl --silent -H "${GITHUB_API_AUTH_HEADER}" "${RELEASE_API_URL}")
TAG_NAME=$(jq -r '.tag_name' <<<"${RELEASE_API_RESPONSE}")

REFS_TAGS_API_URL="${GITHUB_API_BASE}/repos/${OWNER}/${REPO}/git/refs/tags/${TAG_NAME}"
REFS_TAGS_API_RESPONSE=$(curl --silent -H "${GITHUB_API_AUTH_HEADER}" "${REFS_TAGS_API_URL}")

echo "making GitHub API request to discover SHA: ${REFS_TAGS_API_URL}"
SHORT_REV=$(jq -r '.object.sha' <<<"${REFS_TAGS_API_RESPONSE}")
echo "got SHA ${SHORT_REV} for tag ${TAG_NAME}"

echo "building list of files to download"
urls=()
SHA256_FILE= # assume there isn't one
while read -r asset; do
   url=$(jq -r '.browser_download_url' <<< "${asset}")
   if [[ "${url}" == *"sha256"* ]]; then
	   SHA256_FILE=$(basename "${url}")
	   fetch_url "$url" "" 0 # retry 3 times
   elif [[ "${url}" == *"iso"* ]]; then
       urls+=("$url")
   else
       echo "ignoring unexpected browser_download_url: $url"
   fi
done < <(jq -r -c '.assets[]' <<< "${RELEASE_API_RESPONSE}")

## look for the sha256 file and make an associative array of the form
## [<url_1>: <sha256_1>, <url_2>: <sha266_2>]
## the assumption is that this file only contains filenames and hashes for
## "pieces" and the final ISO and that the "pieces" are in `cat` order (first to
## last piece)
declare -A hashes
iso_pieces=()
if [[ "$SHA256_FILE" != "" ]]; then
	while read -r l; do
	    sha256=$(tr -s ' ' <<< "$l" | cut -d' ' -f1)
	    filename=$(tr -s ' ' <<< "$l" | cut -d' ' -f2)
	    iso_pieces+=("$filename")
	    hashes["$filename"]="$sha256"
	done <"${SHA256_FILE}"
else
	echo "FAILED TO FIND CHECKSUM FILE - UNABLE TO VALIDATE PIECES"
fi

echo "downloading ISO pieces in parallel"

i=0 j=3; for url in "${urls[@]}"; do (( i++ < j )) || wait -n; fetch_url "$url" "${hashes[$(basename "$url")]}" 0 & done; wait

echo "concatenating the pieces together"
JOHNOS_ISO_FILENAME="JohnOS-${TAG_NAME}-${SHORT_REV}.iso"
mv JohnOS-*.iso.00 "${JOHNOS_ISO_FILENAME}"

n=0
for piece in "${iso_pieces[@]}"; do
  if [[ "$n" -gt 0 && $(("$n"+1)) -lt ${#iso_pieces[@]} ]]; then
     echo "concatenating piece ${piece}"
     cat "${piece}" >> "${JOHNOS_ISO_FILENAME}"
     rm "${piece}"
  fi
  ((n++))
done

gothash=$(sha256sum "$JOHNOS_ISO_FILENAME" | tr -s ' ' | cut -d' ' -f1)
expecthash=${hashes[${iso_pieces[-1]}]}
if [[ "$gothash" != "$expecthash" ]]; then
	printf "bad checksum.\ngot %s\nexpected %s" "$gothash" "$expecthash"
	exit 1
fi

echo "all good :)"

set -e # preserve the work in case of write failure

echo "moving the build from $TMPDIR to $OUTDIR"

mv "$TMPDIR/$JOHNOS_ISO_FILENAME" "$OUTDIR"
ls -lh "$OUTDIR/$JOHNOS_ISO_FILENAME"
rm -rf "$TMPDIR"
