#!/bin/bash
set -e

suite="$1"
[ "$suite" ] || { echo >&2 "usage: $0 suite"; exit 1; }

arch="$(dpkg --print-architecture)"
schroot="$suite-$arch-sbuild"

dir="$(mktemp --tmpdir --directory "sbuild-createchroot.${suite}.XXXXXXXXXX")"

sudo rm -vf "/etc/schroot/chroot.d/$schroot-"*
sudo sbuild-createchroot \
	--make-sbuild-tarball="/home/tianon/schroots/$suite.tar.gz" \
	--arch="$arch" \
	--include=eatmydata \
	"$suite" \
	"$dir" \
	http://httpredir.debian.org/debian

sudo mv "/etc/schroot/chroot.d/$schroot-"* "/etc/schroot/chroot.d/$schroot"
{
	echo 'source-root-groups=root,sbuild'
	echo 'command-prefix=eatmydata'
} | sudo tee -a "/etc/schroot/chroot.d/$schroot"

session="$suite-$$-$RANDOM-$RANDOM"
schroot -c "source:$schroot" -b -n "$session"
trap "schroot -c '$session' -e" EXIT

_cmd() {
	schroot -c "$session" -r -u root -d / -- "$@"
}

echo 'Acquire::Languages "none";' | _cmd tee /etc/apt/apt.conf.d/no-languages
echo 'APT::Get::Show-Versions "1";' | _cmd tee /etc/apt/apt.conf.d/verbose
echo 'Acquire::PDiffs "false";' | _cmd tee /etc/apt/apt.conf.d/no-pdiffs

# add incoming where appropriate
case "$suite" in
	experimental|rc-buggy|unstable|sid|*-backports{,-sloppy}|*-proposed-updates|*-lts)
		echo "deb http://incoming.debian.org/debian-buildd buildd-$suite main" | _cmd tee /etc/apt/sources.list.d/incoming.list
		;;
esac

# sbuild-update -udcar
_cmd sh -ec '
	apt-get -y update
	apt-get -y dist-upgrade
	apt-get -y clean
	apt-get -y autoclean
	apt-get -y autoremove
'
