#!/usr/bin/env bash
set -Eeuo pipefail

# https://metacpan.org/release/GUILLEM/Dpkg-1.20.9/source/t/Dpkg_Version.t#L169-211

dir="$(dirname "$BASH_SOURCE")"
dir="$(dirname "$dir")"
exec jq -e -s -r -R -L"$dir/jq" '
	include "dpkg-version";

	rtrimstr("\n") | ltrimstr("\n")
	| split("\n")
	| map(
		split(" ")
		| (.[0] | dpkg_version_sort_split) as $v1
		| (.[1] | dpkg_version_sort_split) as $v2
		| (if $v1 > $v2 then "1" elif $v1 < $v2 then "-1" else "0" end) as $cmp
		| if $cmp != .[2] then
			.[0] + " cmp " + .[1] + " = " + $cmp + " but expected " + .[2]
			+ "\n\t" + ($v1 | @json) + " -- " + .[0]
			+ "\n\t" + ($v2 | @json) + " -- " + .[1]
		else empty end
	)
	| if length > 0 then
		error("test failures:\n\n" + join("\n\n") + "\n")
	else "passing" end
' <<'EOF'
1.0-1 2.0-2 -1
2.2~rc-4 2.2-1 -1
2.2-1 2.2~rc-4 1
1.0000-1 1.0-1 0
1 0:1 0
0 0:0-0 0
2:2.5 1:7.5 1
1:0foo 0foo 1
0:0foo 0foo 0
0foo 0foo 0
0foo-0 0foo 0
0foo 0foo-0 0
0foo 0fo 1
0foo-0 0foo+ -1
0foo~1 0foo -1
0foo~foo+Bar 0foo~foo+bar -1
0foo~~ 0foo~ -1
1~ 1 -1
12345+that-really-is-some-ver-0 12345+that-really-is-some-ver-10 -1
0foo-0 0foo-01 -1
0foo.bar 0foobar 1
0foo.bar 0foo1bar 1
0foo.bar 0foo0bar 1
0foo1bar-1 0foobar-1 -1
0foo2.0 0foo2 1
0foo2.0.0 0foo2.10.0 -1
0foo2.0 0foo2.0.0 -1
0foo2.0 0foo2.10 -1
0foo2.1 0foo2.10 -1
1.09 1.9 0
1.0.8+nmu1 1.0.8 1
3.11 3.10+nmu1 1
0.9j-20080306-4 0.9i-20070324-2 1
1.2.0~b7-1 1.2.0~b6-1 1
1.011-1 1.06-2 1
0.0.9+dfsg1-1 0.0.8+dfsg1-3 1
4.6.99+svn6582-1 4.6.99+svn6496-1 1
53 52 1
0.9.9~pre122-1 0.9.9~pre111-1 1
2:2.3.2-2+lenny2 2:2.3.2-2 1
1:3.8.1-1 3.8.GA-1 1
1.0.1+gpl-1 1.0.1-2 1
1a 1000a -1
EOF
