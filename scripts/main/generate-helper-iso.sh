#!/usr/bin/env bash
while [[ "$PROJECT_DIR" != */MobilePassThrough ]]; do PROJECT_DIR="$(readlink -f "$(dirname "${PROJECT_DIR:-0}")")"; done
source "$PROJECT_DIR/scripts/utils/common/libs/helpers"
loadConfig
#####################################################################################################
# This script creates a helper ISO file containing scripts and drivers to fully automate the Windows installation within the VM.
#####################################################################################################

mkdir -p "${HELPER_ISO_FILES_DIR}/bin"
mkdir -p "${HELPER_ISO_FILES_DIR}/scripts"
#if [ ! -f "${HELPER_ISO_FILES_DIR}/bin/AutoHotkeyU64.exe" ]; then
#    echo "> Downloading AutoHotkey..."
#    rm -rf "${HELPER_ISO_FILES_DIR}/tmp"
#    mkdir -p "${HELPER_ISO_FILES_DIR}/tmp"
#    wget "https://autohotkey.com/download/ahk.zip" -O "${HELPER_ISO_FILES_DIR}/tmp/ahk.zip"
#    unzip "${HELPER_ISO_FILES_DIR}/tmp/ahk.zip" -d "${HELPER_ISO_FILES_DIR}/tmp/"
#    echo "> Adding AutoHotkey to iso folder..."
#    cp "${HELPER_ISO_FILES_DIR}/tmp/AutoHotkeyU64.exe" "${HELPER_ISO_FILES_DIR}/bin/"
#    rm -rf "${HELPER_ISO_FILES_DIR}/tmp"
#else
#    echo "> AutoHotkey already exist in iso folder..."
#fi

if [ ! -f "${HELPER_ISO_FILES_DIR}/bin/VC_redist.x64.exe" ]; then
    echo "> Downloading Visual C++ Redistributable Package 2017 x64 for the Looking Glass Host application..."
    wget "https://download.microsoft.com/download/8/9/D/89D195E1-1901-4036-9A75-FBE46443FC5A/VC_redist.x64.exe" -O "${HELPER_ISO_FILES_DIR}/bin/VC_redist.x64.exe"
else
    echo "> Visual C++ Redistributable Package 2017 x64 already exist in iso folder..."
fi

if [ ! -f "${HELPER_ISO_FILES_DIR}/bin/looking-glass-host-setup.exe" ]; then
    #echo "> Downloading Looking Glass Host application..."
    #wget "https://github.com/gnif/LookingGlass/releases/download/${LOOKING_GLASS_VERSION}/looking-glass-host.exe" -O "${HELPER_ISO_FILES_DIR}/bin/looking-glass-host.exe"
    echo "> Copy Looking Glass Host application setup to where we need it..."
    cp "${PROJECT_DIR}/thirdparty/LookingGlass/platform/Windows/looking-glass-host-setup.exe" "${HELPER_ISO_FILES_DIR}/bin/looking-glass-host-setup.exe"
else
    echo "> Looking Glass Host application already exist in iso folder..."
fi

#if [ ! -f "${HELPER_ISO_FILES_DIR}/bin/ivshmem-driver/ivshmem.cat" ] || [ ! -f "${HELPER_ISO_FILES_DIR}/bin/ivshmem-driver/ivshmem.inf" ] || [ ! -f "${HELPER_ISO_FILES_DIR}/bin/ivshmem-driver/ivshmem.pdb" ] || [ ! -f "${HELPER_ISO_FILES_DIR}/bin/ivshmem-driver/ivshmem.sys" ]; then
#    echo "> Downloading IVSHMEM driver..."
#    rm -rf "${HELPER_ISO_FILES_DIR}/tmp"
#    mkdir -p "${HELPER_ISO_FILES_DIR}/tmp"
#    wget "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/upstream-virtio/virtio-win10-prewhql-0.1-161.zip" -O "${HELPER_ISO_FILES_DIR}/tmp/virtio-win10-prewhql.zip"
#    unzip "${HELPER_ISO_FILES_DIR}/tmp/virtio-win10-prewhql.zip" -d "${HELPER_ISO_FILES_DIR}/tmp"
#    rm -f "${HELPER_ISO_FILES_DIR}/tmp/virtio-win10-prewhql.zip"
#    rm -rf "${HELPER_ISO_FILES_DIR}/bin/ivshmem-driver"
#    mkdir -p "${HELPER_ISO_FILES_DIR}/bin/ivshmem-driver"
#    cp "${HELPER_ISO_FILES_DIR}/tmp/Win10/amd64/ivshmem*" "${HELPER_ISO_FILES_DIR}/bin/ivshmem-driver/"
#    #cp -r "${HELPER_ISO_FILES_DIR}/tmp" "${HELPER_ISO_FILES_DIR}/bin/ivshmem-driver"
#    rm -rf "${HELPER_ISO_FILES_DIR}/tmp"
#else
#    echo "> IVSHMEM driver already exist in iso folder..."
#fi

if [ ! -d "${HELPER_ISO_FILES_DIR}/bin/virtio-drivers/Win10" ]; then
    echo "> Downloading virtio drivers..."
    rm -rf "${HELPER_ISO_FILES_DIR}/tmp"
    mkdir -p "${HELPER_ISO_FILES_DIR}/tmp"
    wget "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/upstream-virtio/virtio-win10-prewhql-0.1-161.zip" -O "${HELPER_ISO_FILES_DIR}/tmp/virtio-win10-prewhql.zip"
    mkdir -p "${HELPER_ISO_FILES_DIR}/bin/virtio-drivers"
    unzip "${HELPER_ISO_FILES_DIR}/tmp/virtio-win10-prewhql.zip" -d "${HELPER_ISO_FILES_DIR}/bin/virtio-drivers"
    rm -rf "${HELPER_ISO_FILES_DIR}/tmp"
else
    echo "> virtio drivers already exist in iso folder..."
fi

#if [ ! -f "${HELPER_ISO_FILES_DIR}/bin/devcon.exe" ]; then
#    echo "> Downloading Microsoft's devcon driver tool..."
#    rm -rf "${HELPER_ISO_FILES_DIR}/tmp"
#    mkdir -p "${HELPER_ISO_FILES_DIR}/tmp"
#    wget "https://download.microsoft.com/download/B/5/8/B58D625D-17D6-47A8-B3D3-668670B6D1EB/wdk/Installers/787bee96dbd26371076b37b13c405890.cab" -O "${HELPER_ISO_FILES_DIR}/tmp/devcon.cab"
#    cabextract -d "${HELPER_ISO_FILES_DIR}/tmp" "${HELPER_ISO_FILES_DIR}/tmp/devcon.cab"
#    cp "${HELPER_ISO_FILES_DIR}/tmp/devcon.cab" "${HELPER_ISO_FILES_DIR}/bin/devcon.exe"
#    #TODO: check if installing the cabextract is necessary or if it actually is devcon directly
#    rm -rf "${HELPER_ISO_FILES_DIR}/tmp"
#else
#    echo "> devcon driver tool already exist in iso folder..."
#fi

if [ ! -f "${HELPER_ISO_FILES_DIR}/scripts/chcolatey-install.ps1" ]; then
    echo "> Downloading Chocolatey install script..."
    wget "https://chocolatey.org/install.ps1" -O "${HELPER_ISO_FILES_DIR}/scripts/chcolatey-install.ps1"
else
    echo "> Chocolatey install script already exist in iso folder..."
fi

rm -rf "${HELPER_ISO_FILES_DIR}/tmp"

rm -f "${HELPER_ISO}"

#echo "genisoimage -quiet -input-charset utf-8 -J -joliet-long -r -allow-lowercase -allow-multidot -o \"${HELPER_ISO}\" \"${HELPER_ISO_FILES_DIR}\""
genisoimage -quiet -input-charset utf-8 -J -joliet-long -r -allow-lowercase -allow-multidot -o "${HELPER_ISO}" "${HELPER_ISO_FILES_DIR}" |& grep -v "Warning: "
