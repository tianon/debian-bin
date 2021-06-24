#!/usr/bin/env bash
set -Eeuo pipefail

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
