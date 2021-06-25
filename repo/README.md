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

To validate and move files from `incoming/xxx` into the appropriate `pool/xxx` subdirectories, invoke `incoming.sh`.

To build source packages for a particular arch+suite+component combination, invoke `buildd.sh` and then use `dput-local` to copy the `.changes` files into the appropriate `incoming/xxx` directory.

Full (simplified) workflow:

```console
$ # set up metadata.json
$ cat .../repo/metadata.json
{"suites":{"debian-buster":{"architectures":["amd64","source"],"components":["stable"]}}}

$ # initialize the (empty) repository
$ ./apt-ftparchive-wrapper.sh .../repo

$ # get some source packages installed into the repo
$ dsc-from-source .../repo/incoming/debian-buster/stable .../path/to/package/checkout
$ ./incoming.sh .../repo
$ ./apt-ftparchive-wrapper.sh .../repo

$ # build those source packages for a target architecture and install the results into the repo
$ ./buildd.sh /tmp/sbuild amd64 .../repo debian-buster stable
$ dput-local .../repo/incoming/debian-buster/stable /tmp/sbuild/*.changes
$ ./incoming.sh .../repo
$ ./apt-ftparchive-wrapper.sh .../repo

$ # publish .../repo somewhere
$ rsync --archive --delete --exclude=.cache .../repo/ apt.example.com:static/

$ # profit
$ echo 'deb [ allow-insecure=yes trusted=yes ] https://apt.example.com debian-buster stable' > /etc/apt/sources.list.d/example.list
```
