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

cat <<'EOF'
Dir {
	ArchiveDir ".";
	CacheDir "./.cache";
}

Default {
	Packages::Compress ". xz";
	Sources::Compress ". xz";
	Contents::Compress ". xz";
}

TreeDefault {
	BinCacheDB "packages-$(DIST)-$(SECTION)-$(ARCH).db";
	SrcCacheDB "sources-$(DIST)-$(SECTION).db";

	Directory "pool/$(DIST)/$(SECTION)";
	SrcDirectory "pool/$(DIST)/$(SECTION)";

	Packages "dists/$(DIST)/$(SECTION)/binary-$(ARCH)/Packages";
	Sources "dists/$(DIST)/$(SECTION)/source/Sources";
	Contents "dists/$(DIST)/$(SECTION)/Contents-$(ARCH)";
}
EOF

jq -r '
	[
		.suites
		| to_entries[]
		| .key as $suite
		| .value
		| "\n"
		+ "Tree \"" + $suite + "\" {\n"
		+ "\tSections \"" + (.components | join(" ")) + "\";\n"
		+ "\tArchitectures \"" + (.architectures | join(" ")) + "\";\n"
		+ "}"
	]
	| join("\n")
' metadata.json
