#!/bin/sh -e
# Run lxc-test.sh on LXD containers in parallel.

process_args() {
  script=$(readlink -f "$0")
  script_path=$(dirname "${script}")

  while [ "$1" ]; do
    case "$1" in
      "-c" | "--container")
        shift
        containers="${containers} $1"
        ;;
      "-f" | "--file")
        shift
        contents=$(grep -v '^#' "$1")
        containers="${containers} ${contents}"
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
        echo "Unknown argument: $1"
        exit 1
        ;;
    esac
    shift
  done

  if [ "${containers}" = "" ]; then
    help=1
  fi
}

show_help() {
  if [ ! ${help} ]; then return; fi

  cat <<- EOF
Usage: lxc-parallel-test.sh source [...] -- [argument...] -- [option...]

Sources:

  -c, --container name      An LXD container to run tests against.
  -f, --file list           A file listing LXD containers, one per line.
                            Lines starting with a # are considered comments.

EOF

  "${script_path}/lxc-test.sh" | grep -A 1000 '^Arguments:'

  exit 0
}

test_container() {
  echo "Starting test of ${container} in the background."
  # shellcheck disable=SC2086
  "${script_path}/lxc-test.sh" \
    "${container}" \
    ${options} \
    > "${container}.log" 2>&1 &
  pid=$!
  echo "PID ${pid} is running test of ${container}."
  pids="${pids} ${pid}"
}

run_tests() {
  for container in ${containers}; do
    test_container
  done

  echo "Waiting for tests to complete."
  # shellcheck disable=SC2086
  wait_all ${pids}
}

wait_all() {
  while [ $# -gt 0 ]; do
    for pid in "$@"; do
      shift
      if kill -0 "${pid}" 2> /dev/null; then
        set -- "$@" "${pid}"
      elif wait "${pid}"; then
        echo "PID ${pid} exited with zero exit status."
      else
        echo "PID ${pid} exited with non-zero exit status."
      fi
    done
    sleep 1
  done
}

main() {
  process_args "$@"
  show_help
  run_tests
}

main "$@"

exit 0
