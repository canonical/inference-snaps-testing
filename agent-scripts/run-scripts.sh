SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/setup-agent.sh"
source "${SCRIPT_DIR}/setup-dut.sh"
source "${SCRIPT_DIR}/install-nvidia-driver.sh"
source "${SCRIPT_DIR}/install-intel-npu-driver.sh"
source "${SCRIPT_DIR}/install-snap.sh"
source "${SCRIPT_DIR}/engine-selection.sh"
source "${SCRIPT_DIR}/test-multimodal-prompt.sh" "${SCRIPT_DIR}/circle.jpg"
