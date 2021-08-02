#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
PROJECT_DIR="$(readlink -f "${SCRIPT_DIR}/..")"
UTILS_DIR="${PROJECT_DIR}/utils"
DISTRO=$("${UTILS_DIR}/distro-info")
DISTRO_UTILS_DIR="${UTILS_DIR}/${DISTRO}"

mkdir -p "${PROJECT_DIR}/thirdparty"

function commandsAvailable() {
    commandsMissing=()
    for currentCommand in $1; do
        if ! command -v $currentCommand &> /dev/null; then
            commandsMissing+=("$currentCommand")
        fi
    done
    if ((${#commandsMissing[@]})); then
        echo "Missing commands: ${commandsMissing[@]}"
        return 1 # Some commands are missing
    else
        return 0
    fi
}

# TODO: complete this list
if ! commandsAvailable "wget curl vim screen git crudini remmina spicy genisoimage uuid iasl docker dumpet imake g++ virt-install qemu-system-x86_64 systool"; then
    sudo $DISTRO_UTILS_DIR/install-dependencies
else
    echo "[Skipped] Required packages already installed."
fi

source "$DISTRO_UTILS_DIR/kernel-param-utils"

if runtimeKernelHasParam "iommu=1" && \
 runtimeKernelHasParam "amd_iommu=on" && \
 runtimeKernelHasParam "intel_iommu=on" && \
 runtimeKernelHasParam "i915.enable_gvt=1" && \
 runtimeKernelHasParam "kvm.ignore_msrs=1" && \
 runtimeKernelHasParam "rd.driver.pre=vfio-pci"; then 
    REBOOT_REQUIRED=false
    echo "[Skipped] Kernel parameters are already set."
else
    sudo $UTILS_DIR/set-kernel-params
    REBOOT_REQUIRED=true
fi

if [[ "$(docker images -q ovmf-vbios-patch 2> /dev/null)" == "" ]]; then
    sudo $UTILS_DIR/ovmf-vbios-patch-setup
else
    echo "[Skipped] Image 'ovmf-vbios-patch' has already been built."
fi

source "$UTILS_DIR/gpu-check"

if [ "$HAS_INTEL_GPU" = true ]; then
    sudo $DISTRO_UTILS_DIR/intel-setup
fi
if [ "$HAS_AMD_GPU" = true ]; then
    sudo $DISTRO_UTILS_DIR/amd-setup
fi
if [ "$HAS_NVIDIA_GPU" = true ]; then
    sudo $DISTRO_UTILS_DIR/nvidia-setup
fi
if [ "$SUPPORTS_OPTIMUS" = true ]; then
    sudo $DISTRO_UTILS_DIR/bumblebee-setup
fi

if [ ! -f "${PROJECT_DIR}/acpi-tables/fake-battery.aml" ]; then
    sudo $UTILS_DIR/build-fake-battery-ssdt
else
    echo "[Skipped] Fake ACPI SSDT battery has already been built."
fi

if [ ! -f "${PROJECT_DIR}/thirdparty/VBiosFinder/vendor/bundle/ruby/3.0.0/bin/coderay" ]; then
    sudo $DISTRO_UTILS_DIR/vbios-finder-installer/vbiosfinder
else
    echo "[Skipped] VBiosFinder is already set up."
fi

if [ ! -f "${PROJECT_DIR}/thirdparty/LookingGlass/looking-glass-host.exe" ] || [ ! -f "${PROJECT_DIR}/thirdparty/LookingGlass/client/build/looking-glass-client" ]; then
    sudo $DISTRO_UTILS_DIR/looking-glass-setup
else
    echo "[Skipped] Looking Glass is already set up."
fi

#if [ ! -f "${PROJECT_DIR}/thirdparty/schily-tools/mkisofs/OBJ/x86_64-linux-gcc/mkisofs" ]; then
#    sudo $UTILS_DIR/schily-tools-setup
#else
#    echo "[Skipped] Schily Tools is already set up."
#fi

#echo "> Generating vFloppy for auto Widnows Installation..."
#sudo ${SCRIPT_DIR}/generate-autounattend-vfd.sh
# TODO: add check if files have changed and vfd needs to be regenerated

echo "> Generating helper-iso for auto Windows Configuration / Driver installation..."
sudo ${SCRIPT_DIR}/generate-helper-iso.sh
# TODO: add check if files have changed and helper iso needs to be regenerated


if [ "$1" = "auto" ]; then
    if [ REBOOT_REQUIRED = true ]; then
        echo "> Creating a temporary service that will run on next reboot and create the Windows VM"
        echo "exit because this has not been tested yet"
        exit
        sudo echo "[Unit]
Description=MobilePassthroughInitSetup
After=multi-user.target network.target

[Service]
User=root
Group=root
Type=simple
Environment=DISPLAY=:0
WorkingDirectory=${PROJECT_DIR}
ExecStart=$(sudo) -u $(loguser) $(which gnome-terminal) -- bash -c \"${PROJECT_DIR}/mbpt.sh auto\"
Restart=never

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/MobilePassthroughInitSetup.service
        sudo systemctl daemon-reload
        sudo systemctl enable MobilePassthroughInitSetup.service
        echo "> Rebooting in 15 seconds... Press Ctrl+C to reboot now."
        sleep 15
        sudo systemctl --force reboot
    else
        sudo systemctl disable MobilePassthroughInitSetup.service &> /dev/null
        echo "> No reboot required."
    fi
else
    if [ REBOOT_REQUIRED = true ]; then
        echo "> Please reboot to load the new kernel parameters!"
    else
        echo "> No reboot required."
    fi
fi