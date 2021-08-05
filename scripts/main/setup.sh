#!/usr/bin/env bash
while [[ "$PROJECT_DIR" != */MobilePassThrough ]]; do PROJECT_DIR="$(readlink -f "$(dirname "${PROJECT_DIR:-0}")")"; done
source "$PROJECT_DIR/scripts/utils/common/libs/helpers"
loadConfig

#####################################################################################################
# This script installs all missing and required dependencies and also adds required kernel parameters. It's called like this: `./setup.sh`
# If you want to automatically reboot the system if necessary (e.g. to load new kernel params) run with: `./setup.sh auto`. 
# This won't just reboot the system, but also create a temporary service that will execute `mbpt.sh auto` on the next boot.
# TODO: the service creation shouldn'T be part of setup.sh. It should be in the auto section of mbpt.sh.
#####################################################################################################

source "${PROJECT_DIR}/requirements.sh"
source "$COMMON_UTILS_LIBS_DIR/cpu-check"
source "$COMMON_UTILS_LIBS_DIR/gpu-check"

alias getMissingExecutables="${COMMON_UTILS_TOOLS_DIR}/get-missing-executables"
alias getMissingFiles="${COMMON_UTILS_TOOLS_DIR}/get-missing-files"
alias updatePkgInfo="'${PACKAGE_MANAGER}' update"
alias getExecPkg="'${PACKAGE_MANAGER}' install --executables"
alias getFilePkg="'${PACKAGE_MANAGER}' install --files"
alias addKernelParams="sudo '${KERNEL_PARAM_MANAGER}' add"
alias runtimeKernelHasParams="${COMMON_UTILS_TOOLS_DIR}/runtime-kernel-has-params"
alias ovmfVbiosPatchSetup="sudo '$COMMON_UTILS_SETUP_DIR/ovmf-vbios-patch-setup'"
alias buildFakeBatterySsdt="sudo '$COMMON_UTILS_SETUP_DIR/build-fake-battery-ssdt'"
alias vbiosFinderSetup="sudo '$COMMON_UTILS_SETUP_DIR/vbios-finder-setup'"
alias lookingGlassSetup="sudo '$COMMON_UTILS_SETUP_DIR/looking-glass-setup'"
alias generateHelperIso="sudo '${MAIN_SCRIPTS_DIR}/generate-helper-iso.sh'"
alias nvidiaSetup="sudo '$DISTRO_UTILS_DIR/nvidia-setup'"
alias bumblebeeSetup="sudo '$DISTRO_UTILS_DIR/bumblebee-setup'"
alias downloadWindowsIso="$COMMON_UTILS_TOOLS_DIR/download-windows-iso"
alias createAutoStartService="'${SERVICE_MANAGER}' create-autostart-service"
alias removeAutoStartService="'${SERVICE_MANAGER}' remove-autostart-service"

mkdir -p "${THIRDPARTY_DIR}"

MISSING_EXECUTABLES="$(getMissingExecutables "$ALL_EXEC_DEPS")"
if [ "$MISSING_EXECUTABLES" != "" ]; then
    echo "> Update package info..."
    updatePkgInfo
    echo "> Find and install packages containing executables that we need..."
    getExecPkg "$ALL_EXEC_DEPS" # Find and install packages containing executables that we need
    MISSING_EXECUTABLES="$(getMissingExecutables "$ALL_EXEC_DEPS")"
    if [ "$MISSING_EXECUTABLES" != "" ]; then
        echo "> ERROR: Failed to install packages providing the following executables automatically: $MISSING_EXECUTABLES"
    fi
else
    echo "> [Skipped] Executable dependencies are already installed."
fi

MISSING_FILES="$(getMissingFiles "$ALL_FILE_DEPS")"
if [ "$MISSING_FILES" != "" ]; then
    echo "> Update package info..."
    updatePkgInfo
    echo "> Find and install packages containing files that we need..."
    getFilePkg "$ALL_FILE_DEPS" # Find and install packages containing specific files that we need
    MISSING_FILES="$(getMissingFiles "$ALL_FILE_DEPS")"
    if [ "$MISSING_FILES" != "" ]; then
        MISSING_FILES="$(echo "$MISSING_EXECUTABLES" | sed 's/\s\+/\n/g')" # replace spaces with new lines
        echo "> ERROR: Failed to install packages providing the following executables automatically:"
        echo "$MISSING_FILES"
    fi
else
    echo "> [Skipped] File dependencies are already installed."
fi

if [ "$MISSING_EXECUTABLES" != "" ] || [ "$MISSING_FILES" != "" ]; then
    exit 1
fi

REBOOT_REQUIRED=false
if ! runtimeKernelHasParams "${KERNEL_PARAMS_GENERAL[*]}"; then
    echo "> Adding general kernel params..."
    addKernelParams "${KERNEL_PARAMS_GENERAL[*]}"
    REBOOT_REQUIRED=true
else
    echo "> [Skipped] General kernel params already set on running kernel."
fi

#if [ "$HAS_INTEL_CPU" = true ]; then
    if ! runtimeKernelHasParams "${KERNEL_PARAMS_INTEL_CPU[*]}"; then
        echo "> Adding Intel CPU-specific kernel params..."
        addKernelParams "${KERNEL_PARAMS_INTEL_CPU[*]}"
        REBOOT_REQUIRED=true
    else
        echo "> [Skipped] Intel CPU-specific kernel params already set on running kernel."
    fi
#fi

#if [ "$HAS_AMD_CPU" = true ]; then
    if ! runtimeKernelHasParams "${KERNEL_PARAMS_AMD_CPU[*]}"; then
        echo "> Adding AMD CPU-specific kernel params..."
        addKernelParams "${KERNEL_PARAMS_AMD_CPU[*]}"
        REBOOT_REQUIRED=true
    else
        echo "> [Skipped] AMD CPU-specific kernel params already set on running kernel."
    fi
#fi

#if [ "$HAS_INTEL_GPU" = true ]; then
    if ! runtimeKernelHasParams "${KERNEL_PARAMS_INTEL_GPU[*]}"; then
        echo "> Adding Intel GPU-specific kernel params..."
        addKernelParams "${KERNEL_PARAMS_INTEL_GPU[*]}"
        REBOOT_REQUIRED=true
    else
        echo "> [Skipped] Intel GPU-specific kernel params already set on running kernel."
    fi
#fi

if [ "$HAS_NVIDIA_GPU" = true ]; then # TODO: Don't force Bumblebee and the proprietary Nvidia driver upon the user
    if ! runtimeKernelHasParams "${KERNEL_PARAMS_BUMBLEBEE_NVIDIA[*]}"; then
        echo "> Adding Nvidia GPU-specific kernel params..."
        addKernelParams "${KERNEL_PARAMS_BUMBLEBEE_NVIDIA[*]}"
        REBOOT_REQUIRED=true
    else
        echo "> [Skipped] Nvidia GPU-specific kernel params already set on running kernel."
    fi
fi

if [[ "$(docker images -q ovmf-vbios-patch 2> /dev/null)" == "" ]]; then
    echo "> Image 'ovmf-vbios-patch' has already been built."
    ovmfVbiosPatchSetup
else
    echo "> [Skipped] Image 'ovmf-vbios-patch' has already been built."
fi

if [ "$HAS_NVIDIA_GPU" = true ]; then
    nvidiaSetup
fi
if [ "$SUPPORTS_OPTIMUS" = true ]; then
    bumblebeeSetup
fi

if [ ! -f "${ACPI_TABLES_DIR}/fake-battery.aml" ]; then
    echo "> Building fake ACPI SSDT battery..."
    buildFakeBatterySsdt
else
    echo "> [Skipped] Fake ACPI SSDT battery has already been built."
fi

if [ ! -f ${THIRDPARTY_DIR}/VBiosFinder/vendor/bundle/ruby/*/bin/coderay ]; then
    echo "> Installing VBiosFinder..."
    vbiosFinderSetup
else
    echo "> [Skipped] VBiosFinder is already set up."
fi

if [ ! -f "${THIRDPARTY_DIR}/LookingGlass/looking-glass-host.exe" ] || [ ! -f "${THIRDPARTY_DIR}/LookingGlass/client/build/looking-glass-client" ]; then
    echo "> Installing Looking Glass..."
    lookingGlassSetup
else
    echo "> [Skipped] Looking Glass is already set up."
fi

CHECKSUM_FILE_PATH="$HELPER_ISO_FILES_DIR/.checksum"
PREVIOUS_HELPER_ISO_DIR_CHECKSUM="$(cat "$CHECKSUM_FILE_PATH" 2> /dev/null)"
NEW_HELPER_ISO_DIR_CHECKSUM="$(find "$HELPER_ISO_FILES_DIR" -type f ! -iname ".checksum" -exec md5sum {} + | LC_ALL=C sort | md5sum | cut -d' ' -f1)"
if [ "$PREVIOUS_HELPER_ISO_DIR_CHECKSUM" != "$NEW_HELPER_ISO_DIR_CHECKSUM" ]; then
    echo "> Generating helper ISO for auto unattended Windows install, config and driver installation..."
    rm -f "$CHECKSUM_FILE_PATH"
    generateHelperIso
    echo "$NEW_HELPER_ISO_DIR_CHECKSUM" > "$CHECKSUM_FILE_PATH"
else
    echo "> [Skipped] Helper ISO for auto unattended Windows install, config and driver installation already generated for the current files."
fi

if [ ! -f "$INSTALL_IMG" ]; then
    echo "Downloading Windows ISO from Microsoft now."
    downloadWindowsIso "$INSTALL_IMG"
else
    echo "> [Skipped] Windows ISO has already been downloaded."
fi

if [ "$1" = "auto" ]; then
    if [ "$REBOOT_REQUIRED" = true ]; then
        echo "> Creating a temporary service that will run on next reboot and create the Windows VM"
        createAutoStartService "${PROJECT_DIR}/mbpt.sh auto"
        echo "> Rebooting in 15 seconds... Press Ctrl+C to reboot now."
        #sleep 300
        #sudo shutdown -r 0
    else
        removeAutoStartService &> /dev/null
        echo "> No reboot required."
    fi
else
    if [ REBOOT_REQUIRED = true ]; then
        echo "> Please reboot to load the new kernel parameters!"
    else
        echo "> No reboot required."
    fi
fi
