#!/bin/sh -e
# Copy a single file or directory to an LXD container.

process_args() {
  source="$1"
  IFS='/' read -r container path <<- EOF
$2
EOF

  if [ "${source}" = "" ] ||
     [ "${container}" = "" ] ||
     [ "${path}" = "" ]; then
       help=1
  fi

  path="/${path}"
}

show_help() {
  if [ ! ${help} ]; then return; fi

  cat <<- EOF
Usage: lxc-push.sh <source> <container>/<path>

Source and path must both be a directory or a file.
Path will be created if necessary.
EOF

  exit 0
}

push() {
  if [ -d "${source}" ]; then
    push_directory
  elif [ -f "${source}" ]; then
    push_file
  else
    echo "Source is not a file or directory."
    exit 1
  fi
}

push_directory() {
  device="lxc-push-$$.tmp"
  tmp="/tmp/${device}"

  lxc config device add "${container}" "${device}" \
    disk "source=${source}" "path=${tmp}" > /dev/null

  lxc exec "${container}" -- cp -a --no-preserve=ownership \
    "${tmp}" "${path}" || cleanup_directory 1

  cleanup_directory 0
}

cleanup_directory() {
  lxc config device remove "${container}" "${device}" > /dev/null
  lxc exec "${container}" -- rmdir "${tmp}"

  exit "$1"
}

push_file() {
  mode=$(stat --format '%a' "${source}")
  # work-around for overwrite bug in lxc file push
  lxc exec "${container}" -- rm -f "${path}"
  lxc file push "--mode=${mode}" "${source}" "${container}/${path}"
}

main() {
  process_args "$@"
  show_help
  push
}

main "$@"

exit 0
