#!/bin/sh -e
# Clone and start a Parallels OS X VM for testing.

version="$1"

if [ "${version}" = "" ]; then
  echo "usage: osx-parallels-test.sh version";
  exit 1
fi

src="OS X ${version}"
dst="Test ${version}"
host="test-${version}"

if prlctl status "${dst}" > /dev/null 2>&1; then
  prlctl stop "${dst}" --kill
  prlctl delete "${dst}"
fi

prlctl clone "${src}" --name "${dst}" --linked
prlctl start "${dst}"
