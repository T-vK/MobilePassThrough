#!/usr/bin/env bash
while [[ "$PROJECT_DIR" != */MobilePassThrough ]]; do PROJECT_DIR="$(readlink -f "$(dirname "${PROJECT_DIR:-0}")")"; done
source "$PROJECT_DIR/scripts/utils/common/libs/helpers"
loadConfig

source "${PROJECT_DIR}/requirements.sh"

alias getMissingExecutables="${COMMON_UTILS_TOOLS_DIR}/get-missing-executables"
alias updatePkgInfo="'${PACKAGE_MANAGER}' update"
alias getExecPkg="'${PACKAGE_MANAGER}' install --executables"

MODE="$1"
DRIVE="$2"

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

if [ ! -d "${THIRDPARTY_DIR}/livecd-tools" ]; then
    echo "> Downloading and installing livecd-tools..."
    mkdir -p "${THIRDPARTY_DIR}"
    cd "${THIRDPARTY_DIR}"
    git clone https://github.com/livecd-tools/livecd-tools.git --branch=livecd-tools-28.3 --single-branch livecd-tools
    cd livecd-tools
    sudo make install
    sudo pip3 install urlgrabber
else
    echo "> [Skipped] livecd-tools already installed."
fi

cd "${PROJECT_DIR}"

function build_method_1() {
    if [ ! -f "${ISO_FILE}" ]; then
        echo "> Downloading Fedora ISO..."
        wget "${ISO_DOWNLOAD_URL}" -c -O "${ISO_FILE}.part"
        mv "${ISO_FILE}.part" "${ISO_FILE}"
    else
        echo "> [Skipped] Fedora ISO already downloaded."
    fi

    sudo rm -rf "${ISO_FILE_MODIFIED}"

    echo "> Rebuilding the ISO adding kernel parameters and some files..."
    TMP_SCRIPT="/tmp/tmp-rootfs-setup.sh"
    sudo rm -f "${TMP_SCRIPT}"
    echo "#!/usr/bin/env bash" > "${TMP_SCRIPT}"
    echo "mkdir -p /etc/skel/.config/autostart/" >> "${TMP_SCRIPT}"
    echo "IFS='' read -r -d '' GET_MBPT_SCRIPT <<\"EOF\"" >> "${TMP_SCRIPT}"
    echo "$(cat ${LIVE_ISO_FILES_DIR}/get-mbpt.sh)" >> "${TMP_SCRIPT}"
    echo "EOF" >> "${TMP_SCRIPT}"
    echo 'echo "$GET_MBPT_SCRIPT" > /etc/skel/get-mbpt.sh' >> "${TMP_SCRIPT}"
    echo "chmod +x /etc/skel/get-mbpt.sh" >> "${TMP_SCRIPT}"
    echo "IFS='' read -r -d '' GET_MBPT_DESKTOP_FILE <<\"EOF\"" >> "${TMP_SCRIPT}"
    echo "$(cat ${LIVE_ISO_FILES_DIR}/mbpt.desktop)" >> "${TMP_SCRIPT}"
    echo "EOF" >> "${TMP_SCRIPT}"
    echo 'echo "$GET_MBPT_DESKTOP_FILE" > /etc/skel/.config/autostart/mbpt.desktop' >> "${TMP_SCRIPT}"
    echo 'echo "$GET_MBPT_DESKTOP_FILE" > /usr/share/applications/mbpt.desktop' >> "${TMP_SCRIPT}"
    sudo chmod +x "${TMP_SCRIPT}"

    USERNAME="T-vK" sudo editliveos \
    --builder "T-vK" \
    --noshell \
    --script "${TMP_SCRIPT}" \
    --extra-kernel-args "$ALL_KERNEL_PARAMS" \
    --output "${LIVE_ISO_FILES_DIR}" \
    --name "mbpt" \
    "${ISO_FILE}"
    
    mv "${LIVE_ISO_FILES_DIR}/mbpt-"*.iso "${ISO_FILE_MODIFIED}"

    sudo rm -f "${TMP_SCRIPT}"
}

function build_method_2() {
    if [ ! -f "${ISO_FILE}" ]; then
        echo "> Downloading Fedora ISO..."
        wget "${ISO_DOWNLOAD_URL}" -c -O "${ISO_FILE}.part"
        mv "${ISO_FILE}.part" "${ISO_FILE}"
    else
        echo "> [Skipped] Fedora ISO already downloaded."
    fi

    sudo rm -rf "${ISO_FILE_MODIFIED}"

    echo "> Extracting the squashfs image and unsquash it..."
    sudo rm -f "/tmp/grub.conf"
    sudo rm -f "/tmp/isolinux.cfg"
    sudo rm -f "/tmp/BOOT.conf"
    sudo rm -f "/tmp/grub.cfg"
    sudo rm -f "${SQUASHFS_IMG}"
    xorriso -dev "${ISO_FILE}" -osirrox "on" \
    -extract "${SOURCE_SQUASHFS_IMG}" "${SQUASHFS_IMG}" \
    -extract "/isolinux/grub.conf" "/tmp/grub.conf" \
    -extract "/isolinux/isolinux.cfg" "/tmp/isolinux.cfg" \
    -extract "/EFI/BOOT/BOOT.conf" "/tmp/BOOT.conf" \
    -extract "/EFI/BOOT/grub.cfg" "/tmp/grub.cfg"
    sudo rm -rf "${SQUASHFS_EXTRACTED}"
    sudo unsquashfs -d "${SQUASHFS_EXTRACTED}" "${SQUASHFS_IMG}" # Unsquash the squashfs and mount the rootfs in read-write mode
    sudo rm -f "${SQUASHFS_IMG}"

    echo "> Mounting the rootfs image of the unsquashed squashfs image..."
    sudo umount --force "${ROOTFS_MOUNTPOINT}"
    sudo rm -rf "${ROOTFS_MOUNTPOINT}"
    sudo mkdir -p "${ROOTFS_MOUNTPOINT}"
    sudo mount -o loop,rw "${ROOTFS_IMG}" "${ROOTFS_MOUNTPOINT}"

    echo "> Adding files to the rootfs..."
    sudo mkdir -p "${ROOTFS_MOUNTPOINT}/etc/skel/.config/autostart/"
    sudo cp "${LIVE_ISO_FILES_DIR}/get-mbpt.sh" "${ROOTFS_MOUNTPOINT}/etc/skel/"
    sudo cp "${LIVE_ISO_FILES_DIR}/mbpt.desktop" "${ROOTFS_MOUNTPOINT}/etc/skel/.config/autostart/"
    sudo cp "${LIVE_ISO_FILES_DIR}/mbpt.desktop" "${ROOTFS_MOUNTPOINT}/usr/share/applications/"

    echo "> Unmounting the rootfs image again..."
    sudo umount "${ROOTFS_MOUNTPOINT}"
    sudo rm -rf "${ROOTFS_MOUNTPOINT}"

    echo "> Making a new squashfs image from the unsquashed modified squashfs image..."
    sudo mksquashfs "${SQUASHFS_EXTRACTED}" "${SQUASHFS_IMG_MODIFIED}" -b 1024k -comp xz -Xbcj x86 -e boot
    sudo rm -rf "${SQUASHFS_EXTRACTED}"

    sudo sed -i "s/rd.live.image/$1 &/" "/tmp/grub.conf"
    sudo sed -i "s/rd.live.image/$1 &/" "/tmp/isolinux.cfg"
    sudo sed -i "s/rd.live.image/$1 &/" "/tmp/BOOT.conf"
    sudo sed -i "s/rd.live.image/$1 &/" "/tmp/grub.cfg"

    echo "> Overwriting the squashfs image inside the ISO with the modified one..."
    xorriso -indev "${ISO_FILE}" -outdev "${ISO_FILE_MODIFIED}" -md5 "all" -compliance no_emul_toc \
    -update "${SQUASHFS_IMG_MODIFIED}" "/LiveOS/squashfs.img" \
    -update "/tmp/grub.conf" "/isolinux/grub.conf" \
    -update "/tmp/isolinux.cfg" "/isolinux/isolinux.cfg" \
    -update "/tmp/BOOT.conf" "/EFI/BOOT/BOOT.conf" \
    -update "/tmp/grub.cfg" "/EFI/BOOT/grub.cfg" \
    -boot_image any replay
    
    echo "> Removing modified squashfs image..."
    sudo rm -f "${SQUASHFS_IMG_MODIFIED}"
}

function flash() {
    echo "> Flashing ISO to USB drive"
    mps="$(mount | grep "$DRIVE" | cut -d' ' -f3)" # get mountpoint for device
    if [ "$mps" != "" ]; then
        echo "> $DRIVE is still mounted."
        while IFS= read -r mp; do
            echo "> Unmounting partition mounted at ${mp}..."
            sudo umount --force "$mp"
        done <<< "$mps"
    fi
    yes "" | sudo livecd-iso-to-disk --format ext4 --overlay-size-mb 4095 --efi --force --extra-kernel-args "$ALL_KERNEL_PARAMS" "${ISO_FILE_MODIFIED}" "$DRIVE"
}

if [ "$MODE" = "flash" ]; then
    if [ "$DRIVE" = "" ]; then
        echo "> [Error] Missing parameter. You have to specify the device onto which to flash the Live ISO! E.g. /dev/sda"
        exit 1
    fi
    if [ ! -f "${ISO_FILE_MODIFIED}" ]; then
        build_method_1
    fi
    flash
elif [ "$MODE" = "build" ]; then
    build_method_1
fi
