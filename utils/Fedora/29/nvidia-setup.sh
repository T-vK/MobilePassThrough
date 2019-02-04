#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
PROJECT_DIR="${SCRIPT_DIR}/../../.."
UTILS_DIR="${PROJECT_DIR}/utils"
DISTRO=$("${UTILS_DIR}/distro-info")
DISTRO_UTILS_DIR="${UTILS_DIR}/${DISTRO}"
VM_FILES_DIR="${PROJECT_DIR}/vm-files"

echo "Install third party repositories"
sudo dnf install fedora-workstation-repositories -y

echo "Install third party repositories"
sudo dnf config-manager rpmfusion-nonfree-nvidia-driver --set-enabled -y

echo "Enable the NVIDIA driver repository"
sudo dnf install akmod-nvidia acpi -y

echo "Enable the Bumblebee repository"
sudo dnf copr enable chenxiaolong/bumblebee -y

echo "Install Bumblebee"
sudo dnf install akmod-bbswitch bumblebee primus -y

echo "Make Bumblebee avialable to the current user"
sudo gpasswd -a $USER bumblebee

echo "Enable Bumblebee"
sudo systemctl enable bumblebeed

echo "Block nvidia-fallback service"
sudo systemctl mask nvidia-fallback

echo "Disable Nouveau drivers"
addKernelParam "nouveau.modeset=0"

sudo ${UTILS_DIR}/extract-vbios
