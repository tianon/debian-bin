#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
	local self="$0"; self="$(basename "$self")"
	echo "usage: $self target-dir/ dpkg-arch repo-dir-or-url dist component"
	echo "   eg: $self my-output-dir/ arm64 https://deb.debian.org/debian unstable non-free"
}
fatal_usage() {
	if [ "$#" -gt 0 ]; then
		echo >&2 "error: $*"
		echo >&2
	fi
	usage >&2
	exit 1
}
[ "$#" -eq 5 ] || fatal_usage "expected 4 arguments (got $#)"

targetDirectory="$1"; shift
mkdir -p "$targetDirectory"

# TODO --pull flag

dpkgArch="$1"; shift
export dpkgArch

repo="$1"; shift

suite="$1"; shift
export suite

comp="$1"; shift

# TODO --image flag
case "$suite" in
	debian-* | ubuntu-*)
		distro="${suite%%-*}"
		distroSuite="${suite#$distro-}"
		;;

	# if suite isn't "{debian,ubuntu}-xxx", then we should try to auto-detect whether the value is a suite of Debian or Ubuntu
	*)
		# TODO something less ... hanky?
		if bashbrew list "https://github.com/docker-library/official-images/raw/HEAD/library/debian:$suite" &> /dev/null; then
			distro='debian'
			distroSuite="$suite"
		elif bashbrew list "https://github.com/docker-library/official-images/raw/HEAD/library/ubuntu:$suite" &> /dev/null; then
			distr='ubuntu'
			distroSuite="$suite"
		else
			echo >&2 "error: failed to determine what distribution '$suite' belongs to"
			exit 1
		fi
		;;
esac
: "$distro" "$distroSuite"
export distro distroSuite

image="$(jq -rn '
	({
		all: "library", # if trying to build arch:all, build host "native"
		arm64: "arm64v8",
		armel: "arm32v5",
		armhf: "arm32v7", # TODO raspbian
	}[env.dpkgArch] // env.dpkgArch | sub("el$"; "le"))
	+ "/" + env.distro
	+ ":" + env.distroSuite
	+ if env.distro == "debian" and env.distroSuite != "unstable" then
		"-backports" # TODO use of backports should be optional, somehow
	else "" end
')"

sbuildArgs=(
	# TODO alternatives and aptitude resolver should be optional somehow (and more sbuild flags should be possible to add)
	--bd-uninstallable-explainer apt
	--build-dep-resolver aptitude
	--dist "$distroSuite"
)
if [ "$dpkgArch" != 'all' ]; then
	sbuildArgs+=( --arch "$dpkgArch" --no-arch-all )
else
	sbuildArgs+=( --arch-all --no-arch-any )
fi

prog="$(basename "$0")"
dir="$(mktemp -d -t "$prog.XXXXXX")"
exitTrap="$(printf 'rm -rf %q' "$dir")"
trap "$exitTrap" EXIT

thisDir="$(dirname "$BASH_SOURCE")"
shell="$("$thisDir/needs-build.sh" "$dpkgArch" "$repo" "$suite" "$comp" | jq -rs '[ .[] | values[] ] | map(@json | @sh) | join(" ")')"
eval "jsons=( $shell )"

if [ "${#jsons[@]}" -eq 0 ]; then
	exit
fi

docker-image-to-sbuild-schroot --pull "$dir/chroot.tar" "$image" # TODO --pull somehow smarter

failures=0
for json in "${jsons[@]}"; do
	shell="$(jq <<<"$json" -r '
		[
			"path=" + (.path | @sh),
			"validate=" + (.bashValidate | @sh)
		] | join("\n")
	')"
	eval "$shell"
	rm -rf "$dir/dsc"
	dget-lite "$dir/dsc" "$path" "$validate"
	dscBase="$(basename "$path")"
	dsc="$dir/dsc/$dscBase"
	dsc="$(readlink -ev "$dsc")"
	dscDir="$(dirname "$dsc")"
	if ! docker-sbuild \
		--mount "type=bind,src=$dscDir,dst=/dsc,ro" \
		--workdir /dsc \
		"$targetDirectory" \
		"$dir/chroot.tar" \
		"${sbuildArgs[@]}" \
		"$dscBase" \
	; then
		# TODO allow stopping on failure
		(( failures++ )) || :
	fi
done
exit "$failures"
