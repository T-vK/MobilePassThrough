#!/usr/bin/env bash
while [[ "$PROJECT_DIR" != */MobilePassThrough ]]; do PROJECT_DIR="$(readlink -f "$(dirname "${PROJECT_DIR:-0}")")"; done
source "$PROJECT_DIR/scripts/utils/common/libs/helpers"

#####################################################################################################
# This script installs all missing and required dependencies and also adds required kernel parameters. It's called like this: `./setup.sh`
# If you want to automatically reboot the system if necessary (e.g. to load new kernel params) run with: `./setup.sh auto`. 
# This won't just reboot the system, but also create a temporary service that will execute `mbpt.sh auto` on the next boot.
# TODO: the service creation shouldn'T be part of setup.sh. It should be in the auto section of mbpt.sh.
#####################################################################################################

source "${PROJECT_DIR}/requirements.sh"
source "$COMMON_UTILS_LIBS_DIR/cpu-check"
source "$COMMON_UTILS_LIBS_DIR/gpu-check"

alias getExecPkg="'${COMMON_UTILS_TOOLS_DIR}/install-packages' --executables"
alias getFilePkg="'${COMMON_UTILS_TOOLS_DIR}/install-packages' --files"
alias kernelParamManager="'${KERNEL_PARAM_MANAGER}'"
alias runtimeKernelHasParams="'${COMMON_UTILS_TOOLS_DIR}/runtime-kernel-has-params'"

mkdir -p "${THIRDPARTY_DIR}"

echo "> Find and install packages containing executables that we need..."
getExecPkg "$ALL_EXEC_DEPS" # Find and install packages containing executables that we need
echo "> Find and install packages containing files that we need..."
getFilePkg "$ALL_FILE_DEPS" # Find and install packages containing specific files that we need

REBOOT_REQUIRED=false
if ! runtimeKernelHasParams "${KERNEL_PARAMS_GENERAL[*]}"; then
    echo "> Adding general kernel params..."
    kernelParamManager add "${KERNEL_PARAMS_GENERAL[*]}"
    REBOOT_REQUIRED=true
else
    echo "> [Skipped] General kernel params already set on running kernel..."
    REBOOT_REQUIRED=false
fi

#if [ "$HAS_INTEL_CPU" = true ]; then
    if ! runtimeKernelHasParams "${KERNEL_PARAMS_INTEL_CPU[*]}"; then
        echo "> Adding Intel CPU-specific kernel params..."
        kernelParamManager add "${KERNEL_PARAMS_INTEL_CPU[*]}"
        REBOOT_REQUIRED=true
    else
        echo "> [Skipped] Intel CPU-specific kernel params already set on running kernel..."
    fi
#fi

#if [ "$HAS_AMD_CPU" = true ]; then
    if ! runtimeKernelHasParams "${KERNEL_PARAMS_AMD_CPU[*]}"; then
        echo "> Adding AMD CPU-specific kernel params..."
        kernelParamManager add "${KERNEL_PARAMS_AMD_CPU[*]}"
        REBOOT_REQUIRED=true
    else
        echo "> [Skipped] AMD CPU-specific kernel params already set on running kernel..."
    fi
#fi

#if [ "$HAS_INTEL_GPU" = true ]; then
    if ! runtimeKernelHasParams "${KERNEL_PARAMS_INTEL_GPU[*]}"; then
        echo "> Adding Intel GPU-specific kernel params..."
        kernelParamManager add "${KERNEL_PARAMS_INTEL_GPU[*]}"
        REBOOT_REQUIRED=true
    else
        echo "> [Skipped] Intel GPU-specific kernel params already set on running kernel..."
    fi
#fi

if [ "$HAS_NVIDIA_GPU" = true ]; then # TODO: Don't force Bumblebee and the proprietary Nvidia driver upon the user
    if ! runtimeKernelHasParams "${KERNEL_PARAMS_BUMBLEBEE_NVIDIA[*]}"; then
        echo "> Adding Nvidia GPU-specific kernel params..."
        kernelParamManager add "${KERNEL_PARAMS_BUMBLEBEE_NVIDIA[*]}"
        REBOOT_REQUIRED=true
    else
        echo "> [Skipped] Nvidia GPU-specific kernel params already set on running kernel..."
    fi
fi

if [[ "$(docker images -q ovmf-vbios-patch 2> /dev/null)" == "" ]]; then
    echo "> Image 'ovmf-vbios-patch' has already been built."
    sudo "$COMMON_UTILS_SETUP_DIR/ovmf-vbios-patch-setup"
else
    echo "> [Skipped] Image 'ovmf-vbios-patch' has already been built."
fi

if [ "$HAS_NVIDIA_GPU" = true ]; then
    sudo "$DISTRO_UTILS_DIR/nvidia-setup"
fi
if [ "$SUPPORTS_OPTIMUS" = true ]; then
    sudo "$DISTRO_UTILS_DIR/bumblebee-setup"
fi

if [ ! -f "${ACPI_TABLES_DIR}/fake-battery.aml" ]; then
    echo "> Building fake ACPI SSDT battery..."
    sudo "$COMMON_UTILS_SETUP_DIR/build-fake-battery-ssdt"
else
    echo "> [Skipped] Fake ACPI SSDT battery has already been built."
fi

if [ ! -f "${THIRDPARTY_DIR}/VBiosFinder/vendor/bundle/ruby/3.0.0/bin/coderay" ]; then
    echo "> Installing VBiosFinder..."
    sudo "$COMMON_UTILS_SETUP_DIR/vbios-finder-setup"
else
    echo "> [Skipped] VBiosFinder is already set up."
fi

if [ ! -f "${THIRDPARTY_DIR}/LookingGlass/looking-glass-host.exe" ] || [ ! -f "${THIRDPARTY_DIR}/LookingGlass/client/build/looking-glass-client" ]; then
    echo "> Installing Looking Glass..."
    sudo "$COMMON_UTILS_SETUP_DIR/looking-glass-setup"
else
    echo "> [Skipped] Looking Glass is already set up."
fi

#if [ ! -f "${THIRDPARTY_DIR}/virtio-win.iso" ]; then
#    echo "> Downlaoding virtio drivers..."
#    sudo "$COMMON_UTILS_SETUP_DIR/download-vfio-drivers"
#else
#    echo "> [Skipped] virtio drivers already downloaded."
#fi

echo "> Generating helper-iso for auto Windows Configuration / Driver installation..."
sudo ${MAIN_SCRIPTS_DIR}/generate-helper-iso.sh
# TODO: add check if files have changed and helper iso needs to be regenerated; maybe by using a checksum?

if [ "$1" = "auto" ]; then
    if [ "$REBOOT_REQUIRED" = true ]; then
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