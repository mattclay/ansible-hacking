#!/bin/sh -e
# Run lxc-bootstrap.sh on LXD images in parallel.

script=$(readlink -f "$0")
script_path=$(dirname "${script}")

if [ "$#" -eq 0 ]; then
  cat <<- EOF
Usage: lxc-parallel.sh -f image-list ... [option ...]
Usage: lxc-parallel.sh image ... [option ...]

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

container_pids="lxc-parallel-bootstrap.pid"

rm -f "${container_pids}"

for image in ${images}; do
  for command in os pip; do
    name=$(echo "${image}-${command}" | sed 's|^[^:]*:||; s|[^a-z0-9]|-|g;')
    echo "Starting test of ${name} in the background."
    # shellcheck disable=SC2086
    "${script_path}/lxc-bootstrap.sh" "${image}" "${command}" ${options} > "${name}.log" 2>&1 &
    pid=$!
    echo "${pid}:${name}" >> "${container_pids}"
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
        container=$(grep "^${pid}:" "${container_pids}" | sed "s/^${pid}://;")
        echo "Container ${container} exited with zero exit status."
      else
        container=$(grep "^${pid}:" "${container_pids}" | sed "s/^${pid}://;")
        echo "Container ${container} exited with non-zero exit status."
      fi
    done
    sleep 1
  done
}

echo "Waiting for tests to complete."
# shellcheck disable=SC2086
wait_all ${pids}
