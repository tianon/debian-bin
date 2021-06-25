#!/usr/bin/env bash
set -Eeuo pipefail

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
distro="${suite%%-*}"
distroSuite="${suite#$distro-}"
export distro distroSuite
# TODO if suite isn't "foo-bar", then we should try to auto-detect whether the value is a suite of Debian or Ubuntu

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
		"-backports"
	else "" end
')"

sbuildArgs=(
	--bd-uninstallable-explainer apt
	--build-dep-resolver aptitude
	--arch "$dpkgArch"
	--dist "$distroSuite"
)

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

docker-image-to-sbuild-schroot --pull "$dir/chroot.tar" "$image"

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
	docker-sbuild \
		--mount "type=bind,src=$dscDir,dst=/dsc,ro" \
		--workdir /dsc \
		"$targetDirectory" \
		"$dir/chroot.tar" \
		"${sbuildArgs[@]}" \
		"$dscBase"
	# TODO allow failure?
done
