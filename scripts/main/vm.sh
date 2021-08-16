#!/usr/bin/env bash
while [[ "$PROJECT_DIR" != */MobilePassThrough ]]; do PROJECT_DIR="$(readlink -f "$(dirname "${PROJECT_DIR:-0}")")"; done
source "$PROJECT_DIR/scripts/utils/common/libs/helpers"
loadConfig

#####################################################################################################
# This script can create a VM and install Windows in i,t if called like this: `./vm.sh install`
# or start the previously created Windows VM, if called like this: `./vm.sh`
#####################################################################################################

if [ "$1" = "install" ]; then
    VM_INSTALL=true
elif [ "$1" = "start" ]; then
    VM_INSTALL=false
elif [ "$1" = "remove" ]; then
    if [ $VM_START_MODE = "virt-install" ]; then
        sudo virsh destroy --domain "${VM_NAME}"
        sudo virsh undefine --domain "${VM_NAME}" --nvram
    #elif [ $VM_START_MODE = "qemu" ]; then
    #    
    fi
    if [[ ${DRIVE_IMG} == *.img ]]; then
        sudo rm -f "${DRIVE_IMG}"
    fi
    rm -f "${OVMF_VARS_VM}"
else
    echo "> Error: No valid vm.sh parameter was found!"
    exit 1
fi

GET_XML=false
DRY_RUN=false
if [ "$1" = "install" ] || [ "$1" = "start" ]; then
    if [ "$2" = "dry-run" ]; then
        DRY_RUN=true
    elif [ "$2" = "get-xml" ]; then
        GET_XML=true
        echo "> Enforcing VM start mode 'virt-install' to generate the XML..."
        VM_START_MODE="virt-install"
    fi
fi

#source "$COMMON_UTILS_LIBS_DIR/gpu-check"
alias driver="sudo '$COMMON_UTILS_TOOLS_DIR/driver-util'"
alias vgpu="sudo '$COMMON_UTILS_TOOLS_DIR/vgpu-util'"

VIRT_INSTALL_PARAMS=()
QEMU_PARAMS=()

if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-name" "${VM_NAME}")
elif [ "$VM_START_MODE" = "virt-install" ]; then
    VIRT_INSTALL_PARAMS+=("--name" "${VM_NAME}")
fi

if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-machine" "type=q35,accel=kvm") # for virt-install that's the default WHEN "--os-variant win10" is specified
fi

if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-global" "ICH9-LPC.disable_s3=1") # for virt-install this enabled by default
    QEMU_PARAMS+=("-global" "ICH9-LPC.disable_s4=1") # for virt-install this enabled by default
fi

if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-enable-kvm") # for virt-install this enabled by default
fi

if [ "$VM_START_MODE" = "qemu" ]; then
    # Refer to https://github.com/saveriomiroddi/qemu-pinning for information on how to set your cpu affinity properly
    QEMU_PARAMS+=("-cpu" "host,kvm=off,hv_vapic,hv_relaxed,hv_spinlocks=0x1fff,hv_time,hv_vendor_id=12alphanum")
elif [ "$VM_START_MODE" = "virt-install" ]; then
    VIRT_INSTALL_PARAMS+=("--cpu" "host")
    VIRT_INSTALL_PARAMS+=("--feature" "kvm.hidden.state=yes")
    VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./features/hyperv/vendor_id/@state=on" "--xml" "xpath.set=./features/hyperv/vendor_id/@value='12alphanum'") 
fi

if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-smp" "${CPU_CORE_COUNT}")
elif [ "$VM_START_MODE" = "virt-install" ]; then
    VIRT_INSTALL_PARAMS+=("--vcpu" "${CPU_CORE_COUNT}")
fi

if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-m" "${RAM_SIZE}")
elif [ "$VM_START_MODE" = "virt-install" ]; then
    RAM_SIZE_GB="$(numfmt --from=si "${RAM_SIZE}" --to-unit=1M)"
    VIRT_INSTALL_PARAMS+=("--memory" "${RAM_SIZE_GB}")
fi

if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-mem-prealloc") # for virt-install this enabled by default
fi

QEMU_PARAMS+=("-rtc" "clock=host,base=localtime")
QEMU_PARAMS+=("-nographic")
QEMU_PARAMS+=("-serial" "none")
QEMU_PARAMS+=("-parallel" "none")
QEMU_PARAMS+=("-boot" "menu=on")
QEMU_PARAMS+=("-boot" "once=d")
QEMU_PARAMS+=("-k" "en-us")

if [ $VM_INSTALL = true ]; then
    if [ "$VM_START_MODE" = "qemu" ]; then
        QEMU_PARAMS+=("-drive" "file=${INSTALL_IMG},index=1,media=cdrom")
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        VIRT_INSTALL_PARAMS+=("--cdrom" "${INSTALL_IMG}")
    fi
fi

if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-drive" "file=${HELPER_ISO},index=2,media=cdrom")
elif [ "$VM_START_MODE" = "virt-install" ]; then
    VIRT_INSTALL_PARAMS+=("--disk" "device=cdrom,path=${HELPER_ISO}")
fi

if [ "$VM_START_MODE" = "virt-install" ]; then
    if ! sudo virsh net-list | grep default | grep --quiet active; then
        sudo virsh net-start default
    fi
fi

#QEMU_PARAMS+=("-netdev" "type=tap,id=net0,ifname=tap0,script=${VM_FILES_DIR}/network-scripts/tap_ifup,downscript=${VM_FILES_DIR}/network-scripts/tap_ifdown,vhost=on")
#QEMU_PARAMS+=("-device" "virtio-net-pci,netdev=net0,addr=19.0,mac=${MAC_ADDRESS}")
QEMU_PARAMS+=("-device" "ich9-intel-hda")
QEMU_PARAMS+=("-device" "hda-output")
QEMU_PARAMS+=("-device" "pci-bridge,addr=12.0,chassis_nr=2,id=head.2")
# More parameters are added throughout the whole script

VIRT_INSTALL_PARAMS+=("--virt-type" "kvm")
VIRT_INSTALL_PARAMS+=("--os-variant" "win10")
VIRT_INSTALL_PARAMS+=("--arch=x86_64")
#VIRT_INSTALL_PARAMS+=("--unattended")

if [[ ${DRIVE_IMG} == /dev/* ]]; then
    echo "> Using a physical OS drive..."
    if [ "$VM_START_MODE" = "qemu" ]; then
        QEMU_PARAMS+=("-drive" "file=${DRIVE_IMG},if=virtio" "-snapshot")
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        VIRT_INSTALL_PARAMS+=("--disk" "${DRIVE_IMG}")
    fi
    #QEMU_PARAMS+=("-drive" "file=/dev/sda,if=virtio" "-drive" "file=/dev/sdb,if=virtio" "-drive" "file=/dev/sdc,if=virtio" "-drive" "file=/dev/sdd,if=virtio" "-snapshot")
elif [[ ${DRIVE_IMG} == *.img ]]; then
    echo "> Using a virtual OS drive..."
    if [ ! -f "${DRIVE_IMG}" ]; then
        echo "> Creating a virtual disk for the VM..."
        qemu-img create -f raw "${DRIVE_IMG}" "${VM_DISK_SIZE}"
        sudo chown "$(whoami):$(id -gn "$(whoami)")" "${DRIVE_IMG}"
    fi
    if [ "$VM_START_MODE" = "qemu" ]; then
        QEMU_PARAMS+=("-drive" "id=disk0,if=virtio,cache.direct=on,if=virtio,aio=native,format=raw,file=${DRIVE_IMG}")
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        VIRT_INSTALL_PARAMS+=("--disk" "${DRIVE_IMG}")
    fi
else
    echo "> Error: It appears that no proper OS drive (image) has been provided. Check your 'DRIVE_IMG' var: '${DRIVE_IMG}'"
    exit
fi

if [ ! -f "${OVMF_VARS_VM}" ] || [ $VM_INSTALL = true ]; then
    echo "> Creating fresh OVMF_VARS copy for this VM..."
    sudo rm -f "${OVMF_VARS_VM}"
    sudo cp "${OVMF_VARS}" "${OVMF_VARS_VM}"
    sudo chown "$(whoami):$(id -gn "$(whoami)")" "${OVMF_VARS_VM}"
fi

if sudo which optirun &> /dev/null && sudo optirun echo > /dev/null ; then
    OPTIRUN_PREFIX="optirun "
    DRI_PRIME_PREFIX=""
    echo "> Bumblebee works fine on this system. Using optirun when necessary..."
else
    OPTIRUN_PREFIX=""
    if [ "$SUPPORTS_DRI_PRIME" = true ]; then
        DRI_PRIME_PREFIX="DRI_PRIME=1 "
    else
        echo "> Warning: Bumblebee is not available or doesn't work properly. Continuing anyway..."
    fi
fi

echo "> Retrieving and parsing DGPU IDs..."
DGPU_IDS=$(export DRI_PRIME=1 && sudo ${OPTIRUN_PREFIX}lspci -n -s "${DGPU_PCI_ADDRESS}" | grep -oP "\w+:\w+" | tail -1)
DGPU_VENDOR_ID=$(echo "${DGPU_IDS}" | cut -d ":" -f1)
DGPU_DEVICE_ID=$(echo "${DGPU_IDS}" | cut -d ":" -f2)
DGPU_SS_IDS=$(export DRI_PRIME=1 && sudo ${OPTIRUN_PREFIX}lspci -vnn -d "${DGPU_IDS}" | grep "Subsystem:" | grep -oP "\w+:\w+")
DGPU_SS_VENDOR_ID=$(echo "${DGPU_SS_IDS}" | cut -d ":" -f1)
DGPU_SS_DEVICE_ID=$(echo "${DGPU_SS_IDS}" | cut -d ":" -f2)

if [ -z "$DGPU_IDS" ]; then
    echo "> Error: Failed to retrieve DGPU IDs!"
    echo "> DGPU_PCI_ADDRESS: ${DGPU_PCI_ADDRESS}"
    echo "> DGPU_IDS: $DGPU_IDS"
    echo "> DGPU_VENDOR_ID: $DGPU_VENDOR_ID"
    echo "> DGPU_DEVICE_ID: $DGPU_DEVICE_ID"
    echo "> DGPU_SS_IDS: $DGPU_SS_IDS"
    echo "> DGPU_SS_VENDOR_ID: $DGPU_SS_VENDOR_ID"
    echo "> DGPU_SS_DEVICE_ID: $DGPU_SS_DEVICE_ID"
    exit
fi

echo "> Loading vfio-pci kernel module..."
sudo modprobe vfio-pci

if [ "$USE_LOOKING_GLASS" = true ]; then
    echo "> Using Looking Glass..."
    echo "> Calculating required buffer size for ${LOOKING_GLASS_MAX_SCREEN_WIDTH}x${LOOKING_GLASS_MAX_SCREEN_HEIGHT} for Looking Glass..."
    UNROUNDED_BUFFER_SIZE=$((($LOOKING_GLASS_MAX_SCREEN_WIDTH * $LOOKING_GLASS_MAX_SCREEN_HEIGHT * 4 * 2)/1024/1024+10))
    BUFFER_SIZE=1
    while [[ $BUFFER_SIZE -le $UNROUNDED_BUFFER_SIZE ]]; do
        BUFFER_SIZE=$(($BUFFER_SIZE*2))
    done
    LOOKING_GLASS_BUFFER_SIZE="${BUFFER_SIZE}"
    echo "> Looking Glass buffer size set to: ${LOOKING_GLASS_BUFFER_SIZE}"
    if [ "$VM_START_MODE" = "qemu" ]; then
        QEMU_PARAMS+=("-device" "ivshmem-plain,memdev=ivshmem,bus=pcie.0")
        QEMU_PARAMS+=("-object" "memory-backend-file,id=ivshmem,share=on,mem-path=/dev/shm/looking-glass,size=${LOOKING_GLASS_BUFFER_SIZE}M")
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./devices/shmem/@name=looking-glass")
        VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./devices/shmem/model/@type=ivshmem-plain")
        VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./devices/shmem/size=${LOOKING_GLASS_BUFFER_SIZE}")
        VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./devices/shmem/size/@unit=M")
    fi
    #sudo bash -c "echo '#Type Path Mode UID GID Age Argument' > /etc/tmpfiles.d/10-looking-glass.conf"
    #sudo bash -c "echo 'f /dev/shm/looking-glass 0660 qemu kvm - ' >> /etc/tmpfiles.d/10-looking-glass.conf"
    #sudo systemd-tmpfiles --create --prefix=/dev/shm/looking-glass
else
    echo "> Not using Looking Glass..."
fi

if [ -z "$SMB_SHARE_FOLDER" ]; then
    echo "> Not using SMB share..."
else
    echo "> Using SMB share..."
    QEMU_PARAMS+=("-net" "user,smb=${SMB_SHARE_FOLDER}")
fi

if [ "$DGPU_PASSTHROUGH" = true ]; then
    echo "> Using dGPU passthrough..."
    echo "> Unbinding dGPU from ${HOST_DGPU_DRIVER} driver..."
    driver unbind "${DGPU_PCI_ADDRESS}"
    echo "> Binding dGPU to VFIO driver..."
    driver bind "${DGPU_PCI_ADDRESS}" "vfio-pci"
    #sudo bash -c "echo 'options vfio-pci ids=${DGPU_VENDOR_ID}:${DGPU_DEVICE_ID}' > '/etc/modprobe.d/vfio.conf'"
    # TODO: Make sure to also do the rebind for the other devices that are in the same iommu group (exclude stuff like PCI Bridge root ports that don't have vfio drivers)
    if [ "$VM_START_MODE" = "qemu" ]; then
        QEMU_PARAMS+=("-device" "ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=pci.1") # DGPU root port
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        VIRT_INSTALL_PARAMS+=("--controller" "type=pci,model=pcie-root-port,address.type=pci,address.bus=0x0,address.slot=0x1c,address.function=0x0,address.multifunction=on,index=1,alias.name=pci.1") # <controller type='pci' model='pcie-root-port'><model name='ioh3420'/></controller>
        VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./devices/controller/model/@name=ioh3420")
        VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./devices/controller/target/@chassis=1")
    fi

    if [ "$VM_START_MODE" = "qemu" ]; then
        if [ -z "$DGPU_ROM" ]; then
            echo "> Not using DGPU vBIOS override..."
            DGPU_ROM_PARAM=",rombar=0"
        else
            echo "> Using DGPU vBIOS override..."
            DGPU_ROM_PARAM=",romfile=${DGPU_ROM}"
        fi
        QEMU_PARAMS+=("-device" "vfio-pci,host=${DGPU_PCI_ADDRESS},bus=pci.1,addr=00.0,x-pci-sub-device-id=0x${DGPU_SS_DEVICE_ID},x-pci-sub-vendor-id=0x${DGPU_SS_VENDOR_ID},multifunction=on${DGPU_ROM_PARAM}")
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        if [ -z "$DGPU_ROM" ]; then
            echo "> Not using DGPU vBIOS override..."
            DGPU_ROM_PARAM=",rom.bar=on"
        fi
        VIRT_INSTALL_PARAMS+=("--hostdev" "${DGPU_PCI_ADDRESS},address.bus=1,address.type=pci,address.multifunction=on${DGPU_ROM_PARAM}")
        if [ ! -z "$DGPU_ROM" ]; then
            echo "> Using DGPU vBIOS override..."
            VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./devices/hostdev/rom/@file=${DGPU_ROM}")
            QEMU_PARAMS+=("-set" "device.hostdev0.x-pci-sub-device-id=$((16#${DGPU_SS_DEVICE_ID}))")
            QEMU_PARAMS+=("-set" "device.hostdev0.x-pci-sub-vendor-id=$((16#${DGPU_SS_VENDOR_ID}))")
        fi
    fi
else
    echo "> Not using dGPU passthrough..."
fi

if [ "$SHARE_IGPU" = true ]; then
    echo "> Using mediated iGPU passthrough..."
    vgpu init # load required kernel modules

    # FIXME: There is a bug in Linux that prevents creating new vGPUs without rebooting after removing one. 
    #        So for now we can't create a new vGPU every time the VM starts.
    #vgpu remove "${IGPU_PCI_ADDRESS}" &> /dev/null # Ensure there are no vGPUs before creating a new one
    VGPU_UUID="$(vgpu get "${IGPU_PCI_ADDRESS}" | head -1)"
    if [ "$VGPU_UUID" == "" ]; then
        echo "> Creating a vGPU for mediated iGPU passthrough..."
        VGPU_UUID="$(vgpu create "${IGPU_PCI_ADDRESS}")"
        if [ "$?" = "1" ]; then
            echo "> Failed creating a vGPU. Try again. If you still get this error, you have to reboot. This seems to be a bug in Linux."
            exit 1
        fi
    fi
    
    # TODO: same as for iGPU
    if [ "$VM_START_MODE" = "qemu" ]; then

        if [ "$USE_DMA_BUF" = true ]; then
            echo "> Using dma-buf..."
            QEMU_PARAMS+=("-display" "egl-headless") #"-display" "gtk,gl=on" # DMA BUF Display
            DMA_BUF_PARAM=",display=on,x-igd-opregion=on"
        else
            echo "> Not using dma-buf..."
            DMA_BUF_PARAM=""
        fi

        if [ -z "$IGPU_ROM" ]; then
            echo "> Not using IGPU vBIOS override..."
            IGPU_ROM_PARAM=",rom.bar=on"
        else
            echo "> Using IGPU vBIOS override..."
            IGPU_ROM_PARAM=",romfile=${IGPU_ROM}"
        fi

        QEMU_PARAMS+=("-device" "vfio-pci,bus=pcie.0,addr=05.0,sysfsdev=/sys/bus/mdev/devices/${VGPU_UUID}${IGPU_ROM_PARAM}${DMA_BUF_PARAM}") # GVT-G
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        if [ "$USE_DMA_BUF" = true ]; then
            echo "> Using dma-buf..."
            #QEMU_PARAMS+=("-display" "egl-headless") #"-display" "gtk,gl=on" # DMA BUF Display
            QEMU_PARAMS+=("-set" "device.hostdev1.x-igd-opregion=on")
            GVTG_DISPLAY_STATE="on"
        else
            echo "> Not using dma-buf..."
            GVTG_DISPLAY_STATE="off"
        fi

        if [ -z "$IGPU_ROM" ]; then
            echo "> Not using IGPU vBIOS override..."
            IGPU_ROM_PARAM=",rom.bar=on"
        fi
        VIRT_INSTALL_PARAMS+=("--hostdev" "type=mdev,alias.name=hostdev1,address.domain=0000,address.bus=0,address.slot=2,address.function=0,address.type=pci,address.multifunction=on${IGPU_ROM_PARAM}")
        VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./devices/hostdev[2]/@model=vfio-pci")
        VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./devices/hostdev[2]/source/address/@uuid=${VGPU_UUID}")
        
        if [ ! -z "$IGPU_ROM" ]; then
            echo "> Using IGPU vBIOS override..."
            VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./devices/hostdev[2]/rom/@file=${IGPU_ROM}")
        fi
    fi
else
    echo "> Not using mediated iGPU passthrough..."
fi

if [ "$USE_SPICE" = true ]; then
    echo "> Using spice on port ${SPICE_PORT}..."
    #QEMU_PARAMS+=("-spice" "port=${SPICE_PORT},addr=127.0.0.1,disable-ticketing") #Spice
    if [ "$VM_START_MODE" = "qemu" ]; then
        QEMU_PARAMS+=("-spice" "port=${SPICE_PORT},addr=127.0.0.1,disable-ticketing") #Spice
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        VIRT_INSTALL_PARAMS+=("--channel" "spicevmc,target.address=127.0.0.1:${SPICE_PORT}")
        #VIRT_INSTALL_PARAMS+=("--graphics" "spice,port=${SPICE_PORT}")
    fi
else
    echo "> Not using Spice..."
fi

if [ "$USE_QXL" = true ]; then
    echo "> Using QXL..."
    if [ "$VM_START_MODE" = "qemu" ]; then
        QEMU_PARAMS+=("-device" "qxl,bus=pcie.0,addr=1c.4,id=video.2" "-vga" "qxl")
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        VIRT_INSTALL_PARAMS+=("--video" "qxl")
    fi
else
    echo "> Not using QXL..."
fi
#-video qxl --channel spicevmc
if [ "$USE_FAKE_BATTERY" = true ]; then
    echo "> Using fake battery..."
    if [ ! -f "${VM_FILES_DIR}/fake-battery.aml" ]; then
        mv "${ACPI_TABLES_DIR}/fake-battery.aml" "${VM_FILES_DIR}/fake-battery.aml"
    fi
    FAKE_BATTERY_SSDT_TABLE="$(readlink -f "${VM_FILES_DIR}/fake-battery.aml")"
    if [ "$VM_START_MODE" = "qemu" ]; then
        QEMU_PARAMS+=("-acpitable" "file=${FAKE_BATTERY_SSDT_TABLE}")
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./os/acpi/table/@type=slic" "--xml" "xpath.set=./os/acpi/table=${VM_FILES_DIR}/fake-battery.aml") 
    fi
else
    echo "> Not using fake battery..."
fi

if [ "$PATCH_OVMF_WITH_VROM" = true ]; then
    PATCHED_OVMF_FILES_DIR="${VM_FILES_DIR}/patched-ovmf-files"
    if [ "$DGPU_ROM" != "" ]; then
        echo "> Using patched OVMF..."
        DGPU_ROM_NAME="$(basename "${DGPU_ROM}")"
        if [ ! -f "${PATCHED_OVMF_FILES_DIR}/${DGPU_ROM_NAME}_OVMF_CODE.fd" ] || [ ! -f "${PATCHED_OVMF_FILES_DIR}/${DGPU_ROM_NAME}_OVMF_VARS.fd" ]; then
            DGPU_ROM_DIR="$(dirname "${DGPU_ROM}")"
            mkdir -p "${PATCHED_OVMF_FILES_DIR}/tmp-build"
            sudo chown "$(whoami):$(id -gn "$(whoami)")" "${PATCHED_OVMF_FILES_DIR}"
            echo "> Patching OVMF with your vBIOS ROM. This may take a few minutes!"
            sleep 5 # Ensure the user can read this first
            sudo service docker start
            sudo docker run --rm -ti -v "${PATCHED_OVMF_FILES_DIR}/tmp-build:/build:z" -v "${DGPU_ROM_DIR}:/roms:z" -e "VROM=${DGPU_ROM_NAME}" ovmf-vbios-patch
            sudo chown "$(whoami):$(id -gn "$(whoami)")" -R "${PATCHED_OVMF_FILES_DIR}/tmp-build"
            sudo mv "${PATCHED_OVMF_FILES_DIR}/tmp-build/OVMF_CODE.fd" "${PATCHED_OVMF_FILES_DIR}/${DGPU_ROM_NAME}_OVMF_CODE.fd"
            sudo mv "${PATCHED_OVMF_FILES_DIR}/tmp-build/OVMF_VARS.fd" "${PATCHED_OVMF_FILES_DIR}/${DGPU_ROM_NAME}_OVMF_VARS.fd"
            sudo rm -rf "${PATCHED_OVMF_FILES_DIR}/tmp-build"
        fi
        OVMF_CODE="${PATCHED_OVMF_FILES_DIR}/${DGPU_ROM_NAME}_OVMF_CODE.fd"
        if [ $VM_INSTALL = true ]; then
            echo "> Creating fresh copy of patched OVMF VARS..."
            rm -f "${OVMF_VARS_VM}"
            sudo cp "${PATCHED_OVMF_FILES_DIR}/${DGPU_ROM_NAME}_OVMF_VARS.fd" "${OVMF_VARS_VM}"
        fi
        #OVMF_VARS_VM="${PATCHED_OVMF_FILES_DIR}/${DGPU_ROM_NAME}_OVMF_VARS.fd"
    else
        echo "> Not using patched OVMF..."
    fi
else
    echo "> Not using patched OVMF..."
fi

if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-drive" "if=pflash,format=raw,readonly=on,file=${OVMF_CODE}")
    QEMU_PARAMS+=("-drive" "if=pflash,format=raw,file=${OVMF_VARS_VM}")
elif [ "$VM_START_MODE" = "virt-install" ]; then
    VIRT_INSTALL_PARAMS+=("--boot" "loader=${OVMF_CODE},loader.readonly=yes,loader.type=pflash,nvram.template=${OVMF_VARS_VM},loader_secure=no")
fi

QEMU_PARAMS+=("-usb")
if [ -z "$USB_DEVICES" ]; then
    echo "> Not using USB passthrough..."
    USB_DEVICE_PARAMS=""
else
    echo "> Using USB passthrough..."
    IFS=';' read -a USB_DEVICES_ARRAY <<< "${USB_DEVICES}"
    for USB_DEVICE in "${USB_DEVICES_ARRAY[@]}"; do
        QEMU_PARAMS+=("-device" "usb-host,${USB_DEVICE}")
        echo "> Passing USB device '${USB_DEVICE}' through..."
    done
fi

if [ "$VIRTUAL_INPUT_TYPE" = "virtio" ]; then
    echo "> Using virtual input method 'virtio' for keyboard/mouse input..."
    QEMU_PARAMS+=("-device" "virtio-keyboard-pci,bus=head.2,addr=03.0,display=video.2")
    QEMU_PARAMS+=("-device" "virtio-mouse-pci,bus=head.2,addr=04.0,display=video.2")
elif [ "$VIRTUAL_INPUT_TYPE" = "usb-tablet" ]; then
    echo "> Using virtual input method 'usb-tablet' for keyboard/mouse input..."
    QEMU_PARAMS+=("-device" "usb-tablet")
else
    echo "> Not using virtual input method for keyboard/mouse input..."
fi

#give_qemu_access() {
#    local skip_root=true
#    local -a paths
#    IFS=/ read -r -a paths <<<"$1"
#    local i
#    for (( i = 1; i < ${#paths[@]}; i++ )); do
#        paths[i]="${paths[i-1]}/${paths[i]}"
#    done
#    paths[0]=/
#    for current_path in "${paths[@]}" ; do
#        if [ "$skip_root" = true ] && [ "${current_path}" = "/" ]; then
#            continue
#        fi
#        echo "> Granting qemu access to: '${current_path}'"
#        sudo setfacl --modify user:qemu:rx "${current_path}"
#        sudo chmod +x "${current_path}"
#    done
#    #sudo chmod 777 "$1"
#}

#give_qemu_access "${INSTALL_IMG}"

#sudo bash -c "echo 'user = root' >> /etc/libvirt/qemu.conf"
#sudo systemctl restart libvirtd

if [ $VM_INSTALL = true ]; then
    echo "> Deleting VM if it already exists..."
    sudo virsh destroy --domain "${VM_NAME}" &> /dev/null
    sudo virsh undefine --domain "${VM_NAME}" --nvram &> /dev/null
fi

if [ "$DRY_RUN" = false ]; then
    echo "> Repeatedly sending keystrokes to the new VM for 30 seconds to ensure the Windows ISO boots..."
fi
if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-monitor" "unix:/tmp/${VM_NAME}-monitor,server,nowait")

    if [ "$DRY_RUN" = false ]; then
        bash -c "for i in {1..30}; do echo 'sendkey home' | sudo socat - 'UNIX-CONNECT:/tmp/${VM_NAME}-monitor'; sleep 1; done" &> /dev/null &

        echo "> Starting the spice client @localhost:${SPICE_PORT}..."
        bash -c "sleep 2; spicy -h localhost -p ${SPICE_PORT}" &

        echo "> Starting the Virtual Machine using qemu..."
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "> Generating qemu-system-x86_64 command (dry-run)..."
        echo ""
        printf "sudo qemu-system-x86_64"
        for param in "${QEMU_PARAMS[@]}"; do
            if [[ "${param}" == -* ]]; then 
                printf " \\\\\n  ${param}"
            elif [[ $param = *" "* ]]; then
                printf " \"${param}\""
            else
                printf " ${param}"
            fi
        done
        echo ""
        echo ""
    else
        sudo qemu-system-x86_64 "${QEMU_PARAMS[@]}"
    fi
elif [ "$VM_START_MODE" = "virt-install" ]; then
    if [ "$DRY_RUN" = false ]; then
        bash -c "for i in {1..30}; do sudo virsh send-key ${VM_NAME} KEY_HOME; sleep 1; done" &> /dev/null &

        echo "> Starting the Virtual Machine using virt-install..."
    fi
    #VIRT_INSTALL_PARAMS+=("--debug")
    for param in "${QEMU_PARAMS[@]}"; do
        VIRT_INSTALL_PARAMS+=("--qemu-commandline='${param}'")
    done

    #if [ $VM_INSTALL = true ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "> Generating virt-install command (dry-run)..."
            echo ""
            printf "sudo virt-install"
            for param in "${VIRT_INSTALL_PARAMS[@]}"; do
                if [[ "${param}" == -* ]]; then 
                    printf " \\\\\n  ${param}"
                elif [[ $param = *" "* ]]; then
                    printf " \"${param}\""
                else
                    printf " ${param}"
                fi
            done
            echo ""
            echo ""
        elif [ "$GET_XML" = true ]; then
            VIRT_INSTALL_PARAMS+=("--print-xml")
            sudo virt-install "${VIRT_INSTALL_PARAMS[@]}"
        else
            sudo virt-install "${VIRT_INSTALL_PARAMS[@]}"
        fi
    #else
    #    if [ "$DRY_RUN" = true ]; then
    #        echo ""
    #        printf "sudo virt-install"
    #    else
    #        virsh start "${VM_NAME}"
    #    fi
    #fi
fi

# This gets executed when the vm exits

if [ "$DGPU_PASSTHROUGH" = true ]; then

    echo "> Unbinding dGPU from vfio driver..."
    driver unbind "${DGPU_PCI_ADDRESS}"
    if [ "$HOST_DGPU_DRIVER" = "nvidia" ] || [ "$HOST_DGPU_DRIVER" = "nuveau" ]; then
        echo "> Turn the dGPU off using bumblebee..."
        sudo bash -c "echo 'OFF' >> /proc/acpi/bbswitch"
    fi
    echo "> Binding dGPU back to ${HOST_DGPU_DRIVER} driver..."
    driver bind "${DGPU_PCI_ADDRESS}" "${HOST_DGPU_DRIVER}"

fi

if [ "$SHARE_IGPU" = true ]; then
    echo "> Keeping Intel vGPU for next VM start..."

    # FIXME: There is a bug in Linux that prevents creating new vGPUs without rebooting after removing one. 
    #        So for now we can't create a new vGPU every time the VM starts.
    #echo "> Remove Intel vGPU..."
    #vgpu remove "${IGPU_PCI_ADDRESS}" "${VGPU_UUID}"

fi