# WIP

This is a loosely coupled set of scripts to try to help manage an APT repo by hand (eventual intention is to automate management via these scripts).

In the repository directory, there should be a `metadata.json` file with the following format:

```json
{
	"suites": {
		"debian-buster": {
			"architectures": [
				"amd64",
				"arm64",
				"...",
				"s390x",
				"source"
			],
			"components": [
				"stable"
			],
			"metadata": {
				"Origin": "Foo"
			}
		},
		"debian-unstable": {
			"...": "..."
		},
		"...": "..."
	}
}
```

Since this gets repetitive if the repository is intended to be the same software maintained/built for several different "target" suites/distros, I maintain this file as `metadata.jq` which can then easily generate `metadata.json` (`jq --tab -nSf metadata.jq > metadata.json`) so that duplication can be managed programmatically.

To generate the primary repository metadata (`dists/xxx`, `pool/xxx`, `incoming/xxx`, etc), invoke `apt-ftparchive-wrapper.sh`.