# ansible-hacking
A collection of scripts to make hacking on Ansible easier.

## bootstrap.sh
Set up your environment with everything you need to develop and test Ansible. 
Python modules are installed using your choice of OS packages or pip.
The following platforms are currently supported, with the tested versions listed.
  * Ubuntu
    * 14.04 LTS (Trusty Tahr)
    * 15.10 (Wily Werewolf)
  * Debian
    * 8 (Jessie)
  * Fedora
    * 20
    * 21
    * 22
  * CentOS
    * 6 (pip only)
    * 7
  * Red Hat

## test-bootstrap.sh
Bootstrap a new LXD container and run tests on the container.

## run-test-bootstrap.sh
Run bootstrap tests on the specified LXD images in parallel.
