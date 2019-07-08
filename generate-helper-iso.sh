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

mkdir -p "${PROJECT_DIR}/mobile-passthrough-iso/bin"
#if [ ! -f "${PROJECT_DIR}/mobile-passthrough-iso/bin/AutoHotkeyU64.exe" ]; then
#    echo "> Downloading AutoHotkey..."
#    rm -rf "${PROJECT_DIR}/mobile-passthrough-iso/tmp"
#    mkdir -p "${PROJECT_DIR}/mobile-passthrough-iso/tmp"
#    wget "https://autohotkey.com/download/ahk.zip" -O "${PROJECT_DIR}/mobile-passthrough-iso/tmp/ahk.zip"
#    unzip "${PROJECT_DIR}/mobile-passthrough-iso/tmp/ahk.zip" -d "${PROJECT_DIR}/mobile-passthrough-iso/tmp/"
#    echo "> Adding AutoHotkey to iso folder..."
#    cp "${PROJECT_DIR}/mobile-passthrough-iso/tmp/AutoHotkeyU64.exe" "${PROJECT_DIR}/mobile-passthrough-iso/bin/"
#    rm -rf "${PROJECT_DIR}/mobile-passthrough-iso/tmp"
#else
#    echo "> AutoHotkey already exist in iso folder..."
#fi

if [ ! -f "${PROJECT_DIR}/mobile-passthrough-iso/bin/VC_redist.x64.exe" ]; then
    echo "> Downloading Visual C++ Redistributable Package 2017 x64 for the Looking Glass Host application..."
    wget "https://download.microsoft.com/download/8/9/D/89D195E1-1901-4036-9A75-FBE46443FC5A/VC_redist.x64.exe" -O "${PROJECT_DIR}/mobile-passthrough-iso/bin/VC_redist.x64.exe"
else
    echo "> Visual C++ Redistributable Package 2017 x64 already exist in iso folder..."
fi

if [ ! -f "${PROJECT_DIR}/mobile-passthrough-iso/bin/looking-glass-host.exe" ]; then
    echo "> Downloading Looking Glass Host application..."
    wget "https://github.com/gnif/LookingGlass/releases/download/${LOOKING_GLASS_VERSION}/looking-glass-host.exe" -O "${PROJECT_DIR}/mobile-passthrough-iso/bin/looking-glass-host.exe"
else
    echo "> Looking Glass Host application already exist in iso folder..."
fi

#if [ ! -f "${PROJECT_DIR}/mobile-passthrough-iso/bin/ivshmem-driver/ivshmem.cat" ] || [ ! -f "${PROJECT_DIR}/mobile-passthrough-iso/bin/ivshmem-driver/ivshmem.inf" ] || [ ! -f "${PROJECT_DIR}/mobile-passthrough-iso/bin/ivshmem-driver/ivshmem.pdb" ] || [ ! -f "${PROJECT_DIR}/mobile-passthrough-iso/bin/ivshmem-driver/ivshmem.sys" ]; then
#    echo "> Downloading IVSHMEM driver..."
#    rm -rf "${PROJECT_DIR}/mobile-passthrough-iso/tmp"
#    mkdir -p "${PROJECT_DIR}/mobile-passthrough-iso/tmp"
#    wget "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/upstream-virtio/virtio-win10-prewhql-0.1-161.zip" -O "${PROJECT_DIR}/mobile-passthrough-iso/tmp/virtio-win10-prewhql.zip"
#    unzip "${PROJECT_DIR}/mobile-passthrough-iso/tmp/virtio-win10-prewhql.zip" -d "${PROJECT_DIR}/mobile-passthrough-iso/tmp"
#    rm -f "${PROJECT_DIR}/mobile-passthrough-iso/tmp/virtio-win10-prewhql.zip"
#    rm -rf "${PROJECT_DIR}/mobile-passthrough-iso/bin/ivshmem-driver"
#    mkdir -p "${PROJECT_DIR}/mobile-passthrough-iso/bin/ivshmem-driver"
#    cp "${PROJECT_DIR}/mobile-passthrough-iso/tmp/Win10/amd64/ivshmem*" "${PROJECT_DIR}/mobile-passthrough-iso/bin/ivshmem-driver/"
#    #cp -r "${PROJECT_DIR}/mobile-passthrough-iso/tmp" "${PROJECT_DIR}/mobile-passthrough-iso/bin/ivshmem-driver"
#    rm -rf "${PROJECT_DIR}/mobile-passthrough-iso/tmp"
#else
#    echo "> IVSHMEM driver already exist in iso folder..."
#fi

if [ ! -d "${PROJECT_DIR}/mobile-passthrough-iso/bin/virtio-drivers/Win10" ]; then
    echo "> Downloading virtio drivers..."
    rm -rf "${PROJECT_DIR}/mobile-passthrough-iso/tmp"
    mkdir -p "${PROJECT_DIR}/mobile-passthrough-iso/tmp"
    wget "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/upstream-virtio/virtio-win10-prewhql-0.1-161.zip" -O "${PROJECT_DIR}/mobile-passthrough-iso/tmp/virtio-win10-prewhql.zip"
    mkdir -p "${PROJECT_DIR}/mobile-passthrough-iso/bin/virtio-drivers"
    unzip "${PROJECT_DIR}/mobile-passthrough-iso/tmp/virtio-win10-prewhql.zip" -d "${PROJECT_DIR}/mobile-passthrough-iso/bin/virtio-drivers"
    rm -rf "${PROJECT_DIR}/mobile-passthrough-iso/tmp"
else
    echo "> virtio drivers already exist in iso folder..."
fi

#if [ ! -f "${PROJECT_DIR}/mobile-passthrough-iso/bin/devcon.exe" ]; then
#    echo "> Downloading Microsoft's devcon driver tool..."
#    rm -rf "${PROJECT_DIR}/mobile-passthrough-iso/tmp"
#    mkdir -p "${PROJECT_DIR}/mobile-passthrough-iso/tmp"
#    wget "https://download.microsoft.com/download/B/5/8/B58D625D-17D6-47A8-B3D3-668670B6D1EB/wdk/Installers/787bee96dbd26371076b37b13c405890.cab" -O "${PROJECT_DIR}/mobile-passthrough-iso/tmp/devcon.cab"
#    cabextract -d "${PROJECT_DIR}/mobile-passthrough-iso/tmp" "${PROJECT_DIR}/mobile-passthrough-iso/tmp/devcon.cab"
#    cp "${PROJECT_DIR}/mobile-passthrough-iso/tmp/devcon.cab" "${PROJECT_DIR}/mobile-passthrough-iso/bin/devcon.exe"
#    #TODO: check if installing the cabextract is necessary or if it actually is devcon directly
#    rm -rf "${PROJECT_DIR}/mobile-passthrough-iso/tmp"
#else
#    echo "> devcon driver tool already exist in iso folder..."
#fi

rm -rf "${PROJECT_DIR}/mobile-passthrough-iso/tmp"

echo "> Generating new iso..."
rm -f "${PROJECT_DIR}/mobile-passthrough.iso"
genisoimage -J -joliet-long -r -allow-lowercase -allow-multidot -o "${VM_FILES_DIR}/mobile-passthrough-helper.iso" "${HELPER_ISO}"
