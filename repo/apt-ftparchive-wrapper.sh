#!/usr/bin/env bash
set -Eeuo pipefail

dir="$(dirname "$BASH_SOURCE")"
dir="$(readlink -ev "$dir")"

repo="$1"; shift
cd "$repo"

if [ metadata.jq -nt metadata.json ]; then
	jq --tab -nSf metadata.jq > metadata.json
	touch --reference=metadata.jq metadata.json
fi

"$dir/apt-ftparchive-mkdir.sh" .

conf="$("$dir/apt-ftparchive-generate-conf.sh" .)"
apt-ftparchive -qq generate /dev/stdin <<<"$conf"

"$dir/apt-ftparchive-release.sh" .

