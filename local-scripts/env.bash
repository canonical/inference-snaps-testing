#!/bin/bash -eux

export SNAP_NAME="gemma3"
export SNAP_CHANNEL="latest/edge/IENG-2242-shrink-llamacpp-rocm-component-size" #latest/stable
export SELECT_ENGINE="amd-gpu" #cpu
export EXPECTED_ENGINE=""
export EXPECTED_TPS=10 #0
export INSTALL_NVIDIA_DRIVER_VERSION=""
export INSTALL_INTEL_NPU_DRIVER=""
export DEVICE_IP="10.77.215.208" # "localhost"
export DEVICE_USER="ubuntu" #"$USER"
export SNAP_CONNECTIONS="process-control" #""

