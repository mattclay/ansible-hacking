#!/bin/sh -e
# Set up your environment with everything needed for Ansible dev and testing.

process_args() {
  while [ "$1" ]; do
    case "$1" in
      "os")
        mode="os"
        ;;
      "pip")
        mode="pip"
        ;;
      "-y" | "--assumeyes")
        auto="-y"
        ;;
      "-q" | "--quiet")
        quiet="-q"
        ;;
      "-h" | "--help")
        help=1
        ;;
      *)
        echo "Unknown argument: $1"
        exit 1
        ;;
    esac
    shift
  done

  if [ ! ${mode} ]; then
    help=1
  fi
}

show_help() {
  if [ ! ${help} ]; then return; fi

  cat <<- EOF
Usage: bootstrap.sh command [options]

Commands:

  os                Install all packages using OS package management.
                    Python pip will not be used to install any packages.

  pip               Install Python packages (except crypto) using pip.
                    Install non-Python packages with OS package management.

Options:

  -y, --assumeyes   Assume yes for all questions and do not prompt.
  -q, --quiet       Show minimal output.
  -h, --help        Show this help message and exit.

EOF

  exit 1
}

detect_platform() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
  elif [ -f /etc/centos-release ]; then
    # detect CentOS 6 and earlier
    ID=centos
    VERSION_ID=$(grep -o '[0-9]' /etc/centos-release | head -n 1)
  elif [ -f /etc/redhat-release ]; then
    # detect RHEL 6 and earlier
    ID=rhel
    VERSION_ID=$(grep -o '[0-9]' /etc/redhat-release | head -n 1)
  else
    echo "Platform not detected. No supported '/etc/*-release' file found."
    exit 1
  fi

  pip  --version > /dev/null 2>&1 && have_pip=1
  curl --version > /dev/null 2>&1 && have_curl=1

  yum="yum"

  echo "Platform: ${ID}"
  echo " Version: ${VERSION_ID}"
}

apt_setup() {
  if [ "${install_curl}" ]; then curl_package="curl"; fi

  packages="
    make
    git
    ${curl_package}
    python
    python-crypto
  "

  echo "Installing required OS packages:" ${packages}
  apt-get ${quiet} ${auto} install ${packages}
}

yum_setup() {
  install_epel="$1"
  crypto_version="$2"

  if [ "${install_curl}" ]; then curl_package="curl"; fi
  if [ "${install_epel}" ]; then epel_package="epel-release"; fi
  if [ ! "${crypto_version}" ]; then crypto_package="python-crypto"; fi

  packages="
    ${epel_package}
    which
    make
    git
    ${curl_package}
    python
    ${crypto_package}
  "

  echo "Installing required OS packages:" ${packages}
  ${yum} ${quiet} ${auto} install ${packages}

  if [ "${crypto_version}" ]; then
    # EPEL must be installed before the updated python-crypto version
    ${yum} ${quiet} ${auto} install "python-crypto${crypto_version}"
    # The EPEL python-crypto package isn't usable after installation.
    # A symlink is needed to support "import Crypto".
    # A symlink is needed to make the package visible to "pip list".
    pc_path=$(rpm -q -l "python-crypto${crypto_version}" | grep '/Crypto$')
    pc_rpath=$(echo "${pc_path}" | sed 's|^.*/site-packages/||')
    pkg_path=$(echo "${pc_path}" | sed 's|/site-packages/.*$|/site-packages/|')
    crypto_path="${pkg_path}Crypto"
    pkginfo_path=$(echo "${pc_rpath}" | sed 's|/Crypto$||')"/EGG-INFO/PKG-INFO"
    egginfo_path=$(echo "${pc_path}" | sed 's|/Crypto$||')"-info"
    if [ ! -e "${crypto_path}" ] && 
       [ ! -e "${egginfo_path}" ] &&
       [ -d "${pkg_path}/${pc_rpath}" ] &&
       [ -f "${pkg_path}/${pkginfo_path}" ]; then
      echo "Creating symlinks for crypto module version ${crypto_version}."
      ln -s "${pc_rpath}" "${crypto_path}"
      ln -s "${pkginfo_path}" "${egginfo_path}"
    fi
  fi
}

yum_epel_setup() {
  name="$1"
  version="$2"
  if [ "${VERSION_ID}" -le "${version}" ]; then
    if [ ${mode} = "os" ]; then
      echo "${name} ${version} and earlier packages are too old."
      echo "Installation via pip required using: bootstrap.sh pip"
      exit 1
    fi
    # EPEL required for python-crypto without a C compiler
    install_epel=1
    crypto_version="2.6"
  elif [ ${mode} = "os" ]; then
    # EPEL required for the necessary OS packages for Python
    install_epel=1
  fi
  yum_setup "${install_epel}" "${crypto_version}"
}

apt_packages() {
  if [ ${mode} != "os" ]; then return; fi

  echo "Checking available OS packages ... "
  packages=$(apt-cache ${quiet} show \
    python-setuptools \
    python-six \
    python-yaml \
    python-jinja2 \
    python-nose \
    python-mock \
    python-coverage \
    python-redis \
    python-memcache \
    python-passlib \
    python-systemd \
    | grep  '^Package: ' \
    | sed 's/^Package: //')
  echo "Installing OS packages:" ${packages}
  apt-get ${quiet} ${auto} install ${packages}
}

yum_packages() {
  if [ ${mode} != "os" ]; then return; fi

  echo "Checking available OS packages ... "
  packages=$(${yum} ${quiet} ${auto} info \
    python-setuptools \
    python-six \
    PyYAML \
    python-jinja2 \
    python-nose \
    python-mock \
    python-coverage \
    python-redis \
    python-memcached \
    python-passlib \
    systemd-python \
    | grep  '^Name *: ' \
    | sed 's/^Name *: //')
  echo "Installing OS packages:" ${packages}
  ${yum} ${quiet} ${auto} install ${packages}
}

pip_setup() {
  if [ ${mode} != "pip" ]; then return; fi

  if [ ! ${have_pip} ]; then
    if [ ${quiet} ]; then
      silent="--silent"
      show_error="--show-error"
    fi
    url="https://bootstrap.pypa.io/get-pip.py"
    echo "Downloading and installing pip..."
    curl ${silent} ${show_error} ${url} | python
  fi

  python_version=$(python --version 2>&1 | grep -o '[0-9]\.[0-9]')

  if [ "${python_version}" = "2.6" ]; then unittest2_package="unittest2"; fi

  packages="
    six
    PyYAML
    Jinja2
    nose
    mock
    coverage
    redis
    python-memcached
    passlib
    python-systemd
    $unittest2_package
  "

  echo "Installing pip packages:" ${packages} 
  pip ${quiet} install ${packages}
}

os_setup() {
  if [ ${mode} = "pip" ] && [ ! ${have_pip} ] && [ ! ${have_curl} ]; then
    install_curl=1
  fi

  case "${ID}" in
    ubuntu)
      apt_setup
      apt_packages
      ;;
    debian)
      apt_setup
      apt_packages
      ;;
    fedora)
      if [ "${VERSION_ID}" -ge 22 ]; then yum="dnf"; fi
      yum_setup
      yum_packages
      ;;
    centos)
      yum_epel_setup "CentOS" 6
      yum_packages
      ;;
    rhel)
      yum_epel_setup "RHEL" 6
      yum_packages
      ;;
    *)
      echo "Unsupported platform: ${ID}"
      exit 1
      ;;
  esac

}

success_message() {
  cat <<- EOF

You're almost ready to start hacking on Ansible...

If you haven't already, clone the Ansible repository:

    git clone https://github.com/ansible/ansible --recursive

To update your Ansible code, run the following from your ansible directory:

    hacking/update.sh

In each shell you use, run the following from your ansible directory:

    source hacking/env-setup

That's it!

EOF
}

main() {
  process_args "$@"
  show_help
  detect_platform
  os_setup
  pip_setup
  success_message
}

main "$@"

exit 0
