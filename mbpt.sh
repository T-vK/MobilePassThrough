#!/usr/bin/env bash
while [[ "$PROJECT_DIR" != */MobilePassThrough ]]; do PROJECT_DIR="$(readlink -f "$(dirname "${PROJECT_DIR:-0}")")"; done
source "$PROJECT_DIR/scripts/utils/common/libs/helpers"

#####################################################################################################
# This is the only script that you should really care about as a user of MobilePassThrough.
# Usage: `./mbpt.sh --help`
#####################################################################################################

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
    echo '    auto         Automatically run check, setup and install'
    echo '    configure    Interactively guides you through the creation of your config file'
    echo '    check        Check if and to what degree your notebook is capable of running a GPU passthrough setup'
    echo '    setup        Install required dependencies and set required kernel parameters'
    echo '    install      Create and install the VM'
    echo '    start        Start the VM'
    echo '    live         Create / Flash a Live ISO image of this project'
    # TODO: Split start/install in pre-start, start/install, post-start ()
    # TODO implement:
    #echo '    get-xml      Print out the VM configuration as XML'
    #echo '    get-qemu     Print out the VM configuration as a qemu-system-x86_64 command'
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
    echo '    # Create the VM and install Windows in it (Will overwrite an older instance if one exists!)'
    echo '    mbpt.sh install'
    echo ''
    echo '    # Start the VM'
    echo '    mbpt.sh start'
    echo ''
    echo '    # Create a Live ISO'
    echo '    mbpt.sh live buid'
    echo ''
    echo '    # Flash a Live ISO to the USB drive /dev/sdx'
    echo '    mbpt.sh live flash /dev/sdx'
    echo ''
    echo '    # Print the qemu command that would have been used to start the VM'
    echo '    mbpt.sh start dry-run'
    echo ''
    echo '    # Print the qemu command that would have been used to install the VM'
    echo '    mbpt.sh install dry-run'
    echo ''
    echo '    # Print the libvirt XML that would have been used to start the VM'
    echo '    mbpt.sh start get-xml'
    echo ''
    echo '    # Print the libvirt XML that would have been used to install the VM'
    echo '    mbpt.sh install get-xml'
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
    sudo "${MAIN_SCRIPTS_DIR}/setup.sh"
elif [ "$COMMAND" = "check" ]; then
    sudo "${MAIN_SCRIPTS_DIR}/compatibility-check.sh"
elif [ "$COMMAND" = "configure" ]; then
    "${MAIN_SCRIPTS_DIR}/generate-vm-config.sh"
elif [ "$COMMAND" = "helper-iso" ]; then
    "${MAIN_SCRIPTS_DIR}/generate-helper-iso.sh"
elif [ "$COMMAND" = "install" ] || [ "$COMMAND" = "create" ]; then
    sudo "${MAIN_SCRIPTS_DIR}/vm.sh" install $2
elif [ "$COMMAND" = "remove" ]; then
    sudo "${MAIN_SCRIPTS_DIR}/vm.sh" remove
elif [ "$COMMAND" = "start" ]; then
    sudo "${MAIN_SCRIPTS_DIR}/vm.sh" start $2
elif [ "$COMMAND" = "live" ]; then
    sudo "${MAIN_SCRIPTS_DIR}/generate-live-iso.sh" "$2" "$3"
elif [ "$COMMAND" = "auto" ]; then
    #sudo "${MAIN_SCRIPTS_DIR}/compatibility-check.sh" || echo "Exiting..." && exit 1
    sudo "${MAIN_SCRIPTS_DIR}/setup.sh" auto
    if [ $? -eq 0 ]; then
        sudo "${MAIN_SCRIPTS_DIR}/iommu-check.sh"
        if [ $? -eq 0 ]; then
            sudo "${MAIN_SCRIPTS_DIR}/vm.sh" install
        else
            echo "Exiting..."
            exit 1
        fi
    else
        echo "Exiting..."
        exit 1
    fi
elif [ "$COMMAND" = "vbios" ]; then
    if [ "$2" == "extract" ]; then
        mkdir -p "$4/"
        cd "${THIRDPARTY_DIR}/VBiosFinder"
        ./vbiosfinder extract "$(readlink -f "$3")"
        mv "${THIRDPARTY_DIR}/VBiosFinder/output/*" "$4/"
    elif [ "$2" == "dump" ]; then
        sudo "${COMMON_UTILS_SETUP_DIR}/extract-vbios" "$3" "$4"
    fi
fi
