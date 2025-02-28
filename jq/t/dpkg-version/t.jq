include "dpkg-version";

rtrimstr("\n") | ltrimstr("\n")
| split("\n")
| map(
	split(" ")
	| .[0], .[1]
)
| sort_by(dpkg_version_sort_split)
| map(
	dpkg_version_parse as $parse
	| ($parse | dpkg_version_string) as $string
	| if . != $string then
		error("\(.) parsed as \($parse) which becomes \($string)")
	else . end
	| {
		key: .,
		value: {
			$parse,
			$string,
		},
	}
)
| from_entries
