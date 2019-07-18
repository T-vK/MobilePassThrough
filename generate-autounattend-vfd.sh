#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
PROJECT_DIR="${SCRIPT_DIR}"
UTILS_DIR="${PROJECT_DIR}/utils"
DISTRO=$("${UTILS_DIR}/distro-info")
DISTRO_UTILS_DIR="${UTILS_DIR}/${DISTRO}"

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

TMP_DIR="${PROJECT_DIR}/tmp"
VFD_MP="${TMP_DIR}/autounattend-vfd-mountpoint"
VFD_FILE="${VM_FILES_DIR}/autounattend.vfd"

echo "> Creating empty floppy image..."
rm -f "${VFD_FILE}"
fallocate -l 1474560 "${VFD_FILE}"
mkfs.vfat "${VFD_FILE}"

echo "> Copy files onto the floppy image..."
mkdir -p "${VFD_MP}"
sudo mount -o loop "${VFD_FILE}" "${VFD_MP}"
sudo cp -r "${PROJECT_DIR}/autounattend-vfd-files/." "${VFD_MP}/"
sudo umount "${VFD_MP}"
rm -rf "${TMP_DIR}"