#!/usr/bin/env bash
set -Eeuo pipefail

targetDir="$1"; shift
mkdir -p "$targetDir"

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

for sourceDir; do
	[ -d "$sourceDir" ]

	dir="$(mktemp -d -t docker-dsc.XXXXXX)"
	defer 'rm -rf %q' "$dir"

	cp -aT "$sourceDir" "$dir/source"

	_run() {
		local user; user="$(id -u):$(id -g)"
		docker run -i --rm --mount "type=bind,source=$dir,destination=/work" -w '/work/source' --user "$user" tianon/sbuild "$@"
	}

	pkg="$(_run dpkg-parsechangelog -SSource)"
	ver="$(_run dpkg-parsechangelog -SVersion)"
	origVer="${ver%-*}" # strip everything from the last dash
	if [ "$ver" = "$origVer" ]; then
		# if "$ver" = "$origVer" here, we're a "native" package and thus have no orig tarball
		isNative=1
	else
		isNative=
		origVer="$(echo "$origVer" | sed -r 's/^[0-9]+://')" # strip epoch
	fi

	needOrig=1
	if [ -z "$isNative" ]; then
		for f in "$sourceDir/../tarballs/${pkg}_${origVer}.orig"* "$sourceDir/../${pkg}_${origVer}.orig"*; do
			base="$(basename "$f")"
			if [ -f "$f" ] && [ ! -f "$dir/$base" ]; then
				cp -a "$f" "$dir/$base"
				needOrig=
			fi
		done
	fi
	if [ -n "$needOrig" ]; then
		_run uscan --download-current-version --rename --destdir ..
	fi

	if [ -z "$isNative" ]; then
		_run extract-origtargz
	fi

	_run dpkg-buildpackage -uc -us -S -nc

	cp -a "$dir/"*_* "$targetDir/"

	finalize
done
