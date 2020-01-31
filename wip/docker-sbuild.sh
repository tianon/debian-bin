#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo >&2 "$BASH_SOURCE: line $LINENO: unexpected exit $?"' ERR

# TODO need to figure out a way to handle building arch:all packages (flags to this script?)
# TODO --build-dep-resolver aptitude ??
# TODO --dist value ?? (should we be using *.changes instead of *.dsc ??)
# TODO detect --arch value from tarball ????

# usage: $0 target-dir/ buildd-chroot.tar foo.dsc [bar.dsc [baz.dsc ...]]

targetDir="$1"; shift
mkdir -p "$targetDir"

tar="$1"; shift
[ -f "$tar" ]
tar="$(readlink -f "$tar")"
tarBase="$(basename "$tar")"

prog="$(basename "$0")"
dir="$(mktemp -d -t "$prog.XXXXXX")"
exitTrap="$(printf 'rm -rf %q' "$dir")"
trap "$exitTrap" EXIT
workdir="$dir/workdir"

mkdir "$workdir"
cp -a --reflink=auto "$tar" "$workdir/"
cat > "$workdir/schroot.conf" <<-EOC
	[tar]
	description=$tarBase
	groups=root,sbuild
	root-groups=root,sbuild
	profile=sbuild
	type=file
	file=/schroot/$tarBase
	source-root-groups=root,sbuild
EOC
uid="$(id -u)"
gid="$(id -g)"
cat > "$workdir/Dockerfile" <<-EODF
	FROM tianon/sbuild
	RUN set -eux; \
		groupadd --gid '$gid' user; \
		useradd --gid '$gid' --uid '$uid' --groups sbuild user
	# schroot is picky about tarball ownership
	COPY --chown=root:root $tarBase /schroot/
	COPY schroot.conf /etc/schroot/chroot.d/tar
	USER user
EODF
img="$(docker build -q "$workdir")"
rm -rf "$workdir"

for dsc; do
	[ -f "$dsc" ]
	dsc="$(readlink -f "$dsc")"
	dscDir="$(dirname "$dsc")"
	dscBase="$(basename "$dsc")"

	# SYS_ADMIN is necessary for running sbuild
	tty=
	if [ -t 1 ]; then
		tty='--tty'
	fi
	# TODO handle AppArmor confinement better (at least detect AppArmor instead of assuming it)
	docker run -i $tty --rm \
		--cap-add SYS_ADMIN --security-opt apparmor=unconfined \
		--mount "type=bind,source=$dscDir,destination=/dir,readonly" \
		--mount "type=bind,source=$targetDir,destination=/target" \
		-w /target \
		"$img" \
		sbuild \
			--arch-any --no-arch-all --no-source \
			--build-dep-resolver aptitude \
			--chroot-mode schroot --chroot tar \
			--dist unknown \
			--no-run-lintian \
			--resolve-alternatives \
			"/dir/$dscBase"
done
