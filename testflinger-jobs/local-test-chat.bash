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
source ../agent-scripts/setup-agent.sh
source ../agent-scripts/setup-dut.sh
source ../agent-scripts/install-nvidia-driver.sh
source ../agent-scripts/install-intel-npu-driver.sh
source ../agent-scripts/install-snap.sh
source ../agent-scripts/engine-selection.sh
source ../agent-scripts/test-chat.sh

echo "::group::Testflinger cleanup"
