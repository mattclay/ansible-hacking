#!/bin/sh -e
# Run test-bootstrap.sh on the specified LXD images in parallel.

script=$(readlink -f "$0")
script_path=$(dirname "${script}")

if [ "$#" -eq 0 ]; then
  cat <<- EOF
Usage: run-test-bootstrap.sh -f image-list ... [option ...]
Usage: run-test-bootstrap.sh image ... [option ...]

Arguments:

  image-list        A text file containing a list of LXD images, one per line.
                    Lines starting with a # are considered comments.

  image             An LXD image to run tests against.

EOF

  "${script_path}/bootstrap.sh" | grep -A 1000 '^Options:'

  exit 1
fi

if [ "$1" = "-f" ]; then
  shift
  file=1
fi

for arg in "$@"; do
  case "${arg}" in
    "-"*)
      options="${options} ${arg}"
      ;;
    *)
      if [ ${file} ]; then
        contents=$(grep -v '^#' "${arg}")
        images="${images} ${contents}"
      else
        images="${images} ${arg}"
      fi
      ;;
  esac
done

for image in ${images}; do
  for command in os pip; do
    name="${image}-${command}"
    echo "Starting test of ${name} in the background."
    # shellcheck disable=SC2086
    "${script_path}/test-bootstrap.sh" "${image}" "${command}" ${options} > "${name}.log" 2>&1 &
    pid=$!
    echo "PID ${pid} is running test of ${name}."
    pids="${pids} ${pid}"
  done
done

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

echo "Waiting for tests to complete."
# shellcheck disable=SC2086
wait_all ${pids}
