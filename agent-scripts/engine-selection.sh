#!/bin/bash -eu

# Select an engine if the configuration is set, otherwise do auto selection
# This is to trigger component download in case it failed during installation

if [[ -n "${SELECT_ENGINE}" ]]; then
  # Set expected engine to the selected one
  EXPECTED_ENGINE=$SELECT_ENGINE
else
  SELECT_ENGINE="--auto"
fi

echo "::group::Selecting engine"
# Engine might install multiple large components and can run for a long time
# without producing any output. Run in the background and print elapsed time
# periodically so the CI runner does not consider the job stalled.
# Retry if use-engine exits with a non-zero exit code.
select_timeout=7200
poll_interval=30
max_retries=5
start_time=$(date +%s)

for attempt in $(seq 1 $max_retries); do
  echo "Running \"$SNAP_NAME use-engine\" (attempt $attempt/$max_retries)"

  _run sudo "$SNAP_NAME" use-engine "$SELECT_ENGINE" &
  use_engine_pid=$!

  # Background poller: print elapsed time periodically to avoid CI timeout,
  # and kill use-engine if the global timeout is exceeded.
  (
    while kill -0 "$use_engine_pid" 2>/dev/null; do
      sleep "$poll_interval"
      elapsed=$(( $(date +%s) - start_time ))
      echo "⏳ still running: ${elapsed}s"

      if [ "$elapsed" -ge "$select_timeout" ]; then
        echo "::error::Machine: $dut_hostname, timeout selecting engine after ${elapsed}s"
        kill "$use_engine_pid" 2>/dev/null || true
        break
      fi
    done
  ) &
  poller_pid=$!

  # Wait and capture use-engine's exit code. Done in an if to avoid exiting the script on non-zero.
  if wait "$use_engine_pid"; then
    exit_code=0
  else
    exit_code=$?
  fi

  # Stop the poller if still running
  kill "$poller_pid" || true
  wait "$poller_pid" || true

  if [ "$exit_code" -eq 0 ]; then
    echo "✔ Selecting engine succeeded"
    break
  fi

  echo "✘ Selecting engine failed with exit code $exit_code (attempt $attempt/$max_retries)"
  if [ "$attempt" -ge "$max_retries" ]; then
    echo "::error::Machine: $dut_hostname, selecting engine failed after $max_retries attempts"
    echo "Get logs"
    _run sudo journalctl -a | grep "$SNAP_NAME"
    echo "::endgroup::"
    exit 1
  fi

  # Check if we hit the timeout
  elapsed=$(( $(date +%s) - start_time ))
  if [ "$elapsed" -ge "$select_timeout" ]; then
    echo "Get logs"
    _run sudo journalctl -a | grep "$SNAP_NAME"
    echo "::endgroup::"
    exit 1
  fi

done

# Restart server after changing engine
_run sudo snap restart "$SNAP_NAME"
wait_for_snap_changes

echo "::endgroup::"

echo "::group::Checking selected engine"
selected_engine=$(_run "$SNAP_NAME" status --format=json | jq -r .engine)
echo "Selected engine: $selected_engine"

if [[ -n "${EXPECTED_ENGINE}" ]]; then
  if [ "$EXPECTED_ENGINE" != "$selected_engine" ]; then
    echo "::error::Machine: $dut_hostname, incorrect engine selected: $selected_engine"
    echo "::endgroup::"
    exit 1
  fi
fi
echo "::endgroup::"
