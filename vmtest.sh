#!/bin/bash -e

args="$@"
while ! ping -c1 www.google.com &> /dev/null; do :; done
./bootstrap.sh ${args}
git clone https://github.com/ansible/ansible --recursive
cd ansible
source hacking/env-setup
make tests
