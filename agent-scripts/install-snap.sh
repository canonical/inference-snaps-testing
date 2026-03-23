#!/bin/bash -eu

echo "::group::Installing snap"

# Testflinger has a timeout checking for any output on stdout and stderr.
# The no-wait is to work around this, preventing the snap install step from causing a timeout on a slow internet
# connection. The no-wait, along with wait_for_snap_changes creates output to stdout, which prevents this timeout.

echo "Remove $SNAP_NAME if already installed"
_run sudo snap remove "$SNAP_NAME" --no-wait
wait_for_snap_changes


# Install snap, retrying if snap is not available after all snap changes are done
max_retries=5
retry_count=0
until _run $SNAP_NAME status; do
  retry_count=$((retry_count + 1))
  if [ $retry_count -gt $max_retries ]; then
    echo "Get logs"
    _run sudo journalctl -a | grep "$SNAP_NAME"
    echo "::error::Machine: $dut_hostname, snap still not available after $((max_retries * 30)) seconds"
    echo "::endgroup::"
    exit 1
  fi

  echo "Installing $SNAP_NAME from $SNAP_CHANNEL"
  _run sudo snap install "$SNAP_NAME" --channel "$SNAP_CHANNEL" --no-wait
  wait_for_snap_changes
done
echo "✔ Snap installed"
echo "::endgroup::"


if [ -n "$SNAP_CONNECTIONS" ]; then
  echo "::group::Snap connections"
  # Temporarily set IFS to a comma just for the 'read' command  
  # -r prevents backslash escaping  
  # -a assigns the result to an array named 'my_array'  
  IFS=',' read -r -a my_array <<< "$SNAP_CONNECTIONS"  

  # Iterate over the new array safely  
  for connection in "${my_array[@]}"; do  
      echo "Processing: $connection"  
      _run sudo snap connect $SNAP_NAME:$connection  
  done
  wait_for_snap_changes
  echo "::endgroup::"
fi
echo "::group::Checking snap connections"
_run sudo snap connections "$SNAP_NAME"
echo "::endgroup::"
