#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
PROJECT_DIR="${SCRIPT_DIR}"
UTILS_DIR="${PROJECT_DIR}/utils"
DISTRO=$("${UTILS_DIR}/distro-info")
DISTRO_UTILS_DIR="${UTILS_DIR}/${DISTRO}"

source "$DISTRO_UTILS_DIR/kernel-param-utils"

sudo $DISTRO_UTILS_DIR/install-dependencies
sudo $DISTRO_UTILS_DIR/set-kernel-params
sudo $DISTRO_UTILS_DIR/nvidia-setup
prepare-vm

echo "You should probably reboot now!"
echo "But first make sure you didn't get any errors above."
echo "After the reboot you might want to run the compatibility-check script."

