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
else "pass" end
