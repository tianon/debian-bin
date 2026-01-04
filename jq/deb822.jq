# https://manpages.debian.org/testing/dpkg-dev/deb822.5.en.html

# given a stream of deb822-formatted input lines, this outputs a stream of parsed objects (like "deb822_parse" below, but in streaming form)
#
#   jq --raw-input --null-input 'include "deb822"; deb822_stream(inputs) | ...'
#
def deb822_stream(lines):
	foreach (
		lines,
		"" # inject a synthetic blank line at the end of the input stream to make sure we output everything (because we only output on empty lines, when we know an "entry" is done)
		| select(
			# ignore comment lines (optional in the spec, but for documents that should not have them they are invalid syntax anyhow so should be fairly harmless to strip unilaterally)
			startswith("#")
			| not
			# TODO consider splitting this into a separate function, like "filter_inline_pgp_noise" ?
		)
	) as $line ({ accum: {} };
		if $line == "" then
			{ out: .accum, accum: {} }
		else # TODO should we throw an error if a line contains a newline? (that's bad input)
			def _trimstart: until(startswith(" ") or startswith("\t") | not; .[1:]);
			def _trimend: until(endswith(" ") or endswith("\t") | not; .[:-1]);
			del(.out)
			| ($line | _trimstart) as $ltrim
			| ($ltrim | _trimend) as $trim
			| if $ltrim != $line then
				.accum[.cur] += "\n" + $trim
			else
				($trim | index(":")) as $colon
				| if $colon then
					.cur = $trim[:$colon]
					| .accum[.cur] = ($trim[$colon+1:] | _trimstart)
				else . end # ignore malformed lines that miss a colon
			end
		end
		;
		if .out and (.out | length) > 0 then .out else empty end
	)
;

# given a set of potentially inline-signed PGP lines, this strips the "PGP noise" (and assumes nothing exists outside it -- this is NOT signature verification by any stretch of the imagination!)
def filter_inline_pgp_noise(lines):
	foreach lines as $line ({ out: null, stripHash: false, sig: false };
		if .sig then
			.out = null
			| if $line == "-----END PGP SIGNATURE-----" then
				.sig = false
			else . end
		elif .stripHash and ($line | startswith("Hash:")) then
			.out = null
		elif .stripHash and $line == "" then
			. *= { out: null, stripHash: false }
		elif $line == "-----BEGIN PGP SIGNED MESSAGE-----" then
			. *= { out: null, stripHash: true }
		elif $line == "-----BEGIN PGP SIGNATURE-----" then
			. *= { out: null, sig: true }
		else
			.out = $line
		end
	; if .out then .out else empty end)
;

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
	[
		deb822_stream(
			filter_inline_pgp_noise(
				split("\n")[]
			)
		)
	]
;

# TODO convert the above output back into deb822
#def deb822_string:
#;
