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
		| .metadata = {
			# apply some defaults to the "metadata" struct
			Codename: $suite,
			Suite: $suite,
			Components: (.components | join(" ")),
			Architectures: (.architectures | join(" ")),
		} + .metadata
		| @sh "rm -f \("dists/" + $suite + "/Release")",
		"apt-ftparchive "
		+ (
			.metadata
			| to_entries
			| map(
				@sh "-o \("APT::FTPArchive::Release::" + .key + "=" + .value)"
			)
			| join(" ")
		)
		+ " release "
		+ ("dists/" + $suite | @sh)
		+ " > "
		+ ("dists/" + $suite + "/Release.new" | @sh),
		@sh "mv \("dists/" + $suite + "/Release.new") \("dists/" + $suite + "/Release")"
	]
	| join("\n")
' metadata.json)"
eval "$shell"
