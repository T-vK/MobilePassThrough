#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
PROJECT_DIR="${SCRIPT_DIR}"
UTILS_DIR="${PROJECT_DIR}/utils"
DISTRO=$("${UTILS_DIR}/distro-info")
DISTRO_UTILS_DIR="${UTILS_DIR}/${DISTRO}"
VM_FILES_DIR="${PROJECT_DIR}/vm-files"

VM_DISK_SIZE=20G # Changing this has no effect after `prepare-vm` has already been called to create a VM disk
RAM_SIZE=4G
CPU_CORE_COUNT=3
INSTALL_IMG="${VM_FILES_DIR}/windows10.iso"
DRIVE_IMG="${VM_FILES_DIR}/WindowsVM.img"
#SMB_SHARE_FOLDER="${VM_FILES_DIR}/vmshare"
#GPU_ROM="${VM_FILES_DIR}/vbios-roms/vbios.rom"
WIN_VARS="${VM_FILES_DIR}/WIN_VARS.fd"
OVMF_CODE="/usr/share/OVMF/OVMF_CODE.fd"
VIRTIO_WIN_IMG="/usr/share/virtio-win/virtio-win.iso"
GPU_PCI_ADDRESS=01:00.0
# If you don't use Bumblebee, you need to set the GPU_PCI_ADDRESS manually (see output of lspci) and you have to remove all following occurences of optirun in this script
# This script has only been tested with Bumblebee enabled.

if [ ! -f "${DRIVE_IMG}" ]; then
    # If the VM drive doesn't exist, run the prepare-vm script to create it
    sudo $DISTRO_UTILS_DIR/prepare-vm
fi

MAC_ADDRESS=$(cat "${VM_FILES_DIR}/MAC_ADDRESS.txt")


GPU_IDS=$(optirun lspci -n -s "${GPU_PCI_ADDRESS}" | grep -oP "\w+:\w+" | tail -1)
GPU_VENDOR_ID=$(echo "${GPU_IDS}" | cut -d ":" -f1)
GPU_DEVICE_ID=$(echo "${GPU_IDS}" | cut -d ":" -f2)
GPU_SS_IDS=$(optirun lspci -vnn -d "${GPU_IDS}" | grep "Subsystem:" | grep -oP "\w+:\w+")
GPU_SS_VENDOR_ID=$(echo "${GPU_SS_IDS}" | cut -d ":" -f1)
GPU_SS_DEVICE_ID=$(echo "${GPU_SS_IDS}" | cut -d ":" -f2)

echo "GPU_PCI_ADDRESS: ${GPU_PCI_ADDRESS}"
echo "GPU_IDS: $GPU_IDS"
echo "GPU_VENDOR_ID: $GPU_VENDOR_ID"
echo "GPU_DEVICE_ID: $GPU_DEVICE_ID"
echo "GPU_SS_IDS: $GPU_SS_IDS"
echo "GPU_SS_VENDOR_ID: $GPU_SS_VENDOR_ID"
echo "GPU_SS_DEVICE_ID: $GPU_SS_DEVICE_ID"

#sudo echo "options vfio-pci ids=${GPU_VENDOR_ID}:${GPU_DEVICE_ID}" > /etc/modprobe.d/vfio.conf

echo "Loading vfio-pci kernel module..."
sudo modprobe vfio-pci
echo "Unbinding Nvidia driver from GPU..."
sudo echo "0000:${GPU_PCI_ADDRESS}" > "/sys/bus/pci/devices/0000:${GPU_PCI_ADDRESS}/driver/unbind"

echo "Binding VFIO driver to GPU..."
sudo echo "${GPU_VENDOR_ID} ${GPU_DEVICE_ID}" > "/sys/bus/pci/drivers/vfio-pci/new_id"
#sudo echo "8086:1901" > "/sys/bus/pci/drivers/vfio-pci/new_id"
# TODO: Make sure to also do the rebind for the other devices that are in the same iommu group (exclude stuff like PCI Bridge root ports that don't have vfio drivers)


# This ensures, that the VBIOS will not be overridden if GPU_ROM is not set
if [ -z "$GPU_ROM" ]; then
    GPU_ROM_PARAM=""
else
    GPU_ROM_PARAM=",romfile=${GPU_ROM}"
fi

# This ensures, that the -net parameter for smb sharing won't be passed if SMB_SHARE_FOLDER is not set
if [ -z "$SMB_SHARE_FOLDER" ]; then
    SMB_SHARE_PARAM=""
else
    SMB_SHARE_PARAM="-net user,smb=${SMB_SHARE_FOLDER}"
fi

echo "Starting the Virtual Machine"
# Refer https://github.com/saveriomiroddi/qemu-pinning for how to set your cpu affinity properly
sudo qemu-system-x86_64 \
  -name "Windows10-QEMU" \
  -machine type=q35,accel=kvm \
  -global ICH9-LPC.disable_s3=1 \
  -global ICH9-LPC.disable_s4=1 \
  -enable-kvm \
  -cpu host,kvm=off,hv_vapic,hv_relaxed,hv_spinlocks=0x1fff,hv_time,hv_vendor_id=12alphanum \
  -smp ${CPU_CORE_COUNT} \
  -m ${RAM_SIZE} \
  -mem-prealloc \
  -balloon none \
  -rtc clock=host,base=localtime \
  -nographic \
  -vga none \
  -serial none \
  -parallel none \
  -boot menu=on \
  -boot order=c \
  -k en-us \
  ${SMB_SHARE_PARAM} \
  -spice port=5901,addr=127.0.0.1,disable-ticketing \
  -drive "if=pflash,format=raw,readonly=on,file=${OVMF_CODE}" \
  -drive "if=pflash,format=raw,file=${WIN_VARS}" \
  -drive "file=${INSTALL_IMG},index=1,media=cdrom" \
  -drive "file=${VIRTIO_WIN_IMG},index=2,media=cdrom" \
  -drive "id=disk0,if=virtio,cache.direct=on,if=virtio,aio=native,format=raw,file=${DRIVE_IMG}" \
  -netdev "type=tap,id=net0,ifname=tap0,script=${VM_FILES_DIR}/tap_ifup,downscript=${VM_FILES_DIR}/tap_ifdown,vhost=on" \
  -device ich9-intel-hda \
  -device hda-output \
  -device qxl,bus=pcie.0,addr=1c.4,id=video.2 \
  -device ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1 \
  -device "vfio-pci,host=${GPU_PCI_ADDRESS},bus=root.1,addr=00.0,x-pci-sub-device-id=0x${GPU_SS_DEVICE_ID},x-pci-sub-vendor-id=0x${GPU_SS_VENDOR_ID},multifunction=on${GPU_ROM_PARAM}" \
  -device virtio-net-pci,netdev=net0,addr=19.0,mac=${MAC_ADDRESS} \
  -device pci-bridge,addr=12.0,chassis_nr=2,id=head.2 \
  -device virtio-keyboard-pci,bus=head.2,addr=03.0,display=video.2 \
  -device virtio-mouse-pci,bus=head.2,addr=04.0,display=video.2 \
  #-usb \
  #-device usb-host,vendorid=0x0b95,productid=0x1790 \
  #-device usb-host,hostbus=1,hostaddr=8 \
  #-device usb-tablet \

# This should get executed when the vm exits
sudo echo "0000:${GPU_PCI_ADDRESS}" > "/sys/bus/pci/drivers/vfio-pci/0000:${GPU_PCI_ADDRESS}/driver/unbind"
sudo echo "OFF" >> /proc/acpi/bbswitch
