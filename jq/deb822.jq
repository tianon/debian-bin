# https://manpages.debian.org/testing/dpkg-dev/deb822.5.en.html

# input:
#   Foo: bar
#   Bar: baz
#
#   Foo: buzz
#
#   Multi: line
#    .
#    values
#   Work: like this
#
# output:
#   [
#     {
#       "Foo": "bar",
#       "Bar": "baz"
#     },
#     {
#       "Foo": "buzz"
#     },
#     {
#       "Multi": "line\n.\nvalues",
#       "Work": "like this"
#     }
#   ]
def deb822_parse:
	# normalize CRLF to just LF
	gsub("\r\n|\r"; "\n")

	# naïve PGP stripping
	| gsub("^-----BEGIN PGP SIGNED MESSAGE-----\nHash: [^\n]+\n+|\n+-----BEGIN PGP SIGNATURE-----\n.*\n-----END PGP SIGNATURE-----\n*$"; ""; "m")

	# strip any comments (optional in the spec, but for documents that should not have them they are invalid syntax anyhow so should be harmless to strip)
	| gsub("(^|\n)(#[^\n]*($|\n))+"; "\n")

	# strip any leading/trailing newlines
	| gsub("^\n+|\n+$"; "")

	# split on double newlines
	| split("\n\n+"; "")
	# now we have an array of "paragraphs"

	| map(
		# ignore extra blanks (usually completely empty file)
		select(. != "")

		# split on newlines that are not followed by space or tab
		| split("\n(?![ \t])"; "")
		# now we have an array of "fields"

		| map(
			index(":") as $colon
			| select($colon) # ignore malformed lines that miss a colon
			| { (.[0:$colon]): (
				.[$colon+1:]
				| gsub("^[ \t]+|[ \t]+$"; "")
				| gsub("[ \t]*\n[ \t]*"; "\n")
			) }
		)
		| add
	)
;

# TODO convert the above output back into deb822
#def deb822_string:
#;
