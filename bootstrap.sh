#!/bin/sh

OS_RELEASE="/etc/os-release"

if [ -f ${OS_RELEASE} ]; then
    . ${OS_RELEASE}
elif [ -f /etc/centos-release ]; then
    ID=centos # CentOS 6 support
    CRYPTO_VERSION=2.6 # Newer EPEL version required
    SKIP_NOSE='skip'
    SKIP_COVERAGE='skip'
    SKIP_MOCK='skip'
    SKIP_REDIS='skip'
    PIP_PACKAGES="
        nose
        coverage
        mock
        redis
        unittest2
    "
else
    echo "Platform not detected due to lack of file:" ${OS_RELEASE}
    exit 1
fi

echo "Platform:" ${ID}

case ${ID} in
    ubuntu)
        echo -n "Checking available packages ... "
        PACKAGES=`apt-cache show \
            make \
            git \
            python \
            python-setuptools \
            python-six \
            python-yaml \
            python-jinja2 \
            python-nose \
            python-mock \
            python-coverage \
            python-crypto \
            python-redis \
            python-memcache \
            python-passlib \
            python-systemd \
            | grep  '^Package: ' \
            | sed 's/^Package: //'`
        echo "done"
        echo "Available packages:" ${PACKAGES}
        apt-get -y install ${PACKAGES}
        ;;
    centos)
        echo "Installing epel-release for additional package support."
        yum --quiet --assumeyes install epel-release
        echo -n "Checking available packages ... "
        PACKAGES=`yum --quiet info \
            which \
            make \
            git \
            python \
            python-setuptools \
            python-six \
            PyYAML \
            python-jinja2 \
            python-nose${SKIP_NOSE} \
            python-mock${SKIP_MOCK} \
            python-coverage${SKIP_COVERAGE} \
            python-crypto${CRYPTO_VERSION} \
            python-redis${SKIP_REDIS} \
            python-memcached \
            python-passlib \
            systemd-python \
            | grep  '^Name *: ' \
            | sed 's/^Name *: //'`
        echo "done"
        echo "Available packages:" ${PACKAGES}
        yum --quiet --assumeyes install ${PACKAGES}
        if [ "${CRYPTO_VERSION}" != "" ]; then
            # Use the EPEL python-crypto module for the Crypto import.
            CRYPTO_FULL_PATH=`rpm -q -l "python-crypto${CRYPTO_VERSION}" | grep '/Crypto$'`
            CRYPTO_RELATIVE_PATH=`echo "${CRYPTO_FULL_PATH}" | sed 's|^.*/site-packages/||'`
            PACKAGES_PATH=`echo "${CRYPTO_FULL_PATH}" | sed 's|/site-packages/.*$|/site-packages/|'`
            PACKAGES_CRYPTO_PATH="${PACKAGES_PATH}Crypto"
            if [ ! -e "${PACKAGES_CRYPTO_PATH}" ]; then
                echo "Creating symbolic link for python-crypto module version ${CRYPTO_VERSION}"
                ln -s "${CRYPTO_RELATIVE_PATH}" "${PACKAGES_CRYPTO_PATH}"
            fi
        fi
        if [ "${PIP_PACKAGES}" != "" ]; then
            echo "Installing packages via pip:" ${PIP_PACKAGES} 
            easy_install pip
            pip install ${PIP_PACKAGES}
        fi
        ;;
    *)
        echo "Unsupported platform:" ${ID}
        exit 2
        ;;
esac

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
