#!/bin/bash
set -e

suite="$1"
shift || { echo >&2 "usage: $0 suite [arch]"; exit 1; }

targetSuite="$suite"
case "$targetSuite" in
	experimental) suite='unstable' ;;
	rc-buggy) suite='sid' ;;
	*-backports) suite="${targetSuite%-backports}" ;;
	*-lts) suite="${targetSuite%-lts}" ;;
esac

hostArch="$(dpkg --print-architecture)"
arch="${1:-"$hostArch"}"
schroot="$suite-$arch-sbuild"
targetSchroot="$targetSuite-$arch-sbuild"
mirror='http://httpredir.debian.org/debian'

tarball="${targetSuite}.tar.gz"
if [ "$arch" != "$hostArch" ]; then
	tarball="${targetSuite}-${arch}.tar.gz"
fi
tarball="$HOME/schroots/$tarball"

dir="$(mktemp --tmpdir --directory "sbuild-createchroot.${targetSchroot}.XXXXXXXXXX")"
trap "sudo rm -rf '$dir'" EXIT

sudo rm -vf "/etc/schroot/chroot.d/$schroot-"*
sudo sbuild-createchroot \
	--make-sbuild-tarball="${tarball}" \
	--arch="$arch" \
	--include=eatmydata \
	"$suite" \
	"$dir" \
	"$mirror"

sudo mv -v "/etc/schroot/chroot.d/$schroot-"* "/etc/schroot/chroot.d/$targetSchroot"
if [ "$schroot" != "$targetSchroot" ]; then
	sudo sed -i "s!$schroot!$targetSchroot!g" "/etc/schroot/chroot.d/$targetSchroot"
	schroot="$targetSchroot"
fi
{
	echo 'source-root-groups=root,sbuild'
	echo 'command-prefix=eatmydata'
} | sudo tee -a "/etc/schroot/chroot.d/$schroot"

session="$targetSuite-$$-$RANDOM-$RANDOM"
schroot -c "source:$schroot" -b -n "$session"
trap "schroot -c '$session' -e" EXIT
# it doesn't matter that we override the previous EXIT trap here because the directory it was removing was already deleted if we successfully get this far by sbuild-createchroot itself

_cmd() {
	schroot -c "$session" -r -u root -d / -- "$@"
}

echo 'Acquire::Languages "none";' | _cmd tee /etc/apt/apt.conf.d/no-languages
echo 'APT::Get::Show-Versions "1";' | _cmd tee /etc/apt/apt.conf.d/verbose
echo 'Acquire::PDiffs "false";' | _cmd tee /etc/apt/apt.conf.d/no-pdiffs

# add incoming where appropriate
_incoming() {
	local dist="$1"
	case "$1" in
		experimental|rc-buggy|unstable|sid|*-backports|*-backports-sloppy|*-proposed-updates|*-lts)
			for d in deb deb-src; do
				echo "$d http://incoming.debian.org/debian-buildd buildd-$1 main"
			done | _cmd tee "/etc/apt/sources.list.d/incoming-${1}.list"
			;;
	esac
}

_incoming "$suite"

if [ "$suite" != "$targetSuite" ]; then
	_incoming "$targetSuite"
	for d in deb deb-src; do
		echo "$d $mirror $targetSuite main"
	done | _cmd tee -a /etc/apt/sources.list
	suite="$targetSuite"
fi

# sbuild-update -udcar
_cmd sh -ec '
	apt-get -y update
	apt-get -y dist-upgrade
	apt-get -y clean
	apt-get -y autoclean
	apt-get -y autoremove
'
