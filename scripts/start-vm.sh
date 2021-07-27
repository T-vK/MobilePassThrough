#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
PROJECT_DIR="$(readlink -f "${SCRIPT_DIR}/..")"
UTILS_DIR="${PROJECT_DIR}/utils"
DISTRO=$("${UTILS_DIR}/distro-info")
DISTRO_UTILS_DIR="${UTILS_DIR}/${DISTRO}"

VM_START_MODE="virt-install" # qemu or virt-install

# If user.conf doesn't exist use the default.conf
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

#source "$UTILS_DIR/gpu-check"
shopt -s expand_aliases
alias driver="sudo $UTILS_DIR/driver-util"
alias vgpu="sudo $UTILS_DIR/vgpu-util"

VIRT_INSTALL_PARAMS=()
QEMU_PARAMS=()

if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-name" "${VM_NAME}")
elif [ "$VM_START_MODE" = "virt-install" ]; then
    VIRT_INSTALL_PARAMS+=("--name" "WindowsVM")
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
QEMU_PARAMS+=("-boot" "order=d")
QEMU_PARAMS+=("-k" "en-us")

if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-drive" "file=${INSTALL_IMG},index=1,media=cdrom")
elif [ "$VM_START_MODE" = "virt-install" ]; then
    VIRT_INSTALL_PARAMS+=("--cdrom" "${INSTALL_IMG}")
fi

if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-drive" "file=${VIRTIO_WIN_IMG},index=2,media=cdrom")
elif [ "$VM_START_MODE" = "virt-install" ]; then
    VIRT_INSTALL_PARAMS+=("--cdrom" "${VIRTIO_WIN_IMG}")
fi

if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-drive" "file=${HELPER_ISO},index=3,media=cdrom")
elif [ "$VM_START_MODE" = "virt-install" ]; then
    VIRT_INSTALL_PARAMS+=("--cdrom" "${HELPER_ISO}")
fi

if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-drive" "file=${INSTALL_IMG},index=1,media=cdrom")
elif [ "$VM_START_MODE" = "virt-install" ]; then
    VIRT_INSTALL_PARAMS+=("--cdrom" "${INSTALL_IMG}")
fi

if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-fda" "${VIRTIO_WIN_VFD}")
elif [ "$VM_START_MODE" = "virt-install" ]; then
    VIRT_INSTALL_PARAMS+=("--disk" "device=floppy,path=${VIRTIO_WIN_VFD}")
fi

if [ "$VM_START_MODE" = "qemu" ]; then
    QEMU_PARAMS+=("-fdb" "${AUTOUNATTEND_WIN_VFD}")
elif [ "$VM_START_MODE" = "virt-install" ]; then
    VIRT_INSTALL_PARAMS+=("--disk" "device=floppy,path=${AUTOUNATTEND_WIN_VFD}")
fi
#TODO: Uncomment!
#QEMU_PARAMS+=("-netdev" "type=tap,id=net0,ifname=tap0,script=${VM_FILES_DIR}/network-scripts/tap_ifup,downscript=${VM_FILES_DIR}/network-scripts/tap_ifdown,vhost=on")
#QEMU_PARAMS+=("-device" "virtio-net-pci,netdev=net0,addr=19.0,mac=${MAC_ADDRESS}")
QEMU_PARAMS+=("-device" "ich9-intel-hda")
QEMU_PARAMS+=("-device" "hda-output")
QEMU_PARAMS+=("-device" "pci-bridge,addr=12.0,chassis_nr=2,id=head.2")
# More parameters are added throughout the whole script

VIRT_INSTALL_PARAMS+=("--virt-type" "kvm")
VIRT_INSTALL_PARAMS+=("--os-variant" "win10")
VIRT_INSTALL_PARAMS+=("--arch=x86_64")

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
        #sudo $DISTRO_UTILS_DIR/prepare-vm
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

if [ ! -f "${OVMF_VARS_VM}" ]; then
    echo "> Creating OVMF_VARS copy for this VM..."
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
    LOOKING_GLASS_BUFFER_SIZE="${BUFFER_SIZE}M"
    echo "> Looking Glass buffer size set to: ${LOOKING_GLASS_BUFFER_SIZE}"
    if [ "$VM_START_MODE" = "qemu" ]; then
        QEMU_PARAMS+=("-device" "ivshmem-plain,memdev=ivshmem,bus=pcie.0")
        QEMU_PARAMS+=("-object" "memory-backend-file,id=ivshmem,share=on,mem-path=/dev/shm/looking-glass,size=${LOOKING_GLASS_BUFFER_SIZE}")
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        VIRT_INSTALL_PARAMS+=("--xml xpath.set=./devices/shmem/model/@type=ivshmem-plain")
        VIRT_INSTALL_PARAMS+=("--xml xpath.set=./devices/shmem/size=32")
        VIRT_INSTALL_PARAMS+=("--xml xpath.set=./devices/shmem/size/@unit=M")
    fi
else
    echo "> Not using Looking Glass..."
fi

if [ -z "$DGPU_ROM" ]; then
    echo "> Not using DGPU vBIOS override..."
    DGPU_ROM_PARAM=",rombar=0"
else
    echo "> Using DGPU vBIOS override..."
    DGPU_ROM_PARAM=",romfile=${DGPU_ROM}"
fi

if [ -z "$IGPU_ROM" ]; then
    echo "> Not using DGPU vBIOS override..."
    IGPU_ROM_PARAM=",rombar=0"
else
    echo "> Using DGPU vBIOS override..."
    IGPU_ROM_PARAM=",romfile=${IGPU_ROM}"
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
        QEMU_PARAMS+=("-device" "ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1") # DGPU root port
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        VIRT_INSTALL_PARAMS+=("--controller" "type=pci,model=pcie-root-port" "--xml xpath.set=./devices/controller/model/@name=ioh3420") # <controller type='pci' model='pcie-root-port'><model name='ioh3420'/></controller>
    fi

    # TODO: when the VM boots, check what chassis and slot libvirt allocates. Then plug that into the vfio-pci line.
    QEMU_PARAMS+=("-device" "vfio-pci,host=${DGPU_PCI_ADDRESS},bus=root.1,addr=00.0,x-pci-sub-device-id=0x${DGPU_SS_DEVICE_ID},x-pci-sub-vendor-id=0x${DGPU_SS_VENDOR_ID},multifunction=on${DGPU_ROM_PARAM}")

    #if [ "$VM_START_MODE" = "qemu" ]; then
    #    QEMU_PARAMS+=("-device" "vfio-pci,host=${DGPU_PCI_ADDRESS},bus=root.1,addr=00.0,x-pci-sub-device-id=0x${DGPU_SS_DEVICE_ID},x-pci-sub-vendor-id=0x${DGPU_SS_VENDOR_ID},multifunction=on${DGPU_ROM_PARAM}")
    #elif [ "$VM_START_MODE" = "virt-install" ]; then
    #    VIRT_INSTALL_PARAMS+=("--hostdev" "${DGPU_PCI_ADDRESS},address.type=pci,address.multifunction=on,address") # TODO: not complete; i.e. rom file param missing
    #fi
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

    if [ "$USE_DMA_BUF" = true ]; then
        echo "> Using dma-buf..."
        QEMU_PARAMS+=("-display" "egl-headless") #"-display" "gtk,gl=on" # DMA BUF Display
        GVTG_DISPLAY_STATE="on"
    else
        echo "> Not using dma-buf..."
        GVTG_DISPLAY_STATE="off"
    fi
    
    QEMU_PARAMS+=("-device" "vfio-pci,bus=pcie.0,addr=02.0,sysfsdev=/sys/bus/pci/devices/0000:${IGPU_PCI_ADDRESS}/${VGPU_UUID},x-igd-opregion=on${IGPU_ROM_PARAM},display=${GVTG_DISPLAY_STATE}") # GVT-G
    
    # TODO: same as for iGPU
    #if [ "$VM_START_MODE" = "qemu" ]; then
    #    QEMU_PARAMS+=("-device" "vfio-pci,bus=pcie.0,addr=02.0,sysfsdev=/sys/bus/pci/devices/0000:${IGPU_PCI_ADDRESS}/${VGPU_UUID},x-igd-opregion=on${IGPU_ROM_PARAM},display=${GVTG_DISPLAY_STATE}") # GVT-G
    #elif [ "$VM_START_MODE" = "virt-install" ]; then
    #    VIRT_INSTALL_PARAMS+=("--hostdev" "")
    #fi
else
    echo "> Not using mediated iGPU passthrough..."
fi

if [ "$USE_SPICE" = true ]; then
    echo "> Using spice on port ${SPICE_PORT}..."
    QEMU_PARAMS+=("-spice" "port=${SPICE_PORT},addr=127.0.0.1,disable-ticketing") #Spice
    if [ "$VM_START_MODE" = "qemu" ]; then
        QEMU_PARAMS+=("-spice" "port=${SPICE_PORT},addr=127.0.0.1,disable-ticketing") #Spice
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        VIRT_INSTALL_PARAMS+=("--channel" "spicevmc")
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
        mv "${PROJECT_DIR}/acpi-tables/fake-battery.aml" "${VM_FILES_DIR}/fake-battery.aml"
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
            sudo docker run --rm -ti -v "${PATCHED_OVMF_FILES_DIR}/tmp-build:/build:z" -v "${DGPU_ROM_DIR}:/roms:z" -e "VROM=${DGPU_ROM_NAME}" ovmf-vbios-patch
            sudo chown "$(whoami):$(id -gn "$(whoami)")" -R "${PATCHED_OVMF_FILES_DIR}/tmp-build"
            sudo mv "${PATCHED_OVMF_FILES_DIR}/tmp-build/OVMF_CODE.fd" "${PATCHED_OVMF_FILES_DIR}/${DGPU_ROM_NAME}_OVMF_CODE.fd"
            sudo mv "${PATCHED_OVMF_FILES_DIR}/tmp-build/OVMF_VARS.fd" "${PATCHED_OVMF_FILES_DIR}/${DGPU_ROM_NAME}_OVMF_VARS.fd"
            sudo rm -rf "${PATCHED_OVMF_FILES_DIR}/tmp-build"
        fi
        OVMF_CODE="${PATCHED_OVMF_FILES_DIR}/${DGPU_ROM_NAME}_OVMF_CODE.fd"
        OVMF_VARS_VM="${PATCHED_OVMF_FILES_DIR}/${DGPU_ROM_NAME}_OVMF_VARS.fd"
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

if [ -z "$USB_DEVICES" ]; then
    echo "> Not using USB passthrough..."
    USB_DEVICE_PARAMS=""
else
    echo "> Using USB passthrough..."
    QEMU_PARAMS+=("-usb")
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

give_qemu_access() {
    local skip_root=true
    local -a paths
    IFS=/ read -r -a paths <<<"$1"
    local i
    for (( i = 1; i < ${#paths[@]}; i++ )); do
        paths[i]="${paths[i-1]}/${paths[i]}"
    done
    paths[0]=/
    for current_path in "${paths[@]}" ; do
        if [ "$skip_root" = true ] && [ "${current_path}" = "/" ]; then
            continue
        fi
        echo "> Granting qemu access to: '${current_path}'"
        sudo setfacl --modify user:qemu:rx "${current_path}"
        sudo chmod +x "${current_path}"
    done
    #sudo chmod 777 "$1"
}

give_qemu_access "${INSTALL_IMG}"

#sudo bash -c "echo 'user = root' >> /etc/libvirt/qemu.conf"
#sudo systemctl restart libvirtd

# Delete VM
sudo virsh destroy --domain WindowsVM &> /dev/null
sudo virsh undefine --domain WindowsVM --nvram &> /dev/null

if [ "$VM_START_MODE" = "qemu" ]; then
    echo "> Starting the spice client..."
    spicy -h localhost -p 5900 &
    echo "> Starting the Virtual Machine using qemu..."
    sudo qemu-system-x86_64 "${QEMU_PARAMS[@]}"
elif [ "$VM_START_MODE" = "virt-install" ]; then
    echo "> Starting the Virtual Machine using virt-install..."
    #VIRT_INSTALL_PARAMS+=("--debug")
    for param in "${QEMU_PARAMS[@]}"; do
        VIRT_INSTALL_PARAMS+=("--qemu-commandline='${param}'")
    done
    sudo virt-install "${VIRT_INSTALL_PARAMS[@]}"
fi


# This gets executed when the vm exits
if [ "$DGPU_PASSTHROUGH" = true ]; then
    echo "> Unbinding dGPU from vfio driver..."
    driver unbind "${DGPU_PCI_ADDRESS}"
    if [ "$HOST_DGPU_DRIVER" = "nvidea" ] || [ "$HOST_DGPU_DRIVER" = "nuveau" ]; then
        echo "> Turn the dGPU off using bumblebee..."
        sudo bash -c "echo 'OFF' >> /proc/acpi/bbswitch"
    fi
    echo "> Binding dGPU back to ${HOST_DGPU_DRIVER} driver..."
    driver bind "${DGPU_PCI_ADDRESS}" "${HOST_DGPU_DRIVER}"
fi
if [ "$SHARE_IGPU" = true ]; then
    # FIXME: There is a bug in Linux that prevents creating new vGPUs without rebooting after removing one. 
    #        So for now we can't create a new vGPU every time the VM starts.
    echo "> Keeping Intel vGPU for next VM start..."
    #echo "> Remove Intel vGPU..."
    #vgpu remove "${IGPU_PCI_ADDRESS}" "${VGPU_UUID}"
fi