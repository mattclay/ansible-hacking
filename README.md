# ansible-hacking
A collection of scripts to make hacking on Ansible easier.

## bootstrap.sh
Set up your environment with everything you need to develop and test Ansible. 
On Linux, Python modules are installed using your choice of OS packages or pip.
On OS X, installation is done using a combination of
[brewdo](https://github.com/zigg/brewdo) or brew and pip.
The following platforms are currently supported, with the tested versions listed.
  * Ubuntu (14.04+)
    * 14.04 LTS (Trusty Tahr)
    * 15.04 (Vivid Vervet)
    * 15.10 (Wily Werewolf)
  * Debian (7+)
    * 7 (Wheezy) (pip only)
    * 8 (Jessie)
  * Fedora
    * 20
    * 21
    * 22
  * CentOS (6+)
    * 6 (pip only)
    * 7
  * Red Hat (6+)
  * OS X (10.9+)
    * 10.9 (Mavericks)
    * 10.10 (Yosemite)
    * 10.11 (El Capitan)

Some platform versions have Python modules which are too old.
When this is the case, only the pip command will be available.

NOTE: This script must be run as root, except when using brew.

## lxc-bootstrap.sh
Run bootstrap.sh in a new LXD container.

## lxc-parallel.sh
Run lxc-bootstrap.sh on LXD images in parallel.
Each image will be tested with both the os and pip bootstrap comands.

## osx-parallels-test.sh
Start a new Parallels VM for a specific version of OS X.
Stops and deletes the VM if it already exists.
The VM to clone from must be named "OS X {version}" such as "OS X 10.11".
The VM to clone to will be named "Test {version}" such as "Test 10.11".
