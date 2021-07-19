#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
PROJECT_DIR="${SCRIPT_DIR}"
UTILS_DIR="${PROJECT_DIR}/utils"
DISTRO=$("${UTILS_DIR}/distro-info")
DISTRO_UTILS_DIR="${UTILS_DIR}/${DISTRO}"

source "$DISTRO_UTILS_DIR/kernel-param-utils"

sudo $DISTRO_UTILS_DIR/install-dependencies
sudo $UTILS_DIR/set-kernel-params

source "$UTILS_DIR/gpu-check"

if [ $HAS_INTEL_GPU = true ]; then
    sudo $DISTRO_UTILS_DIR/intel-setup
fi
if [ $HAS_AMD_GPU = true ]; then
    sudo $DISTRO_UTILS_DIR/amd-setup
fi
if [ $HAS_NVIDIA_GPU = true ]; then
    sudo $DISTRO_UTILS_DIR/nvidia-setup
fi
if [ $SUPPORTS_OPTIMUS = true ]; then
    sudo $DISTRO_UTILS_DIR/bumblebee-setup
fi

sudo $DISTRO_UTILS_DIR/looking-glass-setup

echo "Make sure you didn't get any critical errors above."
echo "Then reboot!"
echo "After the reboot you can run the compatibility-check.sh script."
