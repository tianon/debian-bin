#!/usr/bin/env bash
set -Eeuo pipefail

dir="$(dirname "$BASH_SOURCE")"
dir="$(readlink -ev "$dir")"

parent="$(dirname "$dir")"
export PATH="$parent/generic:$PATH"

fail=0
for f in "$dir"/deb822/*.deb822; do
	expected="$(jq '.' "${f%.deb822}.json")"
	actual="$(deb822-json "$f")"

	base="$(basename "$f")"
	if [ "$expected" = "$actual" ]; then
		echo "$base: pass"
	else
		echo >&2 "$base: fail"
		(( fail++ )) || :
	fi
done
exit "$fail"
