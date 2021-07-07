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

repo="$1"; shift
cd "$repo"

shell="$(jq -r '
	.suites
	| to_entries[]
	| .key as $suite
	| .value
	| .components[]
	| $suite + "/" + .
	| @sh
' metadata.json)"
eval "process=( $shell )"

for p in "${process[@]}"; do
	incomingDir="incoming/$p"
	poolBaseDir="pool/$p"
	for changes in "$incomingDir"/*.changes; do
		[ -f "$changes" ] || continue

		changesJson="$(deb822-json "$changes" | jq '.[0]')"

		json="$(dsc-extract-checksums <<<"$changesJson")"
		dir="$(dirname "$changes")"
		export dir

		if ! (
			set -Eeuo pipefail
			shell="$(jq <<<"$json" -r '.[].bashValidate // error("missing bashValidate from dsc-extract-checksums!")')"
			[ -n "$shell" ]
			cd "$dir"
			eval "$shell"
		); then
			echo >&2 "warning: '$changes' appears to be invalid or incomplete! (skipping)"
			continue
		fi

		files="$(jq <<<"$json" -r '
			keys
			| map(env.dir + "/" + . | @sh)
			| join (" ")
		')"
		eval "files=( $files )"
		files+=( "$changes" )

		src="$(jq <<<"$changesJson" -r '.Source')"
		poolDir="$poolBaseDir/$src"

		# verify that the files either don't already exist or are already the same (before copying anything)
		toDelete=()
		toMove=()
		for f in "${files[@]}"; do
			base="$(basename "$f")"
			target="$poolDir/$base"
			if [ -e "$target" ]; then
				if ! diff -q "$f" "$target" > /dev/null; then
					echo >&2 "warning: '$changes' includes '$base' which already exists at '$target' (and the files are not identical!)"
					continue 2
				fi
				toDelete+=( "$f" )
			else
				toMove+=( "$f" )
			fi
		done

		if [ "${#toMove[@]}" -gt 0 ]; then
			mkdir --parents --verbose "$poolDir"
			mv --verbose --target-directory="$poolDir" "${toMove[@]}"
		fi

		if [ "${#toDelete[@]}" -gt 0 ]; then
			rm --verbose "${toDelete[@]}"
		fi
	done
done
