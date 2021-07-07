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

"$dir/apt-ftparchive-wrapper.sh" .
"$dir/incoming.sh" .
"$dir/apt-ftparchive-wrapper.sh" .
