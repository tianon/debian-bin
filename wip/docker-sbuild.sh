#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo >&2 "$BASH_SOURCE: line $LINENO: unexpected exit $?"' ERR

# TODO need to figure out a way to handle building arch:all packages (flags to this script?)
# TODO --build-dep-resolver aptitude ??
# TODO --dist value ?? (should we be using *.changes instead of *.dsc ??)

# usage: $0 target-dir/ buildd-chroot.tar foo.dsc [bar.dsc [baz.dsc ...]]

targetDir="$1"; shift
mkdir -p "$targetDir"

tar="$1"; shift
[ -f "$tar" ]
tar="$(readlink -f "$tar")"
tarBase="$(basename "$tar")"

for dsc; do
	[ -f "$dsc" ]
	dsc="$(readlink -f "$dsc")"
	dscDir="$(dirname "$dsc")"
	dscBase="$(basename "$dsc")"

	read -r -d '' bash <<-'EOBASH' || :
		# schroot is picky about tarball ownership
		tarBase="$(basename "$tar")"
		cp -a "$tar" /tmp/
		tar="/tmp/$tarBase"
		chown root:root "$tar"

		cat > "/etc/schroot/chroot.d/tar" <<-EOF
			[tar]
			description=$tarBase
			groups=root,sbuild
			root-groups=root,sbuild
			profile=sbuild
			type=file
			file=$tar
			source-root-groups=root,sbuild
		EOF

		sbuild \
			--arch-any --no-arch-all --no-source \
			--chroot-mode schroot --chroot tar \
			--dist unknown \
			--resolve-alternatives \
			"$dsc"

		chown -R "$chown" .

		shopt -s dotglob
		mv * /target/
	EOBASH
	[ -n "$bash" ]

	# SYS_ADMIN is necessary for running sbuild
	tty=
	if [ -t 1 ]; then
		tty='--tty'
	fi
	# TODO handle AppArmor confinement better (at least detect AppArmor instead of assuming it)
	chown="$(id -u):$(id -g)"
	docker run -i $tty --rm \
		--cap-add SYS_ADMIN --security-opt apparmor=unconfined \
		--mount "type=bind,source=$dscDir,destination=/dir,readonly" \
		--mount "type=bind,source=$tar,destination=/tar/$tarBase,readonly" \
		--mount "type=bind,source=$targetDir,destination=/target" \
		-e chown="$chown" \
		-e dsc="/dir/$dscBase" \
		-e tar="/tar/$tarBase" \
		-w /intermediate \
		tianon/sbuild \
		bash -Eeuo pipefail -c "$bash"
done
