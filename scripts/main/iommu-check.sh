#!/usr/bin/env bash
while [[ "$PROJECT_DIR" != */MobilePassThrough ]]; do PROJECT_DIR="$(readlink -f "$(dirname "${PROJECT_DIR:-0}")")"; done
source "$PROJECT_DIR/scripts/utils/common/libs/helpers"

#####################################################################################################
# This script checks if virtualization and IOMMU are enabled in the UEFI and kernel. 
# Exits with 0 in case of success; Exits with 1 if it's not fully enabled.
# Will print helpful output telling you what is working and what is not.
#####################################################################################################

if sudo which optirun &> /dev/null && sudo optirun echo>/dev/null ; then
    OPTIRUN_PREFIX="optirun "
else
    OPTIRUN_PREFIX=""
fi

IOMMU_GROUPS=$(sudo ${OPTIRUN_PREFIX}${COMMON_UTILS_TOOLS_DIR}/lsiommu)

# Check if UEFI is configured correctly
if systool -m kvm_intel -v &> /dev/null || systool -m kvm_amd -v &> /dev/null ; then
    UEFI_VIRTUALIZATION_ENABLED=true
    echo "[OK] VT-X / AMD-V virtualization is enabled in the UEFI."
else
    UEFI_VIRTUALIZATION_ENABLED=false
    echo "[Error] VT-X / AMD-V virtualization is not enabled in the UEFI! This is required to run virtual machines!"
fi

if [ "$IOMMU_GROUPS" != "" ] ; then
    UEFI_IOMMU_ENABLED=true
    echo "[OK] VT-D / IOMMU is enabled in the UEFI."
else
    UEFI_IOMMU_ENABLED=false
    echo "[Error] VT-D / IOMMU is not enabled in the UEFI! This is required to check which devices are in which IOMMU group and to use GPU passthrough!"
fi

if [ $UEFI_VIRTUALIZATION_ENABLED = true ] && [ $UEFI_IOMMU_ENABLED = true ] ; then
    exit 0 # success
else
    exit 1 # error
fi