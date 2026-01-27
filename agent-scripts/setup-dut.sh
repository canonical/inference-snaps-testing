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
# Don't refresh snaps automatically
_run sudo snap refresh --hold=3h --no-wait
# On UC22, the kernel, core, snapd snaps get refreshed right after first boot,
# causing unexpected errors and triggering a reboot
# On UC24, the auto refresh starts after a delay while testing
echo "Force refresh snaps for consistency"
_run sudo snap refresh --no-wait
wait_for_snap_changes
echo "::endgroup::"

echo "::group::Installing machine dependencies"
_run sudo apt-get install --yes git
_run sudo snap install go --classic --no-wait
echo "::endgroup::"