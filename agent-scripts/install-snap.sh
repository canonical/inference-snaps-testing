#!/bin/bash -eu

echo "::group::Installing snap"

# Testflinger has a timeout checking for any output on stdout and stderr.
# The no-wait is to work around this, preventing the snap install step from causing a timeout on a slow internet
# connection. The no-wait, along with wait_for_snap_changes creates output to stdout, which prevents this timeout.

echo "Remove $SNAP_NAME if already installed"
_run sudo snap remove "$SNAP_NAME" --no-wait
wait_for_snap_changes

echo "Installing $SNAP_NAME from $SNAP_CHANNEL"
_run sudo snap install "$SNAP_NAME" --channel "$SNAP_CHANNEL" --no-wait
wait_for_snap_changes

echo "::endgroup::"

# We have run into an issue where we get here, but the snap command is not yet available. It's likely a race condition
# where there are no changes remaining, but snapd is finishing up. It was worse with nemotron-3-nano.
# Wait until the snap executable is available.
echo "::group::Waiting for snap command to be available"
max_retries=20
retry_count=0
retry_delay=30
until _run $SNAP_NAME status; do
  retry_count=$((retry_count + 1))
  if [ $retry_count -ge $max_retries ]; then
    echo "Get logs"
    _run sudo journalctl -a | grep "$SNAP_NAME"
    echo "::error::Machine: $dut_hostname, snap still not available after $((max_retries * 30)) seconds"
    echo "::endgroup::"
    exit 1
  fi
  echo "✘ $SNAP_NAME status failed, retrying in ${retry_delay}s... ($retry_count/$max_retries)"
  sleep $retry_delay
done
echo "✔ Snap status succeeded"
echo "::endgroup::"
