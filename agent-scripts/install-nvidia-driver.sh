#!/bin/bash -eu

if [[ -n "${INSTALL_NVIDIA_DRIVER_VERSION}" ]]; then
  echo "::group::Installing NVIDIA driver $INSTALL_NVIDIA_DRIVER_VERSION"
  _run sudo apt-get update
  _run sudo apt-get install -y nvidia-driver-$INSTALL_NVIDIA_DRIVER_VERSION

  # Reboot the device to load NVIDIA drivers
  # In background to avoid breaking the SSH connection prematurely
  echo "Rebooting the device"
  ssh ubuntu@$DEVICE_IP "(sleep 3 && sudo reboot) &"

  # Wait for shutdown to happen
  sleep 10

  # Wait for reboot
  wait_for_ssh --allow-degraded || exit 1
  echo "::endgroup::"
fi