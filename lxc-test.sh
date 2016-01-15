#!/bin/sh -e
# Run test.sh in an LXD container.

process_args() {
  script=$(readlink -f "$0")
  script_path=$(dirname "${script}")

  dir="ansible"

  while [ "$1" ]; do
    case "$1" in
      "-c" | "--copy")
        shift
        if [ ! -d "$1" ]; then
          echo "$1: not a directory"
          exit 1
        fi
        copy="$1"
        ;;
      "-d" | "--dir")
        shift
        dir="$1"
        ;;
      "-q" | "--quiet")
        quiet=1
        quiet_option="--quiet"
        ;;
      "-h" | "--help")
        help=1
        ;;
      "--")
        shift
        options="$*"
        break
        ;;
      *)
        if [ "${container}" = "" ]; then
          container="$1"
        else
          echo "Unknown argument: $1"
          exit 1
        fi
    esac
    shift
  done

  if [ "${container}" = "" ]; then
    help=1
  fi
}

show_help() {
  if [ ! ${help} ]; then return; fi

  cat <<- EOF
usage: lxc-test.sh container [argument...] -- [option...]

Arguments:

  -c, --copy dir            The Ansible directory to copy into the container.
  -d, --dir dir             The name of the Ansible directory in the container.
                            Passed as an option to test.sh.
                            Defaults to "ansible".
  -q, --quiet               Do not include additional log messages.
                            Passed as an option to test.sh if specified.
  -h, --help                Show this help message and exit.

EOF

  "${script_path}/test.sh" | grep -A 1000 '^Options:'

  exit 0
}

populate_container() {
  if [ "${copy}" = "" ]; then return; fi

  log "Copying Ansible directory '${copy}' to container ${container}."

  "${script_path}/lxc-push.sh" \
    "${copy}" \
    "${container}/root/${dir}"

  log "Copy into container ${container} completed."
}

test_container() {
  log "Copying test.sh to container ${container}."

  "${script_path}/lxc-push.sh" \
    "${script_path}/test.sh" \
    "${container}/root/test.sh"

  log "Executing test.sh in container ${container}."

  # shellcheck disable=SC2086
  lxc exec "${container}" -- "/root/test.sh" \
    ${quiet_option} --dir "${dir}" ${options}

  log "Completed test.sh in container ${container}."
}

log() {
  if [ ${quiet} ]; then return; fi

  echo "$@"
}

main() {
  process_args "$@"
  show_help
  populate_container
  test_container
}

main "$@"

exit 0
