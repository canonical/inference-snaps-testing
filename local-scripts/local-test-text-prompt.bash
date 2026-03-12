#!/bin/bash -eu
echo "Moving to script directory"
cd "$(dirname "$0")"
pwd

# The outer testflinger action uses groups for logging. Close its existing one, so we can use our own.
echo "::endgroup::"

echo "::group::Setting configuration variables"
  source env.bash
echo "::endgroup::"

# For consistency we source all the sub-scripts
# Some of them export env vars we need later during the test
source ../agent-scripts/run-scripts.sh

echo "::group::Testflinger cleanup"
