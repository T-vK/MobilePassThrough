#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
PROJECT_DIR="${SCRIPT_DIR}"
UTILS_DIR="${PROJECT_DIR}/utils"
DISTRO=$("${UTILS_DIR}/distro-info")
DISTRO_UTILS_DIR="${UTILS_DIR}/${DISTRO}"
USER_SCRIPTS_DIR="${PROJECT_DIR}/scripts"

COMMAND="$1"

function printHelp() {
    echo 'mbpt.sh COMMAND [ARG...]'
    echo 'mbpt.sh [ -h | --help ]'
    echo ''
    echo 'mbpt.sh is a wrapper script for a collection of tools that help with GPU passthrough on mobile devices like notebooks and convertibles.'
    echo ''
    echo 'Options:'
    echo '  -h, --help       Print usage'
    echo ''
    echo 'Commands:'
    echo '    setup        Install required dependencies and set required kernel parameters'
    echo '    check        Check if and to what degree your notebook is capable of running a GPU passthrough setup'
    echo '    configure    Interactively guides you through the creation of your config file'
    echo '    iso          Generate a helper iso file that contains required drivers and a helper-script for your Windows VM'
    echo '    start        Start your VM'
    echo '    vbios        Dump the vBIOS ROM from the running system or extract it from a BIOS update'
    echo ''
    echo 'Examples:'
    echo '    # Install required dependencies and set required kernel parameters'
    echo '    mbpt.sh setup'
    echo ''
    echo '    # Check if and to what degree your notebook is capable of running a GPU passthrough setup'
    echo '    mbpt.sh check'
    echo ''
    echo '    # Interactively guides you through the creation of your config file'
    echo '    mbpt.sh configure'
    echo ''
    echo '    # Generate a helper iso file that contains required drivers and a helper-script for your Windows VM'
    echo '    mbpt.sh iso'
    echo ''
    echo '    # Start your VM'
    echo '    mbpt.sh start'
    echo ''
    echo '    # Dump the vBIOS ROM of the GPU with the PCI address 01:00.0 to ./my-vbios.rom (This will most likely fail)'
    echo '    mbpt.sh vbios dump 01:00.0 ./my-vbios.rom'
    echo ''
    echo '    # Extract all the vBIOS ROMs of a given BIOS update to the directory ./my-roms'
    echo '    mbpt.sh vbios extract /path/to/my-bios-update.exe ./my-roms'
}


if [ "$COMMAND" = "help" ] || [ "$COMMAND" = "--help" ] || [ "$COMMAND" = "-h" ] || [ "$COMMAND" = "" ]; then
    printHelp
elif [ "$COMMAND" = "setup" ]; then
    sudo "${USER_SCRIPTS_DIR}/setup.sh"
elif [ "$COMMAND" = "check" ]; then
    sudo "${USER_SCRIPTS_DIR}/compatibility-check.sh"
elif [ "$COMMAND" = "configure" ]; then
    "${USER_SCRIPTS_DIR}/generate-vm-config.sh"
elif [ "$COMMAND" = "iso" ]; then
    "${USER_SCRIPTS_DIR}/generate-helper-iso.sh"
elif [ "$COMMAND" = "start" ]; then
    sudo "${USER_SCRIPTS_DIR}/start-vm.sh"
elif [ "$COMMAND" = "vbios" ]; then
    if [ "$2" == "extract" ] ; then
        mkdir -p "$4/"
        cd "${PROJECT_DIR}/thirdparty/VBiosFinder"
        ./vbiosfinder extract "$(readlink -f "$3")"
        mv "${PROJECT_DIR}/thirdparty/VBiosFinder/output/*" "$4/"
    elif [ "$2" == "dump" ] ; then
        sudo "${UTILS_DIR}/extract-vbios" "$3" "$4"
    fi
fi 