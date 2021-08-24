#!/usr/bin/env bash
while [[ "$PROJECT_DIR" != */MobilePassThrough ]]; do PROJECT_DIR="$(readlink -f "$(dirname "${PROJECT_DIR:-0}")")"; done
source "$PROJECT_DIR/scripts/utils/common/libs/helpers"

#####################################################################################################
# This interactive script creates a custom config file (user.conf) to your liking.
#####################################################################################################

#source "$COMMON_UTILS_LIBS_DIR/gpu-check"

interactiveCfg() {
    DEFAULT_VALUE=$(grep -Po "(?<=^$2=).*" "${PROJECT_DIR}/default.conf" | cut -d "#" -f1 | sed 's/^\s*"\(.*\)"\s*$/\1/' | xargs)
    COMMENT=$(grep -Po "(?<=^$2=).*" "${PROJECT_DIR}/default.conf" | cut -d "#" -f2-)
    #echo "DEFAULT_VALUE: $DEFAULT_VALUE"
    declare -A "$2=$DEFAULT_VALUE"
    TMP_VAR_NAME="TMP_$2";
    #echo "TMP_VAR_NAME: ${TMP_VAR_NAME}"
    read -p "$1 [$DEFAULT_VALUE]: " "$TMP_VAR_NAME";
    declare -A "USER_INPUT=${!TMP_VAR_NAME}"
    #echo "VM_FILES_DIR: ${VM_FILES_DIR}"
    #echo "USER_INPUT: ${!TMP_VAR_NAME}"
    if [ "${USER_INPUT}" != "" ]; then
        FINAL_VALUE="${USER_INPUT}"
    else
        FINAL_VALUE="${DEFAULT_VALUE}"
    fi
    declare -g "$2=${FINAL_VALUE}"
    #echo "FINAL_VALUE: $FINAL_VALUE"
    if [ "${USER_CONFIG_FILE}" != "" ]; then
        crudini --set "${USER_CONFIG_FILE}" "" "$2" "\"${FINAL_VALUE}\" #${COMMENT}"
        echo "> Set $2 to '${FINAL_VALUE}'"
    fi
    # TODO: change modified value on config file USER_CONFIG_FILE
}

echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!IF IN DOUBT WITH ANY OF THE FOLLOWING, JUST PRESS ENTER TO USE THE RECOMMENDED/DEFAULT VALUE!!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
interactiveCfg "Where should the VM files be saved?" VM_FILES_DIR
echo "> Directory set to '${VM_FILES_DIR}'"

#read -p "Where should the config to be generated be saved? (Will overwrite if necessary) [${VM_FILES_DIR}/user.conf]: " USER_CONFIG_FILE
#if [ "$USER_CONFIG_FILE" == "" ]; then
#    USER_CONFIG_FILE="${VM_FILES_DIR}/user.conf"
#fi
USER_CONFIG_FILE="${PROJECT_DIR}/user.conf"

eval "USER_CONFIG_FILE=${USER_CONFIG_FILE}"
#echo "USER_CONFIG_FILE=$USER_CONFIG_FILE"
mkdir -p "$(dirname "${USER_CONFIG_FILE}")"
cp "${PROJECT_DIR}/default.conf" "${USER_CONFIG_FILE}"
echo "> Config will be created at ${USER_CONFIG_FILE}'"

interactiveCfg "What should the name of the VM be?" VM_NAME
interactiveCfg "Where to save the VM drive image? (At least 40G is highly recommended; Can't be changed wihtout a reinstall)" DRIVE_IMG
interactiveCfg "How big should the VM drive image be?" VM_DISK_SIZE
interactiveCfg "How many CPU cores should the VM get? (e.g. 8 or auto; auto=AVAILABLE_CORES-1G)" CPU_CORE_COUNT
interactiveCfg "How much RAM should the VM get? (e.g. 16G or auto; auto=FREE_RAM-1G)" RAM_SIZE
interactiveCfg "Path to your Windows installation iso. (If it doesn't exist it will be downloaded to that location automatically.)" INSTALL_IMG
interactiveCfg "Path to a dGPU ROM. (Optional)" DGPU_ROM
interactiveCfg "Path to a iGPU ROM. (Optional)" IGPU_ROM
interactiveCfg "Path to a folder to share with the VM via SMB. (Optional)" SMB_SHARE_FOLDER
interactiveCfg "Location of OVMF_VARS.fd." OVMF_VARS
interactiveCfg "Where to create Creating a copy of OVMF_VARS.fd (containing the executable firmware code and but the non-volatile variable store) for the VM?" OVMF_VARS_VM
interactiveCfg "Location of OVMF_CODE.fd." OVMF_CODE
interactiveCfg "Location of helper iso or where to create it." HELPER_ISO
interactiveCfg "Pass the dGPU through to the VM. (true, false or auto to enable if more than one GPU is in this system)" DGPU_PASSTHROUGH
interactiveCfg "Share the iGPU with the VM to allow using Optimus within the VM to save battery life (true, false or auto to share it only if available)" SHARE_IGPU
interactiveCfg "dGPU driver used by the Linux host (E.g. nvidia, nouveau, amdgpu, radeon or auto to detect it automatically)" HOST_DGPU_DRIVER
interactiveCfg "The PCI address of your dGPU as obtained by 'lspci' or 'optimus lspci'. (E.g. 01:00.0 or auto to detect it automatically)" DGPU_PCI_ADDRESS
interactiveCfg "The PCI address of your iGPU as obtained by 'lspci'. (E.g. 00:02.0 or auto to detect it automatically)" IGPU_PCI_ADDRESS
interactiveCfg "Virtual input device mode for keyboard and mouse. (if usb-tablet doesn't work properly, you may want to switch to virtio)" VIRTUAL_INPUT_TYPE
interactiveCfg "MAC address to use (e.g. 11:22:33:44:55:66 or auto to generate it automatically)" MAC_ADDRESS
interactiveCfg "Network mode to use? Only supports bridge at the moment." NETWORK_MODE
interactiveCfg "Max screen width with Looking Glass." LOOKING_GLASS_MAX_SCREEN_WIDTH
interactiveCfg "Max screen height with Looking Glass." LOOKING_GLASS_MAX_SCREEN_HEIGHT
interactiveCfg "Version of Looking Glass to use (B4 is highly recommended)" LOOKING_GLASS_VERSION
interactiveCfg "Enable spice. (Leave this on unless you know what you're doing!)" USE_SPICE
interactiveCfg "Port to use for spice." SPICE_PORT
interactiveCfg "Display mode to use (e.g. 1 or 2 ... see scripts/utils/common/plugins)" DISPLAY_MODE
interactiveCfg "Provide the VM with a fake battery (Highly recommended to avoid Error 43)" USE_FAKE_BATTERY
interactiveCfg "Patch OVMF with your dGPU ROM if you supply one. (Highly recommended to avoid Error 43)" PATCH_OVMF_WITH_VROM
interactiveCfg "Tool to use to start/install the VM. (qemu or virt-install)" VM_START_MODE
interactiveCfg "List of USB devices to pass through. (Semicolon separated, e.g. vendorid=0x0b12,productid=0x9348;vendorid=0x0b95,productid=0x1790)" USB_DEVICES
# TODO: Make selecting USB devices easier