#!/bin/bash -eu

# Force select an engine if variable is set
if [[ -n "${SELECT_ENGINE}" ]]; then
  echo "::group::Manually selecting engine"
  # Engine might install multiple large components.
  # Retry periodically to install missing components.
  max_retries=30
  retry_count=0
  retry_delay=60
  until _run sudo "$SNAP_NAME" use-engine "$SELECT_ENGINE"; do
    retry_count=$((retry_count + 1))
    if [ $retry_count -ge $max_retries ]; then
      echo "Get logs"
      _run sudo journalctl -a | grep "$SNAP_NAME"
      echo "::error::Machine: $dut_hostname, failed to use-engine after trying $((max_retries * 30)) seconds"
      exit 1
    fi
    echo "✘ $SNAP_NAME use-engine failed, retrying in ${retry_delay}s... ($retry_count/$max_retries)"
    sleep $retry_delay
  done
  echo "✔ Selecting engine succeeded"

  # Restart server after changing engine
  _run sudo snap restart "$SNAP_NAME"
  wait_for_snap_changes

  # Set expected engine to the selected one
  EXPECTED_ENGINE=$SELECT_ENGINE
  echo "::endgroup::"
fi

echo "::group::Checking selected engine"
selected_engine=$(_run "$SNAP_NAME" status --format=json | jq -r .engine)
echo "Selected engine: $selected_engine"

if [[ -n "${EXPECTED_ENGINE}" ]]; then
  if [ "$EXPECTED_ENGINE" != "$selected_engine" ]; then
    echo "::error::Machine: $dut_hostname, incorrect engine selected: $selected_engine"
    exit 1
  fi
fi
echo "::endgroup::"
