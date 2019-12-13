#!/usr/bin/env bash
set -Eeuo pipefail

tar="$1"; shift
from="$1"; shift

onExit=
defer() {
	local newExit; newExit="$(printf "$@")"
	[ -z "$onExit" ] || onExit="; $onExit"
	onExit="$newExit$onExit"
	trap "$onExit" EXIT
}

dir="$(mktemp -d -t docker-sbuild.XXXXXX)"
defer 'rm -rf %q' "$dir"

cat > "$dir/Dockerfile" <<-EOF
	FROM $from
	# this should match the package list added to the "buildd" variant in debootstrap and the list installed by sbuild
	# https://salsa.debian.org/installer-team/debootstrap/blob/da5f17904de373cd7a9224ad7cd69c80b3e7e234/scripts/debian-common#L20
	# https://salsa.debian.org/debian/sbuild/blob/fc306f4be0d2c57702c5e234273cd94b1dba094d/bin/sbuild-createchroot#L257-260
	RUN set -eux; \
		apt-get update; \
		apt-get install -y --no-install-recommends \
			build-essential \
			fakeroot \
		; \
		rm -rf /var/lib/apt/lists/*
EOF
docker build --iidfile "$dir/image.txt" "$dir"
img="$(< "$dir/image.txt")"
#defer 'docker rmi %q > /dev/null' "$img"

ctr="$(docker create "$img")"
defer 'docker rm -vf %q > /dev/null' "$ctr"

docker export --output "$tar" "$ctr"

# sbuild needs "/dev/null" and our goofy tarball might not have it, so we need to "fake" it (which we do by adding Docker's intentionally minimal version to the end of the generated tarball)
user="$(id -u):$(id -g)"
tar="$(readlink -f "$tar")"
docker run -i --rm -u "$user" --mount "type=bind,source=$tar,destination=/tar.tar" tianon/sbuild tar --append --file=/tar.tar --directory=/ dev

printf '%q created (FROM %q)\n' "$tar" "$from"
