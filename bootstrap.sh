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
      "brewdo")
        mode="brewdo"
        ;;
      "-t" | "--test")
        test=1
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
      "--help-all")
        help=1
        help_all=1
        ;;
      "--as-platform")
        shift
        set_platform=1
        as_platform="$1"
        ;;
      "--as-version")
        shift
        set_version=1
        as_version="$1"
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
Usage: bootstrap.sh command [option ...]

Platform: ${ID:-Not Detected}
 Version: ${VERSION_ID:-Not Detected}

Commands:
EOF

  if [ $help_all ]; then
    commands="os pip brewdo"
    cat <<- EOF

  Command availability depends on platform and version.
EOF
  elif [ "${ID}" = "" ] || [ "${VERSION_ID}" = "" ]; then
    cat <<- EOF

  Platform or version not detected. No commands available.
EOF
  elif [ "${commands}" = "" ]; then
    cat <<- EOF

  Platform or version not supported. No commands available.
EOF
  else
    cat <<- EOF

  Commands available for the detected platform and version.
EOF
  fi

  for command in ${commands}; do

  if [ "${command}" = "os" ]; then
    cat <<- EOF

  os                Install all packages using OS package management.
                    Python pip will not be used to install any packages.
EOF
  fi

  if [ "${command}" = "pip" ]; then
    cat <<- EOF

  pip               Install Python packages (except crypto) using pip.
                    Install non-Python packages with OS package management.
EOF
  fi

  if [ "${command}" = "brewdo" ]; then
    cat <<- EOF

  brewdo            Install using a combination of brewdo and pip.
EOF
  fi
  done

  cat <<- EOF

Options:

  -y, --assumeyes   Assume yes for all questions and do not prompt.
  -q, --quiet       Show minimal output.
  -h, --help        Show this help message and exit.
      --help-all    Show help for all commands and exit.
  -t, --test        Clone the Ansible GitHub repository and run tests.

EOF

  exit 0
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
  elif VERSION_ID=$(sw_vers -productVersion 2> /dev/null); then
    ID=osx
  fi

  if [ ${set_platform} ]; then
    ID="${as_platform}"
  fi

  if [ ${set_version} ]; then
    VERSION_ID="${as_version}"
  fi
}

review_platform() {
  case "${ID}" in
    ubuntu)
      major_version=$(echo "${VERSION_ID}" | awk -F "." '{print $1}')
      if [ "${major_version}" -ge 14 ]; then
        commands="os pip"
      fi
      ;;
    debian)
      commands="os pip"
      ;;
    fedora)
      commands="os pip"
      ;;
    centos)
      if [ "${VERSION_ID}" -ge 7 ]; then
        commands="os pip"
      elif [ "${VERSION_ID}" -ge 6 ]; then
        commands="pip"
      fi
      ;;
    rhel)
      if [ "${VERSION_ID}" -ge 7 ]; then
        commands="os pip"
      elif [ "${VERSION_ID}" -ge 6 ]; then
        commands="pip"
      fi
      ;;
    osx)
      major_version=$(echo "${VERSION_ID}" | awk -F "." '{print $1}')
      minor_version=$(echo "${VERSION_ID}" | awk -F "." '{print $2}')
      if [ "${major_version}" -eq 10 ] && [ "${minor_version}" -ge 9 ]; then
        commands="brewdo"
      fi
      ;;
  esac
}

check_platform() {
  for command in ${commands}; do
    if [ "${mode}" = "${command}" ]; then
      valid_mode=1
    fi
  done

  if [ ! ${valid_mode} ]; then
    cat <<- EOF
Command '${mode}' is not valid for this platform or version.
See available commands with: bootstrap.sh --help
EOF
    exit 1
  fi

  pip  --version > /dev/null 2>&1 && have_pip=1
  curl --version > /dev/null 2>&1 && have_curl=1

  yum="yum"

  if [ ${mode} = "pip" ] && [ ! ${have_pip} ] && [ ! ${have_curl} ]; then
    install_curl=1
  fi
}

osx_setup() {
  if xcode-select --print-path > /dev/null 2>&1; then return; fi

  # Install CLI tools without any GUI prompts.
  # Based on the solution found on Stack Exchange here:
  # http://apple.stackexchange.com/questions/107307

  # Create file checked by CLI updates' .dist code in Apple's SUS catalog.
  # Command Line Tools will not appear in the update list without this.
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

  echo "Finding Command Line Tools software update ..."
  update=$(softwareupdate -l \
    | grep '^ *\* *Command Line Tools ' \
    | head -n 1 \
    | sed -e 's/^ *\* *//')

  echo "Installing software update: ${update} ..."
  softwareupdate --install "${update}"
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

  # shellcheck disable=SC2086
  {
    echo "Installing required OS packages:" ${packages}
    apt-get ${quiet} ${auto} install ${packages}
  }
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

  # shellcheck disable=SC2086
  {
    echo "Installing required OS packages:" ${packages}
    ${yum} ${quiet} ${auto} install ${packages}
  }

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
  if [ "${VERSION_ID}" -le 6 ]; then
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

  # shellcheck disable=SC2086
  {
    echo "Installing OS packages:" ${packages}
    apt-get ${quiet} ${auto} install ${packages}
  }
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

  # shellcheck disable=SC2086
  {
    echo "Installing OS packages:" ${packages}
    ${yum} ${quiet} ${auto} install ${packages}
  }
}

brewdo_setup() {
  if [ ${mode} != "brewdo" ]; then return; fi

  if ! brewdo > /dev/null 2>&1; then
    git clone https://github.com/zigg/brewdo
    (
    cd brewdo
    ./brewdo install
    ./brewdo "do" make install
    )
    rm -rf brewdo
  fi

  brewdo brew install python

  have_pip=1
  pip_wrapper="brewdo do"
  mode="pip"
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
    ${unittest2_package}
    ${pycrypto_package}
  "

  # shellcheck disable=SC2086
  {
    echo "Installing pip packages:" ${packages}
    ${pip_wrapper} pip ${quiet} install ${packages}
  }
}

os_setup() {
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
      yum_epel_setup
      yum_packages
      ;;
    rhel)
      yum_epel_setup
      yum_packages
      ;;
    osx)
      osx_setup
      brewdo_setup
      # pycrypto needs to be installed via pip
      pycrypto_package="pycrypto"
      ;;
  esac
}

test_ansible() {
  if [ ! ${test} ]; then return; fi

  git clone https://github.com/ansible/ansible --recursive
  cd ansible
  . hacking/env-setup
  make tests
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
  detect_platform
  review_platform
  show_help
  check_platform
  os_setup
  pip_setup
  success_message
  test_ansible
}

main "$@"

exit 0
