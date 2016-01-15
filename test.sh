#!/bin/sh -e
# Easily run Ansible tests.

process_args() {
  if [ $# -eq 0 ]; then help=1; fi
  if [ "${ANSIBLE_HOME}" = "" ]; then setup=1; fi

  while [ "$1" ]; do
    case "$1" in
      "-s" | "--setup")
        setup=1
        ;;
      "-d" | "--dir")
        shift
        dir="$1"
        ;;
      "-T" | "--tests")
        tests=1
        ;;
      "-i" | "--integration")
        shift
        target="$1"
        ;;
      "-t" | "--tag")
        shift
        tags="${tags}${tags:+,}$1"
        ;;
      "-q" | "--quiet")
        quiet=1
        ;;
      "-h" | "--help")
        help=1
        ;;
      *)
        echo "Unknown argument: $1"
        exit 1
    esac
    shift
  done
}

show_help() {
  if [ ! ${help} ]; then return; fi

  cat <<- 'EOF'
Usage: test.sh [option ...]

Options:

  -s, --setup               Run "env-setup" even if "$ANSIBLE_HOME" is set.
  -d, --dir                 Use dir as the Ansible home directory.
                            Otherwise try "$PWD" and "$PWD/ansible".
  -T, --tests               Run "make tests" from the Ansible directory.
  -i, --integration target  Run the specified Ansible integration test target.
  -t, --tag tag             Comma separated list of integration test tags.
                            If omitted, all tags for the test target will run.
                            May be specified multiple times to add more tags.
  -q, --quiet               Do not include additional log messages.
  -h, --help                Show this help message and exit.

EOF

  exit 0
}

run_setup() {
  if [ ! ${setup} ]; then return; fi

  for src in "${dir}" "${PWD}" "${PWD}/ansible" "${ANSIBLE_HOME}"; do
    if [ -f "${src}/hacking/env-setup" ]; then
      log "Setting up Ansible environment..."
      cd "${src}"
      . "hacking/env-setup"
      setup=""
      break
    fi
  done

  if [ ${setup} ]; then
    cat <<- 'EOF'
Unable to find a valid Ansible home directory.
Do you need to use the --dir option? See --help for details.
EOF

    exit 1
  fi
}

run_tests() {
  if [ ! ${tests} ]; then return; fi

  log "Running Ansible tests..."

  (
    cd "${ANSIBLE_HOME}"
    make tests
  )

  log "Completed Ansible tests."
}

run_integration() {
  if [ "${target}" = "" ]; then return; fi

  log "Running Ansible integration test target '${target}'..."

  if [ "${tags}" = "" ]; then
    log "No tags were specified."
  else
    log "Tags: ${tags}"
  fi

  (
    cd "${ANSIBLE_HOME}/test/integration"
    TEST_FLAGS="--tags ${tags}" make "${target}"
  )

  log "Completed Ansible integration tests."
}

log() {
  if [ ${quiet} ]; then return; fi

  echo "$@"
}

main() {
  process_args "$@"
  show_help
  run_setup
  run_tests
  run_integration
}

main "$@"

exit 0
