#!/bin/bash -eu

# Force select an engine if variable is set
if [[ -n "${SELECT_ENGINE}" ]]; then
  echo "::group::Manually selecting engine"
  # Engine might install two large components
  # If the first one times out, try again to trigger the second one.
  _run sudo "$SNAP_NAME" use-engine "$SELECT_ENGINE" || true
  wait_for_snap_changes
  _run sudo "$SNAP_NAME" use-engine "$SELECT_ENGINE" || true
  wait_for_snap_changes
  _run sudo "$SNAP_NAME" use-engine "$SELECT_ENGINE"
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
