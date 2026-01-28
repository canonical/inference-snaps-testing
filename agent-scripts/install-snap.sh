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
# We've run into an issue where we get here, but the snap command is not yet available. It's likely a race condition
# where there are no changes remaining, but snapd is finishing up. Adding a sleep here to mitigate the issue.
sleep 10
echo "::endgroup::"
