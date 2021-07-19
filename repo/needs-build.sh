#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
	local self="$0"; self="$(basename "$self")"
	echo "usage: $self dpkg-arch repo-dir-or-url dist component"
	echo "   eg: $self arm64 https://deb.debian.org/debian unstable non-free"
}
fatal_usage() {
	if [ "$#" -gt 0 ]; then
		echo >&2 "error: $*"
		echo >&2
	fi
	usage >&2
	exit 1
}
[ "$#" -eq 4 ] || fatal_usage "expected 4 arguments (got $#)"

arch="$1"; shift
repo="$1"; shift
dist="$1"; shift
comp="$1"; shift

remote=
if grep -qE '^https?://' <<<"$repo"; then
	remote=1
else
	repo="$(readlink -ev "$repo")"
fi
export repo

arches="$arch"
if [ "$arch" != 'all' ]; then
	arches="$(dpkg-arch-wildcards "$arch")"
fi
export arches

prog="$(basename "$0")"
dir="$(mktemp -d -t "$prog.XXXXXX")"
exitTrap="$(printf 'rm -rf %q' "$dir")"
trap "$exitTrap" EXIT

_get() {
	local to="$1"; shift
	local path="$1"; shift
	if [ -n "$remote" ]; then
		if wget --no-verbose --output-document="$to.XXX" "$repo/$path"; then
			mv -fT "$to.XXX" "$to"
		else
			rm -f "$to.XXX"
			return 1
		fi
	else
		if [ -e "$repo/$path" ]; then
			cp -afT "$repo/$path" "$to"
		else
			return 1
		fi
	fi
}
_get_compressed() {
	local to="$1"; shift
	local path="$1"; shift
	if _get "$to.xz" "$path.xz"; then
		xz -dT0 "$to.xz"
	elif _get "$to.gz" "$path.gz"; then
		pigz -d "$to.gz"
	else
		_get "$to" "$path"
	fi
}

# https://wiki.debian.org/DebianRepository/Format

_get_compressed "$dir/Packages" "dists/$dist/$comp/binary-$arch/Packages"
_get_compressed "$dir/Sources" "dists/$dist/$comp/source/Sources"

packages="$(deb822-json "$dir/Packages")"
sources="$(deb822-json "$dir/Sources")"

# gather a list of source+version combinations that are already built for this architecture
# https://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-source
built="$(jq <<<"$packages" -c '
	[
		.[]
		| if .Source then
			if .Source | index(" ") then
				.Source
			else
				.Source + " (" + .Version + ")"
			end
		else
			.Package + " (" + .Version + ")"
		end
	] | unique
')"
export built

# TODO use Build-Depends + Package to do a crude sort_by here?? (to ensure we list packages in the order they ought to build)

jq <<<"$sources" -c '
	(env.arches | split("[[:space:]]+"; "")) as $arches
	| (env.built | fromjson) as $built
	| .[]
	| select(
		(.Architecture | split(" ") | any(. as $arch | $arches | index($arch)))
		and (((.Package // .Source) + " (" + .Version + ")") as $pkg | $built | index($pkg) | not)
	)
' | dsc-extract-checksums | jq 'with_entries(select(.key | endswith(".dsc")) | .value.path = env.repo + "/" + .value.directory + "/" + .key)'
