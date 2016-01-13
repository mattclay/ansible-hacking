#!/bin/sh -e
# Run bootstrap.sh in a new LXD container.

script=$(readlink -f "$0")
script_path=$(dirname "${script}")

if [ "$#" -lt 2 ]; then
  cat <<- EOF
Usage: lxc-bootstrap.sh image command [option ...]

The image argument is the LXD image you want to test bootstrap.sh with.
The commands and options are those for bootstrap.sh, as follows:

EOF

  "${script_path}/bootstrap.sh" --help-all | grep -A 1000 '^Commands:'

  exit 1
fi

image="$1"

case "${image}" in
  *:*)
    name=$(echo "${image}-$2" | sed 's|^[^:]*:||; s|/|-|g;')
    ;;
  *)
    name="${image}-$2"
    ;;
esac

shift
args="$*"

echo "Checking for existing ${name} container."
if lxc info "${name}" > /dev/null 2>&1; then
  echo "Deleting ${name} container."
  lxc delete "${name}" > /dev/null 2>&1
  echo "Waiting for ${name} container to be deleted."
  while lxc info "${name}" > /dev/null 2>&1; do
    sleep 1
  done
  echo "Successfully deleted ${name} container."
else
  echo "Did not find ${name} container."
fi

echo "Launching ${name} container from ${image} image."
lxc launch "${image}" "${name}"

echo "Waiting for networking to come up in ${name} container."
while ! lxc info "${name}" | grep 'eth0:' > /dev/null 2>&1; do
  sleep 1
done
echo "Networking is up in ${name} container."

echo "Pushing bootstrap.sh to ${name} container."
"${script_path}/lxc-push.sh" \
  "${script_path}/bootstrap.sh" \
  "${name}/root/bootstrap.sh"

echo "Executing bootstrap.sh in ${name} container."
# shellcheck disable=SC2086
lxc exec "${name}" -- /root/bootstrap.sh ${args}

echo "Completed bootstrap.sh in ${name} container."
