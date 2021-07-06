#!/usr/bin/env bash
set -Eeuo pipefail

dir="$(dirname "$BASH_SOURCE")"
dir="$(readlink -ev "$dir")"
parent="$(dirname "$dir")"
export PATH="$parent/generic:$PATH"

dir="$(mktemp -d -t 'dsc-tests.XXXXXX')"
exitTrap="$(printf 'rm -rf %q' "$dir")"
trap "$exitTrap" EXIT

# https://snapshot.debian.org/package/refind/0.12.0-1/
url='http://snapshot.debian.org/archive/debian/20200723T030638Z/pool/main/r/refind/refind_0.12.0-1.dsc'

# test remote (non-local) dget-lite
dget-lite "$dir/dget" "$url"
# (the files fetched here will be used for more tests :D)

assert() {
	if ! "$@"; then
		{
			local text; text="$(printf ' %q' "$@")"
			echo
			echo "error: assert failed:$text"
			local i n="${#FUNCNAME[@]}"
			for (( i = 1; i < n; i++ )); do
				local j="$(( i - 1 ))"
				printf '  %s() @ %s:%s\n' "${FUNCNAME[$i]}" "${BASH_SOURCE[$j]}" "${BASH_LINENO[$j]}"
			done
			echo
		} >&2
		return 1
	fi
	return 0
}

sha256_orig() {
	local d="$1"; shift
	count="$(ls -1 "$d" | wc -l)"
	assert test "$count" = '3'
	sha256sum --strict --check <<-EOF
		19759f47a4fd4041264bb5158a878345167914a6ac7fd9980cf954acac60568a *$d/refind_0.12.0-1.dsc
		7bb8505bc9ff87a7b6de38bf9a91d46f4d613b30031d5eb088a4d791a31eb7c4 *$d/refind_0.12.0.orig.tar.gz
		8309c086ed6fca7db5a025933f21a6dc3376689d9f393562b54615ad251c8e30 *$d/refind_0.12.0-1.debian.tar.xz
	EOF
}
sha256_orig "$dir/dget"

# test deb822-json
# wget -qO- 'https://snapshot.debian.org/archive/debian/20200723T030638Z/pool/main/r/refind/refind_0.12.0-1.dsc' | deb822-json | jq -r '@json | @sh'
expected='[{"Format":"3.0 (quilt)","Source":"refind","Binary":"refind","Architecture":"amd64 arm64 i386","Version":"0.12.0-1","Maintainer":"Rod Smith <rod.smith@canonical.com>","Uploaders":"Tianon Gravi <tianon@debian.org>","Homepage":"https://www.rodsbooks.com/refind","Standards-Version":"4.3.0","Vcs-Browser":"https://salsa.debian.org/debian/refind","Vcs-Git":"https://salsa.debian.org/debian/refind.git","Build-Depends":"debhelper (>= 9), gnu-efi","Package-List":"\nrefind deb admin optional arch=amd64,arm64,i386","Checksums-Sha1":"\na6b63bbaf9c09e63c82cbd54fb5a776e0260b3f9 3898337 refind_0.12.0.orig.tar.gz\nc34e80a8df0a2eaf0c2cda626fb53bb829562154 20400 refind_0.12.0-1.debian.tar.xz","Checksums-Sha256":"\n7bb8505bc9ff87a7b6de38bf9a91d46f4d613b30031d5eb088a4d791a31eb7c4 3898337 refind_0.12.0.orig.tar.gz\n8309c086ed6fca7db5a025933f21a6dc3376689d9f393562b54615ad251c8e30 20400 refind_0.12.0-1.debian.tar.xz","Files":"\n673088f61ccd60535a3b2c0d607e4a7e 3898337 refind_0.12.0.orig.tar.gz\nce0411663ea17fcf9662a229ba72f725 20400 refind_0.12.0-1.debian.tar.xz"}]'
expected="$(jq -cS . <<<"$expected")"
actual="$(deb822-json "$dir/dget/refind_0.12.0-1.dsc" | jq -cS .)"
assert test "$expected" = "$actual"

# test dsc-extract-checksums
# wget -qO- 'https://snapshot.debian.org/archive/debian/20200723T030638Z/pool/main/r/refind/refind_0.12.0-1.dsc' | deb822-json | dsc-extract-checksums | jq -r '@json | @sh'
expected='{"refind_0.12.0-1.debian.tar.xz":{"bashValidate":"s=\"$(stat -c %s '\''refind_0.12.0-1.debian.tar.xz'\'')\" && [ \"$s\" = '\''20400'\'' ] && sha256sum --check --quiet --strict - <<<'\''8309c086ed6fca7db5a025933f21a6dc3376689d9f393562b54615ad251c8e30 *refind_0.12.0-1.debian.tar.xz'\''","sha256":"8309c086ed6fca7db5a025933f21a6dc3376689d9f393562b54615ad251c8e30","size":"20400"},"refind_0.12.0.orig.tar.gz":{"bashValidate":"s=\"$(stat -c %s '\''refind_0.12.0.orig.tar.gz'\'')\" && [ \"$s\" = '\''3898337'\'' ] && sha256sum --check --quiet --strict - <<<'\''7bb8505bc9ff87a7b6de38bf9a91d46f4d613b30031d5eb088a4d791a31eb7c4 *refind_0.12.0.orig.tar.gz'\''","sha256":"7bb8505bc9ff87a7b6de38bf9a91d46f4d613b30031d5eb088a4d791a31eb7c4","size":"3898337"}}'
expected="$(jq -cS . <<<"$expected")"
actual="$(dsc-extract-checksums "$dir/dget/refind_0.12.0-1.dsc" | jq -cS .)"
assert test "$expected" = "$actual"

# test local dget-lite
dget-lite "$dir/dget-local" "$dir/dget/refind_0.12.0-1.dsc"
sha256_orig "$dir/dget-local"
rm -rf "$dir/dget-local"

# test dput-local
mkdir "$dir/dput-local"
dput-local "$dir/dput-local" "$dir/dget/refind_0.12.0-1.dsc"
sha256_orig "$dir/dput-local"
rm -rf "$dir/dput-local"

# test extract-origtargz
mkdir -p "$dir/src/refind"
cp "$dir/dget/refind_0.12.0.orig.tar.gz" "$dir/src/"
tar --extract --file "$dir/dget/refind_0.12.0-1.debian.tar.xz" --directory "$dir/src/refind"
files="$(ls -1 "$dir/src/refind")"
assert test "$files" = 'debian'
( set -Eeuo pipefail; cd "$dir/src/refind"; extract-origtargz )
assert grep -q Tianon "$dir/src/refind/debian/changelog" # Debian's debian/ (not upstream's)
assert test -s "$dir/src/refind/NEWS.txt" # ... but upstream files

# test dsc-from-source
dsc-from-source "$dir/new-dsc" "$dir/src/refind"
assert test -s "$dir/new-dsc/refind_0.12.0-1.dsc"
# wget -qO- 'https://snapshot.debian.org/archive/debian/20200723T030638Z/pool/main/r/refind/refind_0.12.0-1.dsc' | deb822-json | dsc-extract-checksums | jq -r 'del(.[].bashValidate) | @json | @sh'
expected='{"refind_0.12.0-1.debian.tar.xz":{"sha256":"8309c086ed6fca7db5a025933f21a6dc3376689d9f393562b54615ad251c8e30","size":"20400"},"refind_0.12.0.orig.tar.gz":{"sha256":"7bb8505bc9ff87a7b6de38bf9a91d46f4d613b30031d5eb088a4d791a31eb7c4","size":"3898337"}}'
expected="$(jq -cS . <<<"$expected")"
actual="$(dsc-extract-checksums "$dir/new-dsc/refind_0.12.0-1.dsc" | jq -cS 'del(.[].bashValidate)')"
assert test "$expected" = "$actual"
rm -f "$dir/new-dsc/refind_0.12.0-1"_* # axe .buildinfo + .changes
cp -f "$dir/dget/refind_0.12.0-1.dsc" "$dir/new-dsc/" # override .dsc so we can verify the full dir
sha256_orig "$dir/new-dsc" # heck yeah, reproducible .debian.tar.xz (love 2 test dpkg-buildpackage behavior)
rm -rf "$dir/new-dsc"

# done testing (extracted) source things
rm -rf "$dir/src"

# test dsc-new-suite
dsc-new-suite "$dir/new-dsc" bullseye '~deb11u0' "$dir/dget/refind_0.12.0-1.dsc"
assert test -s "$dir/new-dsc/refind_0.12.0-1~deb11u0.dsc"
expected='2a89a0f666e57d2c8989df07d525e86739ae6963b1919c2b5e102c0763cd694e'
actual="$(sha256sum < "$dir/new-dsc/refind_0.12.0-1~deb11u0.dsc" | cut -d' ' -f1)"
assert test "$expected" = "$actual" # once again, love 2 test dpkg-buildpackage behavior O:)
rm -rf "$dir/new-dsc"
