#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
PROJECT_DIR="${SCRIPT_DIR}"
UTILS_DIR="${PROJECT_DIR}/utils"
DISTRO=$("${UTILS_DIR}/distro-info")
DISTRO_UTILS_DIR="${UTILS_DIR}/${DISTRO}"

source "$DISTRO_UTILS_DIR/kernel-param-utils"

sudo $DISTRO_UTILS_DIR/install-dependencies
sudo $UTILS_DIR/set-kernel-params
sudo $DISTRO_UTILS_DIR/nvidia-setup
sudo $DISTRO_UTILS_DIR/looking-glass-setup

echo "Make sure you didn't get any critical errors above."
echo "Then reboot!"
echo "After the reboot you can run the compatibility-check.sh script."
