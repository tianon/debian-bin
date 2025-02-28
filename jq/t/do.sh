#!/usr/bin/env bash
set -Eeuo pipefail

shopt -s nullglob # if * matches nothing, return nothing

dir="$(dirname "$BASH_SOURCE")"
dir="$(readlink -ve "$dir")"

# TODO arguments for choosing a test?  directory?  name?  filtering in/out?
for t in "$dir/"*"/t.jq"; do
	td="$(dirname "$t")"
	tdb="$(basename "$td")"
	echo "- $tdb"
	for input in "$td"/in.* "$td"/in-*.*; do
		args=( --tab -L "$dir/.." --from-file "$t" )

		base="${input#$td/in}"

		ext="${base##*.}"
		inputb="$(basename "$input")"
		if [ "$ext" != 'json' ]; then
			args+=( --raw-input --slurp ) # TODO some way to control slurp behavior? perhaps we always supply --null-input and let input/inputs control slurping in-program? (that's not exactly the same, but probably close enough)
		fi

		output="$td/out${base%.$ext}"
		outputs=( "$output".* )
		case "${#outputs[@]}" in
			0) echo >&2 "error: '$in' missing '$output.*' counterpart"; exit 1 ;;
			1) ;;
			*) echo >&2 "error: '$in' has too many '$output.*' counterparts: ${outputs[*]}"; exit 1 ;;
		esac
		output="${outputs[0]}"
		outputExt="${output##*.}"
		outputb="$(basename "$output")"
		if [ "$outputExt" != 'json' ]; then
			args+=( --raw-output )
		fi

		echo "  - $inputb => $outputb"
		jq "${args[@]}" "$input" > "$output"
	done
done
