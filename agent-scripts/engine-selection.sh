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
# Retry up to 5 times if use-engine exits with a non-zero exit code.
max_timeout=7200
poll_interval=30
max_retries=5
use_engine_exit_code=1
start_time=$(date +%s)

for attempt in $(seq 1 $max_retries); do
  echo "▶ Running $SNAP_NAME use-engine (attempt $attempt/$max_retries)..."

  _run sudo "$SNAP_NAME" use-engine "$SELECT_ENGINE" &
  use_engine_pid=$!

  while kill -0 "$use_engine_pid" 2>/dev/null; do
    sleep "$poll_interval"
    elapsed=$(( $(date +%s) - start_time ))
    echo "⏳ $SNAP_NAME use-engine still running... elapsed: ${elapsed}s"

    if [ "$elapsed" -ge "$max_timeout" ]; then
      echo "::error::Machine: $dut_hostname, failed to use-engine after ${elapsed}s (timeout: ${max_timeout}s)"
      kill "$use_engine_pid" 2>/dev/null || true
      wait "$use_engine_pid" 2>/dev/null || true
      echo "Get logs"
      _run sudo journalctl -a | grep "$SNAP_NAME"
      echo "::endgroup::"
      exit 1
    fi
  done

  wait "$use_engine_pid"
  use_engine_exit_code=$?
  elapsed=$(( $(date +%s) - start_time ))

  if [ "$use_engine_exit_code" -eq 0 ]; then
    echo "✔ Selecting engine succeeded (attempt $attempt/$max_retries, elapsed: ${elapsed}s)"
    break
  fi

  echo "✘ use-engine failed after ${elapsed}s with exit code $use_engine_exit_code (attempt $attempt/$max_retries)"
  if [ "$attempt" -ge "$max_retries" ]; then
    echo "Get logs"
    _run sudo journalctl -a | grep "$SNAP_NAME"
    echo "::error::Machine: $dut_hostname, use-engine failed after $max_retries attempts"
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
