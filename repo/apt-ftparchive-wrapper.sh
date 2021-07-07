#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
	local self="$0"; self="$(basename "$self")"
	echo "usage: $self repo-dir/"
}
fatal_usage() {
	if [ "$#" -gt 0 ]; then
		echo >&2 "error: $*"
		echo >&2
	fi
	usage >&2
	exit 1
}
[ "$#" -eq 1 ] || fatal_usage "expected 1 argument (got $#)"

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
