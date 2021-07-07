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
	[
		.suites
		| to_entries[]
		| .key as $suite
		| .value
		| (
			"dists/" + $suite,
			(
				.components[]
				| (
					"incoming/" + $suite + "/" + .,
					"pool/" + $suite + "/" + .
				)
			),
			(
				[ .components, .architectures ]
				| combinations
				| "dists/" + $suite + "/" + .[0] + "/" + if .[1] == "source" then .[1] else "binary-" + .[1] end
			)
		)
	]
	+ [ ".cache" ]
	| sort
	| map(@sh)
	| "mkdir --parents --verbose " + join(" ")
' metadata.json)"
eval "$shell"
