#!/bin/sh

image="$1"
name="${image}-$2"
shift
args="$@"

lxc delete "${name}" || exit 1
sleep 3
lxc launch "${image}" "${name}" --ephemeral || exit 1
lxc file push --mode=0755 bootstrap.sh "${name}/root/" || exit 1
lxc file push --mode=0755 vmtest.sh "${name}/root/" || exit 1
lxc exec "${name}" -- /root/vmtest.sh ${args} || exit 1
lxc exec "${name}" -- /bin/bash

