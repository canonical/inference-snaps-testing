#!/bin/bash -eu

if [[ -z "${INSTALL_NVIDIA_DRIVER_VERSION}" ]]; then
  echo "INSTALL_NVIDIA_DRIVER_VERSION is not set; skipping NVIDIA driver installation"
  return 0
fi

echo "::group::Installing NVIDIA driver $INSTALL_NVIDIA_DRIVER_VERSION"
_run_retry sudo apt-get update
_run_retry sudo apt-get install -y nvidia-driver-"$INSTALL_NVIDIA_DRIVER_VERSION"

# Reboot the device to load NVIDIA drivers
# In background to avoid breaking the SSH connection prematurely
echo "Rebooting the device"
ssh "$DEVICE_USER"@"$DEVICE_IP" "(sleep 3 && sudo reboot) &"

# Wait for shutdown to happen
sleep 10

# Wait for reboot
wait_for_ssh --allow-degraded || exit 1
echo "::endgroup::"
