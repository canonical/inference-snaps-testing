#!/bin/bash -eux

export SNAP_NAME="gemma3"
export SNAP_CHANNEL="latest/stable"
export SELECT_ENGINE="cpu"
export EXPECTED_ENGINE=""
export EXPECTED_TPS=0
export INSTALL_NVIDIA_DRIVER_VERSION=""
export INSTALL_INTEL_NPU_DRIVER=""
export DEVICE_IP="localhost"
export DEVICE_USER=$USER
export SNAP_CONNECTIONS=""

