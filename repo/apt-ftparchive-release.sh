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
		| .metadata = {
			# apply some defaults to the "metadata" struct
			Codename: $suite,
			Suite: $suite,
			Components: (.components | join(" ")),
			Architectures: (.architectures | join(" ")),
		} + .metadata
		| "apt-ftparchive "
		+ (
			.metadata
			| to_entries
			| map(
				"-o "
				+ ("APT::FTPArchive::Release::" + .key + "=" + .value | @sh)
			)
			| join(" ")
		)
		+ " release "
		+ ("dists/" + $suite | @sh)
		+ " > "
		+ ("dists/" + $suite + "/Release.new" | @sh),
		"mv " + ("dists/" + $suite + "/Release.new" | @sh) + " " + ("dists/" + $suite + "/Release" | @sh)
	]
	| join("\n")
' metadata.json)"
eval "$shell"
