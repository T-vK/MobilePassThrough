#!/usr/bin/env bash
while [[ "$PROJECT_DIR" != */MobilePassThrough ]]; do PROJECT_DIR="$(readlink -f "$(dirname "${PROJECT_DIR:-0}")")"; done
source "$PROJECT_DIR/scripts/utils/common/libs/helpers"

#####################################################################################################
# This script installs all missing and required dependencies and also adds required kernel parameters. It's called like this: `./setup.sh`
# If you want to automatically reboot the system if necessary (e.g. to load new kernel params) run with: `./setup.sh auto`. 
# This won't just reboot the system, but also create a temporary service that will execute `mbpt.sh auto` on the next boot.
# TODO: the service creation shouldn'T be part of setup.sh. It should be in the auto section of mbpt.sh.
#####################################################################################################

mkdir -p "${THIRDPARTY_DIR}"


# TODO: parse requirements.json and install dependencies automatically
# TODO: complete this list
if ! "${COMMON_UTILS_TOOLS_DIR}/commands-available" "wget curl vim screen git crudini remmina spicy genisoimage uuid iasl docker dumpet imake g++ virt-install qemu-system-x86_64 systool"; then
    sudo "$DISTRO_UTILS_DIR/install-dependencies"
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
    sudo "$COMMON_UTILS_SETUP_DIR/set-kernel-params"
    REBOOT_REQUIRED=true
fi

if [[ "$(docker images -q ovmf-vbios-patch 2> /dev/null)" == "" ]]; then
    sudo "$COMMON_UTILS_SETUP_DIR/ovmf-vbios-patch-setup"
else
    echo "[Skipped] Image 'ovmf-vbios-patch' has already been built."
fi

source "$COMMON_UTILS_LIBS_DIR/gpu-check"

if [ "$HAS_INTEL_GPU" = true ]; then
    sudo "$DISTRO_UTILS_DIR/intel-setup"
fi
if [ "$HAS_AMD_GPU" = true ]; then
    sudo "$DISTRO_UTILS_DIR/amd-setup"
fi
if [ "$HAS_NVIDIA_GPU" = true ]; then
    sudo "$DISTRO_UTILS_DIR/nvidia-setup"
fi
if [ "$SUPPORTS_OPTIMUS" = true ]; then
    sudo "$DISTRO_UTILS_DIR/bumblebee-setup"
fi

if [ ! -f "${ACPI_TABLES_DIR}/fake-battery.aml" ]; then
    sudo "$COMMON_UTILS_SETUP_DIR/build-fake-battery-ssdt"
else
    echo "[Skipped] Fake ACPI SSDT battery has already been built."
fi

if [ ! -f "${THIRDPARTY_DIR}/VBiosFinder/vendor/bundle/ruby/3.0.0/bin/coderay" ]; then
    sudo "$DISTRO_UTILS_DIR/vbios-finder-installer/vbiosfinder"
else
    echo "[Skipped] VBiosFinder is already set up."
fi

if [ ! -f "${THIRDPARTY_DIR}/LookingGlass/looking-glass-host.exe" ] || [ ! -f "${THIRDPARTY_DIR}/LookingGlass/client/build/looking-glass-client" ]; then
    sudo "$DISTRO_UTILS_DIR/looking-glass-setup"
else
    echo "[Skipped] Looking Glass is already set up."
fi

echo "> Generating helper-iso for auto Windows Configuration / Driver installation..."
sudo ${MAIN_SCRIPTS_DIR}/generate-helper-iso.sh
# TODO: add check if files have changed and helper iso needs to be regenerated


if [ "$1" = "auto" ]; then
    if [ REBOOT_REQUIRED = true ]; then
        echo "> Creating a temporary service that will run on next reboot and create the Windows VM"
        echo "exit because this has not been tested yet"
        exit # TODO: TEST THIS
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