#!/bin/bash -eu

echo "::group::Check target machine"
# ensure machine is available before continuing
wait_for_ssh --allow-degraded || exit 1
# Store machine hostname for logging
dut_hostname=$(_run hostname)
export dut_hostname
echo "Target machine: $dut_hostname"
echo "::endgroup::"

echo "::group::Snapd refresh"
set -e

# Due to an issue with kernel components and snapd <2.74, we need to update to snapd from the beta channel.
echo "Current snapd version:"
_run "sudo snap list snapd" || true
echo "Updating snapd to latest"
_run "sudo snap refresh snapd --no-wait" || true

# Wait for snapd update to finish
max_iterations=30
interval=60 # seconds
iteration=0
while true; do
  if wait_for_snap_changes; then
    echo "Checking snapd version"
    _run "sudo snap list snapd" || true
    break
  fi

  # Timeout and fail if it takes too long
  iteration=$((iteration + 1))
  if ((iteration >= max_iterations)); then
    echo "Timeout waiting for snaps to update"
    exit 1
  fi

  # Server is either offline, or there are still snapd changes in progress, wait before checking again
  sleep $interval
done
echo "::endgroup::"

echo "::group::Installing machine dependencies"
_run_retry sudo apt-get install --yes git curl
_run sudo snap install go --classic --no-wait
wait_for_snap_changes
echo "::endgroup::"
