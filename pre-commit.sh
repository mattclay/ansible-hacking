#!/bin/sh -e
# Runs checks which should be performed before each commit.

echo "Running shellcheck static analysis."

shellcheck \
  ./*.sh

echo "Checking files for trailing whitespace."

grep ' $' \
  ./*.sh \
  README.md \
  && echo "ERROR: One or more lines end in whitespace (see above)." \
  && exit 1

echo "All checks passed."
