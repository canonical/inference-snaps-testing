#!/bin/bash -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting configuration variables"
source "${SCRIPT_DIR}/env.bash"

source "${SCRIPT_DIR}/../agent-scripts/test-vlm.sh"
