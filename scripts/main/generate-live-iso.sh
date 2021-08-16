#!/usr/bin/env bash
while [[ "$PROJECT_DIR" != */MobilePassThrough ]]; do PROJECT_DIR="$(readlink -f "$(dirname "${PROJECT_DIR:-0}")")"; done
source "$PROJECT_DIR/scripts/utils/common/libs/helpers"
loadConfig

alias getMissingExecutables="${COMMON_UTILS_TOOLS_DIR}/get-missing-executables"
alias updatePkgInfo="'${PACKAGE_MANAGER}' update"
alias getExecPkg="'${PACKAGE_MANAGER}' install --executables"

DRIVE="$1"

if [ "$DRIVE" = "" ]; then
    echo "ERROR: Missing parameter. You have to specify the device onto which to flash the Live ISO! E.g. /dev/sda"
    exit 1
fi

ISO_DOWNLOAD_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/34/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-34-1.2.iso"
ISO_FILE="${LIVE_ISO_FILES_DIR}/Fedora-Workstation-Live-x86_64-34-1.2.iso"
ISO_FILE_MODIFIED="${LIVE_ISO_FILES_DIR}/Fedora-Workstation-Live-x86_64-34-1.2.modified.iso"

SOURCE_SQUASHFS_IMG="/LiveOS/squashfs.img"
SQUASHFS_IMG="/tmp/squashfs.img"
SQUASHFS_EXTRACTED="/tmp/squashfs-extracted"
SQUASHFS_IMG_MODIFIED="/tmp/squashfs.modified.img"

ROOTFS_IMG="${SQUASHFS_EXTRACTED}/LiveOS/rootfs.img"
ROOTFS_MOUNTPOINT="/tmp/rootfs-mountpoint"

MISSING_EXECUTABLES="$(getMissingExecutables "$EXEC_DEPS_LIVE_ISO")"

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

if [ ! -f "${ISO_FILE}" ]; then
    echo "> Downloading Fedora ISO..."
    wget "${ISO_DOWNLOAD_URL}" -c -O "${ISO_FILE}.part"
    mv "${ISO_FILE}.part" "${ISO_FILE}"
else
    echo "> [Skipped] Fedora ISO already downloaded."
fi

sudo rm -rf "${ISO_FILE_MODIFIED}"

echo "> Extract the squashfs image and unsquash it"
sudo rm -f "${SQUASHFS_IMG}"
xorriso -dev "${ISO_FILE}" -osirrox "on" -extract "${SOURCE_SQUASHFS_IMG}" "${SQUASHFS_IMG}"
sudo unsquashfs -d "${SQUASHFS_EXTRACTED}" "${SQUASHFS_IMG}" # Unsquash the squashfs and mount the rootfs in read-write mode
sudo rm -f "${SQUASHFS_IMG}"

echo "> Mount the rootfs image of the unsquashed squashfs image"
sudo umount --force "${ROOTFS_MOUNTPOINT}"
sudo rm -rf "${ROOTFS_MOUNTPOINT}"
sudo mkdir -p "${ROOTFS_MOUNTPOINT}"
sudo mount -o loop,rw "${ROOTFS_IMG}" "${ROOTFS_MOUNTPOINT}"

echo "> Add files to the rootfs"
sudo mkdir "${ROOTFS_MOUNTPOINT}/etc/skel/Downloads/"
sudo mkdir -p "${ROOTFS_MOUNTPOINT}/etc/skel/.config/autostart"
sudo cp "/home/fedora/Projects/MobilePassThrough/live-iso-files/get-mbpt.sh" "${ROOTFS_MOUNTPOINT}/etc/skel/Downloads/"
sudo cp "/home/fedora/Projects/MobilePassThrough/live-iso-files/mbpt.desktop" "${ROOTFS_MOUNTPOINT}/etc/skel/.config/autostart/"
sudo cp "/home/fedora/Projects/MobilePassThrough/live-iso-files/mbpt.desktop" "${ROOTFS_MOUNTPOINT}/usr/share/applications/"

echo "> Unmount the rootfs image again"
sudo umount "${ROOTFS_MOUNTPOINT}"

echo "> Make a new squashfs image from the unsquashed modified squashfs image"
sudo mksquashfs "${SQUASHFS_EXTRACTED}" "${SQUASHFS_IMG_MODIFIED}" -b 1024k -comp xz -Xbcj x86 -e boot
sudo rm -rf "${SQUASHFS_EXTRACTED}"

echo "> Overwrite the squashfs image inside the ISO with the modified one"
xorriso -indev "${ISO_FILE}" -outdev "${ISO_FILE_MODIFIED}" -md5 "all" -compliance no_emul_toc \
-update "${SQUASHFS_IMG_MODIFIED}" "/LiveOS/squashfs.img" \
-boot_image any replay

echo "> Remove modified squashfs image"
sudo rm -f "${SQUASHFS_IMG_MODIFIED}"

echo "> Flashing ISO to USB drive"
mp="$(mount | grep "$DRIVE" | cut -d' ' -f3)" # get mountpoint for device
if [ "$mp" != "" ]; then
    echo "$DRIVE is still mounted. Unmounting $DRIVE now..."
    umount --force "$mp"
fi
yes "" | sudo /home/fedora/Downloads/livecd-tools/tools/livecd-iso-to-disk.sh --format ext4 --efi --force --overlay-size-mb 8000 "$ISO_FILE_MODIFIED" "$DRIVE"

exit

# TODO: Figure out a way to add kernel parameters to the ISO

#addKernelParams "iommu=1 intel_iommu=on amd_iommu=on kvm.ignore_msrs=1 rd.driver.pre=vfio-pci i915.enable_gvt=1 nouveau.modeset=0"

#GRUB_CFG_PATH="${ROOTFS_MOUNTPOINT}/etc/default/grub"
function addKernelParams() {
    sudo rm -f "/tmp/grub.conf"
    sudo rm -f "/tmp/isolinux.cfg"
    sudo rm -f "/tmp/BOOT.conf"
    sudo rm -f "/tmp/grub.cfg"
    
    xorriso -dev "${ISO_FILE}" -osirrox "on" -extract "/isolinux/grub.conf" "/tmp/grub.conf" \
    -extract "/isolinux/isolinux.cfg" "/tmp/isolinux.cfg" \
    -extract "/EFI/BOOT/BOOT.conf" "/tmp/BOOT.conf" \
    -extract "/EFI/BOOT/grub.cfg" "/tmp/grub.cfg"

    sudo sed -i "s/rd.live.image/$1 &/" "/tmp/grub.conf"
    sudo sed -i "s/rd.live.image/$1 &/" "/tmp/isolinux.cfg"
    sudo sed -i "s/rd.live.image/$1 &/" "/tmp/BOOT.conf"
    sudo sed -i "s/rd.live.image/$1 &/" "/tmp/grub.cfg"

    xorriso -indev "${ISO_FILE}" -outdev "${ISO_FILE_MODIFIED}" -compliance no_emul_toc \
    -update "/tmp/grub.conf" "/isolinux/grub.conf" \
    -update "/tmp/isolinux.cfg" "/isolinux/isolinux.cfg" \
    -update "/tmp/BOOT.conf" "/EFI/BOOT/BOOT.conf" \
    -update "/tmp/grub.cfg" "/EFI/BOOT/grub.cfg" \
    -boot_image any replay
}