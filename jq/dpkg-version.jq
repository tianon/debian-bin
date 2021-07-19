# given a Debian version, returns an array that can be used for sorting
# inspired heavily by the Dpkg::Version (Perl) source code
def dpkg_version_sort_split:
	[
		if index(":") then . else "0:" + . end # force epoch to be specified
		| if index("-") then . else . + "-0" end # force revision to be specified
		| scan("[0-9]+|[^0-9]+")
		| try tonumber // (
			split("")
			| map(
				# https://metacpan.org/release/GUILLEM/Dpkg-1.20.9/source/lib/Dpkg/Version.pm#L338-350
				if . == "~" then
					-1
				else
					explode[0]
					+ if test("[a-zA-Z]") then 0 else 256 end
				end
			)
		)
	] + [[0]] # gotta add an extra [0] at the end to make sure "1.0" ([1,[302],0]) is higher than "1.0~" ([1,[302],0,[-1]])
;
