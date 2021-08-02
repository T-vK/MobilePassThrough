#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
PROJECT_DIR="$(readlink -f "${SCRIPT_DIR}/..")"
UTILS_DIR="${PROJECT_DIR}/utils"
DISTRO=$("${UTILS_DIR}/distro-info")
DISTRO_UTILS_DIR="${UTILS_DIR}/${DISTRO}"
LOG_BASE_DIR="${PROJECT_DIR}/logs"

# If user.conf doesn't exist use the default.conf
if [ -f "${PROJECT_DIR}/user.conf" ]; then
    echo "> Loading config from ${PROJECT_DIR}/user.conf"
    source "${PROJECT_DIR}/user.conf"
elif [ -f "${PROJECT_DIR}/default.conf" ]; then
    echo "> Warning: No user.conf found, falling back to default.conf"
    echo "> Loading config from ${PROJECT_DIR}/default.conf"
    source "${PROJECT_DIR}/default.conf"
else
    echo "> Error: No user.conf or user.conf found!"
    exit
fi

sudo virsh destroy --domain "${VM_NAME}"
sudo virsh undefine --domain "${VM_NAME}" --nvram