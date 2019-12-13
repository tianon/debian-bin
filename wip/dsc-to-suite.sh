#!/usr/bin/env bash
set -Eeuo pipefail

targetDir="$1"; shift
mkdir -p "$targetDir"

suite="$1"; shift # "jessie"
suffix="$1"; shift # "~deb8u0"

deferred=
defer() {
	local newExit; newExit="$(printf "$@")"
	[ -z "$deferred" ] || deferred="; $deferred"
	deferred="$newExit$deferred"
	trap "$deferred" EXIT
}
finalize() {
	eval "$deferred"
	deferred=
	trap - EXIT
}

for dsc; do
	[ -f "$dsc" ]

	dir="$(mktemp -d -t docker-dsc.XXXXXX)"
	defer 'rm -rf %q' "$dir"

	# copy necessary artifacts into our temporary directory
	cp -a "$dsc" "$dir/"
	files="$(awk '/^[^:]+:$/ { f = $0; next } /^[^:]+:/ { f = ""; next } /^ / && f ~ /^(Files|Checksums-Sha[0-9]+):$/ { print $3 }' "$dsc")"
	dscDir="$(dirname "$dsc")"
	for f in $files; do
		cp -a "$dscDir/$f" "$dir/"
	done
	dsc="$(basename "$dsc")"

	runDir='/work'
	_run() {
		local user; user="$(id -u):$(id -g)"
		docker run -i --rm --mount "type=bind,source=$dir,destination=/work" -w "$runDir" --user "$user" tianon/sbuild "$@"
	}

	# extract the dsc source package into something we can work with
	_run dpkg-source --extract "$dsc" 'source'
	runDir+='/source'

	# munge the changelog with a new entry (but the same date, urgency, etc)
	_run bash -Eeuo pipefail -c '
		pkg="$(dpkg-parsechangelog -SSource)"
		ver="$(dpkg-parsechangelog -SVersion)"
		urg="$(dpkg-parsechangelog -SUrgency)"
		maint="$(dpkg-parsechangelog -SMaintainer)"
		date="$(dpkg-parsechangelog -SDate)"
		'"$(printf 'suite=%q' "$suite")"'
		'"$(printf 'suffix=%q' "$suffix")"'

		echo "$pkg ($ver$suffix) $suite; urgency=$urg"
		echo
		echo "  * Repacked for $suite"
		echo
		echo " -- $maint  $date"
		echo
	' | cat - "$dir/source/debian/changelog" > "$dir/munged-changelog"
	mv "$dir/munged-changelog" "$dir/source/debian/changelog"

	# remove (now unnecessary) input artifacts
	for f in $files "$dsc"; do
		case "$f" in
			*.orig*) ;; # "WAIT, I NEED THAT"
			*) rm -f "$dir/$f" ;;
		esac
	done

	# build new source package
	_run dpkg-buildpackage -uc -us -S -nc

	# copy artifacts out!
	cp -a "$dir/"*_* "$targetDir/"

	finalize
done
