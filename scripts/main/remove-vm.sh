#!/usr/bin/env bash
while [[ "$PROJECT_DIR" != */MobilePassThrough ]]; do PROJECT_DIR="$(readlink -f "$(dirname "${PROJECT_DIR:-0}")")"; done
source "$PROJECT_DIR/scripts/utils/common/libs/helpers"
loadConfig

#####################################################################################################
# This script deletes the Windows VM in case it already exists. Call this script like this `./delete-vm.sh`
#####################################################################################################

sudo virsh destroy --domain "${VM_NAME}"
sudo virsh undefine --domain "${VM_NAME}" --nvram

# TODO: consider moving this to vm.sh and maybe make it usable like this:
#       vm.sh remove
#       vm.sh install
#       vm.sh start