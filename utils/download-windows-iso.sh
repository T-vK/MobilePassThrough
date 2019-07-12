#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
PROJECT_DIR="${SCRIPT_DIR}/.."
UTILS_DIR="${PROJECT_DIR}/utils"
DISTRO=$("${UTILS_DIR}/distro-info")
DISTRO_UTILS_DIR="${UTILS_DIR}/${DISTRO}"

if [[ "$WIN10_IMG_ARCH" == "x86" ]] || [[ "$WIN10_IMG_ARCH" == "i386" ]] ; then
    echo "Retrieving the x86 Windows 10 iso URL."
    WINDOWS_10_ISO_URL=$(curl -LsI -o /dev/null -w %{url_effective} "https://www.itechtics.com/?dl_id=71")
else
    echo "Retrieving the x64 Windows 10 iso URL."
    WINDOWS_10_ISO_URL=$(curl -LsI -o /dev/null -w %{url_effective} "https://www.itechtics.com/?dl_id=70")
fi

echo "Making sure the URL comes from a trusted Microsoft domain..."
if [[ $WINDOWS_10_ISO_URL == https://software-download.microsoft.com/* ]] ; then
    echo "Downloading the Windows 10 installation iso."
    wget "$WINDOWS_10_ISO_URL" -O "$VM_FILES_DIR/windows10.iso"
else
    echo "URL validation failed. Please download the Windows 10 iso manually."
    exit 1
fi