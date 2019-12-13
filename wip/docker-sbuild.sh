#!/usr/bin/env bash
set -Eeuo pipefail

# TODO need to figure out a way to handle building arch:all packages (flags to this script?)
# TODO dpkg arch likely needs to be an argument to this script?  or parse from the given tarball?
# TODO --build-dep-resolver aptitude ??

targetDir="$1"; shift
mkdir -p "$targetDir"

tar="$1"; shift
[ -f "$tar" ]

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

	dir="$(mktemp -d -t docker-sbuild.XXXXXX)"
	defer 'rm -rf %q' "$dir"

	# copy necessary artifacts into our temporary directory
	cp -a "$dsc" "$dir/"
	files="$(awk '/^[^:]+:$/ { f = $0; next } /^[^:]+:/ { f = ""; next } /^ / && f ~ /^(Files|Checksums-Sha[0-9]+):$/ { print $3 }' "$dsc")"
	dscDir="$(dirname "$dsc")"
	for f in $files; do
		cp -a "$dscDir/$f" "$dir/"
	done
	cp --reflink=auto -a "$tar" "$dir/"

	read -r -d '' bash <<-'EOBASH' || :
		# schroot is picky about tarball ownership
		cp -a "$tar" /tmp/; tar="$(basename "$tar")"; tar="/tmp/$tar"
		chown root:root "$tar"

		dpkgArch='amd64' # TODO !!!!!

		cat > "/etc/schroot/chroot.d/tar-$dpkgArch-sbuild" <<-EOF
			[tar-$dpkgArch-sbuild]
			description=$dpkgArch Autobuilder ($tar)
			groups=root,sbuild
			root-groups=root,sbuild
			profile=sbuild
			type=file
			file=$tar
			source-root-groups=root,sbuild
		EOF

		sbuild \
			--dist tar \
			--arch "$dpkgArch" \
			--no-source \
			--arch-any \
			--no-arch-all \
			--resolve-alternatives \
			--build-dep-resolver aptitude \
			"$dsc"

		chown -R "$chown" .
		mv * /target/
	EOBASH
	[ -n "$bash" ]

	# SYS_ADMIN is necessary for running sbuild
	tty=
	if [ -t 1 ]; then
		tty='--tty'
	fi
	# TODO handle AppArmor confinement better (detect AppArmor perhaps)
	docker run -i $tty --rm \
		--cap-add SYS_ADMIN --security-opt apparmor=unconfined \
		--mount "type=bind,source=$dir,destination=/dir,readonly" \
		--mount "type=bind,source=$targetDir,destination=/target" \
		-e chown="$(id -u):$(id -g)" \
		-e dsc="/dir/$(basename "$dsc")" \
		-e tar="/dir/$(basename "$tar")" \
		-w /intermediate \
		tianon/sbuild \
		bash -Eeuo pipefail -c "$bash"

	finalize
done
