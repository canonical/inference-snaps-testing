#!/bin/bash -eu

if [ "${INSTALL_INTEL_NPU_DRIVER}" = "true" ]; then
  echo "::group::Installing Intel NPU driver snap"
  _run sudo snap install intel-npu-driver
  wait_for_snap_changes
fi