#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
PROJECT_DIR="${SCRIPT_DIR}"
UTILS_DIR="${PROJECT_DIR}/utils"
DISTRO=$("${UTILS_DIR}/distro-info")
DISTRO_UTILS_DIR="${UTILS_DIR}/${DISTRO}"

if [ "$1" == "--auto" ]; then
    INTERACTIVE=false
else
    INTERACTIVE=true
fi

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

if [[ ${DRIVE_IMG} == /dev/* ]] ; then
    echo "> Using a physical OS drive..."
    OS_DRIVE_PARAM="-drive file=${DRIVE_IMG},if=virtio  -snapshot"
    #OS_DRIVE_PARAM="-drive file=/dev/sda,if=virtio -drive file=/dev/sdb,if=virtio -drive file=/dev/sdc,if=virtio -drive file=/dev/sdd,if=virtio -snapshot"
elif [[ ${DRIVE_IMG} == *.img ]] ; then
    echo "> Using a virtual OS drive..."
    if [ ! -f "${DRIVE_IMG}" ]; then
        #sudo $DISTRO_UTILS_DIR/prepare-vm
        echo "> Creating a virtual disk for the VM..."
        qemu-img create -f raw "${DRIVE_IMG}" "${VM_DISK_SIZE}"
    fi
    OS_DRIVE_PARAM="-drive id=disk0,if=virtio,cache.direct=on,if=virtio,aio=native,format=raw,file=${DRIVE_IMG}"
else
    echo "> Error: It appears that no proper OS drive (image) has been provided. Check your 'DRIVE_IMG' var."
    exit
fi

if [ ! -f "${WIN_VARS}" ]; then
    echo "> Creating OVMF_VARS copy for this VM..."
    sudo cp "${OVMF_VARS}" "${WIN_VARS}"
fi

if sudo which optirun &> /dev/null && sudo optirun echo > /dev/null ; then
    USE_BUMBLEBEE=true
    OPTIRUN_PREFIX="optirun "
    echo "> Bumblebee works fine on this system. Using optirun when necessary..."
else
    USE_BUMBLEBEE=false
    OPTIRUN_PREFIX=""
    echo "> Warning: Bumblebee is not available or doesn't work properly. Continuing anyway..."
fi

echo "> Loading vfio-pci kernel module..."
sudo modprobe vfio-pci

if [ "$USE_LOOKING_GLASS" = true ] ; then
    echo "> Using Looking Glass..."
    echo "> Calculating required buffer size for ${LOOKING_GLASS_MAX_SCREEN_WIDTH}x${LOOKING_GLASS_MAX_SCREEN_HEIGHT} for Looking Glass..."
    UNROUNDED_BUFFER_SIZE=$((($LOOKING_GLASS_MAX_SCREEN_WIDTH * $LOOKING_GLASS_MAX_SCREEN_HEIGHT * 4 * 2)/1024/1024+2))
    BUFFER_SIZE=1
    while [[ $BUFFER_SIZE -le $UNROUNDED_BUFFER_SIZE ]]; do
        BUFFER_SIZE=$(($BUFFER_SIZE*2))
    done;
    LOOKING_GLASS_BUFFER_SIZE="${BUFFER_SIZE}M"
    echo "> Looking Glass buffer size set to: ${LOOKING_GLASS_BUFFER_SIZE}"
    echo "> Starting IVSHMEM server..."
    sudo -u qemu ivshmem-server -p /tmp/ivshmem.pid -S /tmp/ivshmem_socket -l "${LOOKING_GLASS_BUFFER_SIZE}" -n 8
    echo "> Adjusting permissons for the IVSHMEM server socket..."
    sudo chmod 600 /tmp/ivshmem_socket
    LOOKING_GLASS_DEVICE_PARAM="-device ivshmem-plain,memdev=ivshmem,bus=pcie.0"
    LOOKING_GLASS_OBJECT_PARAM="-object memory-backend-file,id=ivshmem,share=on,mem-path=/dev/shm/looking-glass,size=${LOOKING_GLASS_BUFFER_SIZE}"
else
    echo "> Not using Looking Glass..."
    LOOKING_GLASS_DEVICE_PARAM=""
    LOOKING_GLASS_OBJECT_PARAM=""
fi

if [ -z "$DGPU_ROM" ]; then
    echo "> Not using DGPU vBIOS override..."
    DGPU_ROM_PARAM=""
else
    echo "> Using DGPU vBIOS override..."
    DGPU_ROM_PARAM=",romfile=${DGPU_ROM}"
fi

if [ -z "$SMB_SHARE_FOLDER" ]; then
    echo "> Not using SMB share..."
    SMB_SHARE_PARAM=""
else
    echo "> Using SMB share..."
    SMB_SHARE_PARAM="-net user,smb=${SMB_SHARE_FOLDER}"
fi

if [ "$DGPU_PASSTHROUGH" = true ] ; then
    echo "> Using dGPU passthrough..."
    
    echo "> Retrieving and parsing DGPU IDs..."
    DGPU_IDS=$(sudo ${OPTIRUN_PREFIX}lspci -n -s "${DGPU_PCI_ADDRESS}" | grep -oP "\w+:\w+" | tail -1)
    DGPU_VENDOR_ID=$(echo "${DGPU_IDS}" | cut -d ":" -f1)
    DGPU_DEVICE_ID=$(echo "${DGPU_IDS}" | cut -d ":" -f2)
    DGPU_SS_IDS=$(optirun lspci -vnn -d "${DGPU_IDS}" | grep "Subsystem:" | grep -oP "\w+:\w+")
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
    
    echo "> Unbinding dGPU from ${HOST_DGPU_DRIVER} driver..."
    sudo bash -c "echo '0000:${DGPU_PCI_ADDRESS}' '/sys/bus/pci/devices/0000:${DGPU_PCI_ADDRESS}/driver/unbind'"
    echo "> Binding dGPU to VFIO driver..."
    sudo bash -c "echo '${DGPU_VENDOR_ID} ${DGPU_DEVICE_ID}' > '/sys/bus/pci/drivers/vfio-pci/new_id'"
    #sudo bash -c "echo 'options vfio-pci ids=${DGPU_VENDOR_ID}:${DGPU_DEVICE_ID}' > '/etc/modprobe.d/vfio.conf'"
    #sudo bash -c "echo '8086:1901' > '/sys/bus/pci/drivers/vfio-pci/new_id'"
    # TODO: Make sure to also do the rebind for the other devices that are in the same iommu group (exclude stuff like PCI Bridge root ports that don't have vfio drivers)
    DGPU_ROOT_PORT_PARAM="-device ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1"
    DGPU_PARAM="-device vfio-pci,host=${DGPU_PCI_ADDRESS},bus=root.1,addr=00.0,x-pci-sub-device-id=0x${DGPU_SS_DEVICE_ID},x-pci-sub-vendor-id=0x${DGPU_SS_VENDOR_ID},multifunction=on${DGPU_ROM_PARAM}"
else
    echo "> Not using dGPU passthrough..."
    DGPU_ROOT_PORT_PARAM=""
    DGPU_PARAM=""
fi

if [ "$SHARE_IGPU" = true ] ; then
    echo "> Using mediated iGPU passthrough..."
    sudo modprobe kvmgt #sudo modprobe xengt
    sudo modprobe vfio-mdev
    sudo modprobe vfio-iommu-type1
    VGPU_UUID=$(uuid)
    VGPU_TYPES_DIR="/sys/bus/pci/devices/0000:${IGPU_PCI_ADDRESS}/mdev_supported_types/*"
    VGPU_TYPE_DIR=( $VGPU_TYPES_DIR )
    VGPU_TYPE=$(basename -- "${VGPU_TYPE_DIR}")
    # For further twaeking read: https://github.com/intel/gvt-linux/wiki/GVTg_Setup_Guide#53-create-vgpu-kvmgt-only
    echo "> Create temporary vGPU for mediated iGPU passthrough..."
    sudo bash -c "echo '${VGPU_UUID}' > '/sys/bus/pci/devices/0000:${IGPU_PCI_ADDRESS}/mdev_supported_types/${VGPU_TYPE}/create'"
     # display=on when using dmabuf

    if [ "$USE_DMA_BUF" = true ] ; then
        echo "> Using dma-buf..."
        DMA_BUF_DISPLAY_PARAM="-display egl-headless" #"-display gtk,gl=on"
        GVTG_PARAM="-device vfio-pci,bus=pcie.0,addr=02.0,sysfsdev=/sys/bus/pci/devices/0000:${IGPU_PCI_ADDRESS}/${VGPU_UUID},x-igd-opregion=on,display=on"
    else
        echo "> Not using dma-buf..."
        DMA_BUF_DISPLAY_PARAM=""
        GVTG_PARAM="-device vfio-pci,bus=pcie.0,addr=02.0,sysfsdev=/sys/bus/pci/devices/0000:${IGPU_PCI_ADDRESS}/${VGPU_UUID},x-igd-opregion=on,display=off"
    fi
else
    echo "> Not using mediated iGPU passthrough..."
    GVTG_PARAM=""
fi

if [ "$USE_SPICE" = true ] ; then
    echo "> Using spice on port ${SPICE_PORT}..."
    SPICE_PARAM="-spice port=${SPICE_PORT},addr=127.0.0.1,disable-ticketing"
else
    echo "> Not using Spice..."
    SPICE_PARAM=""
fi

if [ "$USE_QXL" = true ] ; then
    echo "> Using QXL..."
    QXL_DEVICE_PARAM="-device qxl,bus=pcie.0,addr=1c.4,id=video.2"
    QXL_VGA_PARAM="-vga qxl"
else
    echo "> Not using QXL..."
    QXL_DEVICE_PARAM=""
    QXL_VGA_PARAM=""
fi

if [ -z "$USB_DEVICES" ]; then
    echo "> Not using USB passthrough..."
    USB_DEVICE_PARAMS=""
else
    echo "> Using USB passthrough..."
    IFS=';' read -a USB_DEVICES_ARRAY <<< "${USB_DEVICES}"
    USB_DEVICE_PARAMS=""
    for USB_DEVICE in "${USB_DEVICES_ARRAY[@]}"; do
        USB_DEVICE_PARAMS="${USB_DEVICE_PARAMS} -device usb-host,${USB_DEVICE}"
    done
    echo "USB_DEVICE_PARAMS: $USB_DEVICE_PARAMS"
fi

if [ "$VIRTUAL_INPUT_TYPE" = "virtio" ] ; then
    echo "> Using virtual input method 'virtio' for keyboard/mouse input..."
    VIRTUAL_INPUT_PARAMS="-device virtio-keyboard-pci,bus=head.2,addr=03.0,display=video.2 -device virtio-mouse-pci,bus=head.2,addr=04.0,display=video.2"
elif [ "$VIRTUAL_INPUT_TYPE" = "usb-tablet" ] ; then
    echo "> Using virtual input method 'usb-tablet' for keyboard/mouse input..."
    VIRTUAL_KEYBOARD_PARAM="-device usb-tablet"
else
    echo "> Not using virtual input method for keyboard/mouse input..."
    VIRTUAL_KEYBOARD_PARAM=""
fi

echo "> Starting the Virtual Machine..."
# Refer https://github.com/saveriomiroddi/qemu-pinning for how to set your cpu affinity properly
sudo qemu-system-x86_64 \
  -name "${VM_NAME}" \
  -machine type=q35,accel=kvm \
  -global ICH9-LPC.disable_s3=1 \
  -global ICH9-LPC.disable_s4=1 \
  -enable-kvm \
  -cpu host,kvm=off,hv_vapic,hv_relaxed,hv_spinlocks=0x1fff,hv_time,hv_vendor_id=12alphanum \
  -smp ${CPU_CORE_COUNT} \
  -m ${RAM_SIZE} \
  -mem-prealloc \
  -rtc clock=host,base=localtime \
  -nographic \
  -serial none \
  -parallel none \
  -boot order=d \
  -k en-us \
  ${SMB_SHARE_PARAM} \
  ${SPICE_PARAM} \
  -drive "if=pflash,format=raw,readonly=on,file=${OVMF_CODE}" \
  -drive "if=pflash,format=raw,file=${WIN_VARS}" \
  -drive "file=${INSTALL_IMG},index=1,media=cdrom" \
  -drive "file=${VIRTIO_WIN_IMG},index=2,media=cdrom" \
  -drive "file=${HELPER_ISO},index=3,media=cdrom" \
  -fda "${VIRTIO_WIN_VFD}" \
  -fdb "${AUTOUNATTEND_WIN_VFD}" \
  ${OS_DRIVE_PARAM} \
  -netdev "type=tap,id=net0,ifname=tap0,script=${VM_FILES_DIR}/tap_ifup,downscript=${VM_FILES_DIR}/tap_ifdown,vhost=on" \
  ${GVTG_PARAM} \
  -device ich9-intel-hda \
  -device hda-output \
  ${DGPU_ROOT_PORT_PARAM} \
  ${DGPU_PARAM} \
  -device virtio-net-pci,netdev=net0,addr=19.0,mac=${MAC_ADDRESS} \
  -device pci-bridge,addr=12.0,chassis_nr=2,id=head.2 \
  -usb \
  ${VIRTUAL_KEYBOARD_PARAM} \
  ${USB_DEVICE_PARAMS} \
  ${LOOKING_GLASS_DEVICE_PARAM} \
  ${LOOKING_GLASS_OBJECT_PARAM} \
  ${QXL_DEVICE_PARAM} \
  ${QXL_VGA_PARAM} \
  ${DMA_BUF_DISPLAY_PARAM}

# This gets executed when the vm exits
if [ "$DGPU_PASSTHROUGH" = true ] ; then
    echo "> Binding dGPU back to ${HOST_DGPU_DRIVER} driver..."
    sudo bash -c "echo '0000:${DGPU_PCI_ADDRESS}' > '/sys/bus/pci/drivers/vfio-pci/0000:${DGPU_PCI_ADDRESS}/driver/unbind'"
    sudo bash -c "echo 'OFF' >> /proc/acpi/bbswitch"
fi
if [ "$SHARE_IGPU" = true ] ; then
    echo "> Remove temporary Intel vGPU..."
    sudo bash -c "echo 1 > '/sys/bus/pci/devices/0000:${IGPU_PCI_ADDRESS}/${VGPU_UUID}/remove'"
fi
