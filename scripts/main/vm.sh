#!/usr/bin/env bash
while [[ "$PROJECT_DIR" != */MobilePassThrough ]]; do PROJECT_DIR="$(readlink -f "$(dirname "${PROJECT_DIR:-0}")")"; done
source "$PROJECT_DIR/scripts/utils/common/libs/helpers"
loadConfig

#####################################################################################################
# This script can create a VM and install Windows in i,t if called like this: `./vm.sh install`
# or start the previously created Windows VM, if called like this: `./vm.sh`
#####################################################################################################

ORIGINAL_VM_ACTION="$1"
VM_ACTION="$ORIGINAL_VM_ACTION"
if [ "$VM_ACTION" != "auto" ]; then
    echo "> Action: $VM_ACTION"
fi

if [ "$VM_ACTION" = "install" ]; then
    VM_ACTION="install"
elif [ "$VM_ACTION" = "start" ]; then
    VM_ACTION="start"
elif [ "$VM_ACTION" = "stop" ]; then
    if [ "$VM_START_MODE" = "virt-install" ]; then
        sudo virsh destroy --domain "${VM_NAME}"
    elif [ "$VM_START_MODE" = "qemu" ]; then
        sudo killall -9 qemu-system-x86_64 &> /dev/null
    fi
elif [ "$VM_ACTION" = "auto" ]; then
    if sudo fdisk -lu "${DRIVE_IMG}" 2> /dev/null | grep --quiet 'Microsoft'; then
        VM_ACTION="start"
    else
        VM_ACTION="install"
    fi
    echo "> Action: $VM_ACTION"
elif [ "$VM_ACTION" = "remove" ]; then
    if [ "$VM_START_MODE" = "virt-install" ]; then
        sudo virsh destroy --domain "${VM_NAME}"
        sudo virsh undefine --domain "${VM_NAME}" --nvram
    elif [ "$VM_START_MODE" = "qemu" ]; then
        sudo killall -9 qemu-system-x86_64 &> /dev/null
    fi
    if [[ ${DRIVE_IMG} == *.img ]]; then
        sudo rm -f "${DRIVE_IMG}"
    fi
    rm -f "${OVMF_VARS_VM}"
    exit
else
    echo "> Error: No valid vm.sh parameter was found!"
    exit 1
fi

echo "> Start mode: $VM_START_MODE"

GET_XML=false
DRY_RUN=false
if [ "$VM_ACTION" = "install" ] || [ "$VM_ACTION" = "start" ]; then
    if [ "$2" = "dry-run" ]; then
        DRY_RUN=true
    elif [ "$2" = "get-xml" ]; then
        GET_XML=true
        echo "> Enforcing VM start mode 'virt-install' to generate the XML..."
        VM_START_MODE="virt-install"
    fi
fi

# Remove domain from PCI addressed if provided
DGPU_PCI_ADDRESS="$(echo "$DGPU_PCI_ADDRESS" | sed 's/0000://g')"
IGPU_PCI_ADDRESS="$(echo "$IGPU_PCI_ADDRESS" | sed 's/0000://g')"

#source "$COMMON_UTILS_LIBS_DIR/gpu-check"
alias driver="sudo '$COMMON_UTILS_TOOLS_DIR/driver-util'"
alias vgpu="sudo '$COMMON_UTILS_TOOLS_DIR/vgpu-util'"
alias lsiommu="sudo '$COMMON_UTILS_TOOLS_DIR/lsiommu'"

VIRT_INSTALL_PARAMS=()
QEMU_PARAMS=()

#####################################################################################
############################## Set basic VM parameters ##############################
#####################################################################################
function setMiscParams() {
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
        QEMU_PARAMS+=("-mem-prealloc") # for virt-install this enabled by default
    fi

    QEMU_PARAMS+=("-rtc" "clock=host,base=localtime")
    QEMU_PARAMS+=("-nographic")
    QEMU_PARAMS+=("-serial" "none")
    QEMU_PARAMS+=("-parallel" "none")
    QEMU_PARAMS+=("-boot" "menu=on")
    QEMU_PARAMS+=("-boot" "once=d")
    QEMU_PARAMS+=("-k" "en-us")

    QEMU_PARAMS+=("-device" "ich9-intel-hda")
    QEMU_PARAMS+=("-device" "hda-output")
    QEMU_PARAMS+=("-device" "pci-bridge,addr=12.0,chassis_nr=2,id=head.2")
    # More parameters are added throughout the whole script

    VIRT_INSTALL_PARAMS+=("--virt-type" "kvm")
    VIRT_INSTALL_PARAMS+=("--os-variant" "win10")
    VIRT_INSTALL_PARAMS+=("--arch=x86_64")
}

#####################################################################################
################################# Set up networking #################################
#####################################################################################
function setUpNetworking() {
    if [ "$NETWORK_MODE" == "bridged" ]; then
        echo "> Using network mode ${NETWORK_MODE}..."
        if ! sudo virsh net-list | grep default | grep --quiet active; then
            sudo virsh net-start default
        fi

        if [ "$MAC_ADDRESS" = "auto" ]; then
            MAC_ADDRESS=$(printf '52:54:BE:EF:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)))
        fi
        echo "> Using MAC address: ${MAC_ADDRESS}..."

        INTERFACE_NAME="$(sudo cat /var/lib/libvirt/dnsmasq/default.conf | grep "^interface=" | cut -d'=' -f2-)"
        NETWORK="$(sudo ip route | grep " ${INTERFACE_NAME} " | cut -d' ' -f1)"

        if [ "$VM_START_MODE" = "qemu" ]; then
            QEMU_PARAMS+=("-net" "nic,model=e1000,macaddr=${MAC_ADDRESS}" "-net" "bridge,br=virbr0")
            #QEMU_PARAMS+=("-netdev" "type=tap,id=net0,ifname=tap0,script=${VM_FILES_DIR}/network-scripts/tap_ifup,downscript=${VM_FILES_DIR}/network-scripts/tap_ifdown,vhost=on")
            #QEMU_PARAMS+=("-device" "virtio-net-pci,netdev=net0,addr=19.0,mac=${MAC_ADDRESS}")
            #-net user,hostfwd=tcp::13389-:3389 -net nic
        elif [ "$VM_START_MODE" = "virt-install" ]; then
            VIRT_INSTALL_PARAMS+=("--network" "network=default,model=e1000,mac=${MAC_ADDRESS}")
            #VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./devices/interface[type=network]/mac@address='${MAC_ADDRESS}'")
            #VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./devices/interface[0]/source@network=default")
            #if ! sudo virsh net-list | grep default | grep --quiet active; then
            #    sudo virsh net-start default
            #fi
        fi
    else
        echo "Networking will not be enabled for this VM..."
    fi
}

#####################################################################################
################################### Set CPU Cores ###################################
#####################################################################################
function setCpuCores() {
    if [ "$CPU_CORE_COUNT" = "auto" ]; then
        AVAILABLE_CPU_CORE_COUNT="$(nproc)"
        CPU_CORE_COUNT="$((AVAILABLE_CPU_CORE_COUNT-1))"
        if [[ $CPU_CORE_COUNT -gt 16 ]]; then
            CPU_CORE_COUNT=16
        fi
    fi
    echo "> Using ${CPU_CORE_COUNT} CPU cores..."
    if [ "$VM_START_MODE" = "qemu" ]; then
        QEMU_PARAMS+=("-smp" "${CPU_CORE_COUNT}")
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        VIRT_INSTALL_PARAMS+=("--vcpu" "${CPU_CORE_COUNT}")
    fi
}

#####################################################################################
################################### Set RAM size ####################################
#####################################################################################
function setRamSize() {
    if [ "$RAM_SIZE" = "auto" ]; then
        FREE_RAM="$(free -g | grep 'Mem: ' | tr -s ' ' | cut -d ' ' -f7)"
        RAM_SIZE_GB="$((FREE_RAM-1))"
        if [[ $RAM_SIZE_GB -gt 16 ]]; then
            RAM_SIZE_GB=16
        fi
        RAM_SIZE="${RAM_SIZE_GB}G"
    fi
    echo "> Using ${RAM_SIZE} of RAM..."
    if [ "$VM_START_MODE" = "qemu" ]; then
        QEMU_PARAMS+=("-m" "${RAM_SIZE}")
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        RAM_SIZE_GB="$(numfmt --from=si "${RAM_SIZE}" --to-unit=1M)"
        VIRT_INSTALL_PARAMS+=("--memory" "${RAM_SIZE_GB}")
    fi
}

#####################################################################################
############################## Set install media (ISO) ##############################
#####################################################################################
function setInstallMediaParam() {
    if [ "$VM_ACTION" = "install" ]; then
        if [ "$VM_START_MODE" = "qemu" ]; then
            QEMU_PARAMS+=("-drive" "file=${INSTALL_IMG},index=1,media=cdrom")
        elif [ "$VM_START_MODE" = "virt-install" ]; then
            VIRT_INSTALL_PARAMS+=("--cdrom" "${INSTALL_IMG}")
        fi
    fi
}

#####################################################################################
################################## Set helper ISO ###################################
#####################################################################################
function setHelperIsoParam() {
    if [ "$VM_START_MODE" = "qemu" ]; then
        QEMU_PARAMS+=("-drive" "file=${HELPER_ISO},index=2,media=cdrom")
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        VIRT_INSTALL_PARAMS+=("--disk" "device=cdrom,path=${HELPER_ISO}")
    fi
}

#####################################################################################
########################### Set/create OS install drive #############################
#####################################################################################
function setUpOsDrive() {
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
        if [ "$VM_ACTION" = "install" ] && [ -f "${DRIVE_IMG}" ]; then
            echo "> Removing old virtual disk..."
            sudo rm -rf "${DRIVE_IMG}"
        fi
        if [ ! -f "${DRIVE_IMG}" ]; then
            echo "> Creating a virtual disk for the VM..."
            qemu-img create -f raw "${DRIVE_IMG}" "${VM_DISK_SIZE}" > /dev/null
            sudo chown "$(whoami):$(id -gn "$(whoami)")" "${DRIVE_IMG}"
        fi
        if [ "$VM_START_MODE" = "qemu" ]; then
            QEMU_PARAMS+=("-drive" "id=disk0,if=virtio,cache.direct=on,if=virtio,aio=native,format=raw,file=${DRIVE_IMG}")
        elif [ "$VM_START_MODE" = "virt-install" ]; then
            VIRT_INSTALL_PARAMS+=("--disk" "${DRIVE_IMG}")
        fi
        OS_DRIVE_SIZE="$(sudo ls -l --b=G "${DRIVE_IMG}" | cut -d " " -f5)"
        echo "> Virtual OS drive has ${OS_DRIVE_SIZE} of storage."
    else
        echo "> Error: It appears that no proper OS drive (image) has been provided. Check your 'DRIVE_IMG' var: '${DRIVE_IMG}'"
        exit
    fi
}

#####################################################################################
################ Figure out if optirun or DRI_PRIME should be used ##################
#####################################################################################
function bumblebeeCheck() {
    if sudo which optirun &> /dev/null && sudo optirun echo > /dev/null ; then
        OPTIRUN_PREFIX="optirun "
        DRI_PRIME_PREFIX=""
        echo "> Bumblebee works fine on this system. Using optirun when necessary..."
    else
        OPTIRUN_PREFIX=""
        if [ "$SUPPORTS_DRI_PRIME" = true ]; then
            DRI_PRIME_PREFIX="DRI_PRIME=1 "
        else
            echo "> Bumblebee is not available..."
        fi
    fi
}

#####################################################################################
########################## Set up samba share directory #############################
#####################################################################################
function setUpSambaShare() {
    if [ -z "$SMB_SHARE_FOLDER" ]; then
        echo "> Not using SMB share..."
    else
        echo "> Using SMB share..."
        QEMU_PARAMS+=("-net" "user,smb=${SMB_SHARE_FOLDER}")
    fi
}

#####################################################################################
####################### Set parameters for dGPU passthrough #########################
#####################################################################################
function setDGpuParams() {
    if [ "$DGPU_PASSTHROUGH" != false ]; then
        DGPU_PASSTHROUGH=false
        availableGpusIds="$(sudo ${OPTIRUN_PREFIX}lshw -C display -businfo | grep 'pci@' | cut -d'@' -f2 | cut -d' ' -f1 | cut -d':' -f2-)"
        if [ "$DGPU_PCI_ADDRESS" = "auto" ]; then
            DGPU_PCI_ADDRESS=""
            while IFS= read -r pciAddress; do
                gpuInfo="$(sudo ${OPTIRUN_PREFIX}lspci -s "$pciAddress")"
                if [[ "$gpuInfo" != *"Intel"* ]]; then
                    DGPU_PCI_ADDRESS="$pciAddress"
                    break
                fi
            done <<< "$availableGpusIds"
        fi

        if [ "$(echo -e "$availableGpusIds" | wc -l)" -le 1 ]; then
            echo "> Not using dGPU passthrough because single GPU passthrough is not supported yet..."
        elif [ "$DGPU_PCI_ADDRESS" != "" ]; then
            DGPU_PASSTHROUGH=true
            echo "> Using dGPU passthrough..."

            if [ "$HOST_DGPU_DRIVER" = "auto" ]; then
                HOST_DGPU_DRIVER="$(sudo ${OPTIRUN_PREFIX}lspci -s "$DGPU_PCI_ADDRESS" -vv | grep driver | cut -d':' -f2 | cut -d' ' -f2-)"
            fi

            DGPU_INFO="$(sudo lspci | grep "$DGPU_PCI_ADDRESS" | cut -d' ' -f2-)"
            echo "> dGPU is: $DGPU_INFO"
            echo "> dGPU driver is $HOST_DGPU_DRIVER"
            
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
                exit 1
            fi

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
    else
        echo "> Not using dGPU passthrough..."
    fi
}

##############################################################################################
### If mediated iGPU passthrough is enabled, check if vGPU exists or if one can be created ###
##############################################################################################
function vGpuSetup() {
    DMA_BUF_AVAILABLE=false
    if [ "$SHARE_IGPU" = true ] || [ "$SHARE_IGPU" = "auto" ]; then

        if [ "$IGPU_PCI_ADDRESS" = "auto" ]; then
            IGPU_PCI_ADDRESS=""
            availableGpusIds="$(sudo ${OPTIRUN_PREFIX}lshw -C display -businfo | grep 'pci@' | cut -d'@' -f2 | cut -d' ' -f1 | cut -d':' -f2-)"

            while IFS= read -r pciAddress; do
                gpuInfo="$(sudo ${OPTIRUN_PREFIX}lspci -s "$pciAddress")"
                if [[ "$gpuInfo" == *"Intel"* ]]; then
                    IGPU_PCI_ADDRESS="$pciAddress"
                    break
                fi
            done <<< "$availableGpusIds"
        fi
        
        if [ "$IGPU_PCI_ADDRESS" != "" ]; then
            vgpu init # load required kernel modules

            # FIXME: There is a bug in Linux that prevents creating new vGPUs without rebooting after removing one. 
            #        So for now we can't create a new vGPU every time the VM starts.
            #vgpu remove "${IGPU_PCI_ADDRESS}" &> /dev/null # Ensure there are no vGPUs before creating a new one
            VGPU_UUID="$(vgpu get "${IGPU_PCI_ADDRESS}" | head -1)"
            if [ "$VGPU_UUID" == "" ]; then
                echo "> Creating a vGPU for mediated iGPU passthrough..."
                VGPU_UUID="$(vgpu create "${IGPU_PCI_ADDRESS}")"
                if [ "$?" = "1" ]; then
                    echo "> [Error] Failed creating a vGPU. (You can try again. If you still get this error, you have to reboot. This seems to be a bug in Linux.)"
                    echo "> Continuing without mediated iGPU passthrough..."
                    VGPU_UUID=""
                fi
            fi

            if [ "$VGPU_UUID" != "" ]; then
                IGPU_INFO="$(sudo lspci | grep "$IGPU_PCI_ADDRESS" | cut -d' ' -f2-)"
                echo "> iGPU is: $IGPU_INFO"
                echo "> iGPU dirver is: $HOST_DGPU_DRIVER"
                echo "> UUID of vGPU is: $VGPU_UUID"
                DMA_BUF_AVAILABLE=true
            fi
        else
            echo "> No iGPU found. - Not using mediated iGPU passthrough..."
        fi
    else
        echo "> Not using mediated iGPU passthrough..."
    fi
}

#####################################################################################
############################ Load display output plugin #############################
#####################################################################################
function loadDisplayOutputPlugin() {
    if [ "$DISPLAY_MODE" != "" ]; then
        echo "> Loading display-mode-${DISPLAY_MODE} plugin..."
        source "${COMMON_UTILS_PLUGINS_DIR}/display-mode-${DISPLAY_MODE}"
    else
        echo "> [Error] No display mode provided..."
    fi
}

#########################################################################################################
### If there is a vGPU for mediated iGPU passthrough, set parameters for iGPU passthrough and dma-buf ###
#########################################################################################################
function setIGpuParams() {
    if [ "$VGPU_UUID" != "" ]; then
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
                echo "> Not using iGPU vBIOS override..."
                #IGPU_ROM_PARAM=",rom.bar=on"
            else
                echo "> Using iGPU vBIOS override..."
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
                echo "> Not using iGPU vBIOS override..."
                IGPU_ROM_PARAM=",rom.bar=on"
            fi
            VIRT_INSTALL_PARAMS+=("--hostdev" "type=mdev,alias.name=hostdev1,address.domain=0000,address.bus=0,address.slot=2,address.function=0,address.type=pci,address.multifunction=on${IGPU_ROM_PARAM}")
            VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./devices/hostdev[2]/@model=vfio-pci")
            VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./devices/hostdev[2]/source/address/@uuid=${VGPU_UUID}")
            
            if [ ! -z "$IGPU_ROM" ]; then
                echo "> Using iGPU vBIOS override..."
                VIRT_INSTALL_PARAMS+=("--xml" "xpath.set=./devices/hostdev[2]/rom/@file=${IGPU_ROM}")
            fi
        fi
    fi
}

#####################################################################################
############################### Set Spice parameters ################################
#####################################################################################
function setSpiceParams() {
    if [ "$USE_SPICE" = true ]; then
        if sudo lsof -i ":${SPICE_PORT}" | grep --quiet LISTEN; then
            echo "[Error] Something is blocking the SPICE_PORT (${SPICE_PORT})! Change it in your config or kill whatever is blocking it."
        else
            echo "> Using spice on port ${SPICE_PORT}..."
            #QEMU_PARAMS+=("-spice" "port=${SPICE_PORT},addr=127.0.0.1,disable-ticketing") #Spice
            if [ "$VM_START_MODE" = "qemu" ]; then
                QEMU_PARAMS+=("-spice" "port=${SPICE_PORT},addr=127.0.0.1,disable-ticketing") #Spice
            elif [ "$VM_START_MODE" = "virt-install" ]; then
                VIRT_INSTALL_PARAMS+=("--channel" "spicevmc,target.address=127.0.0.1:${SPICE_PORT}")
                #VIRT_INSTALL_PARAMS+=("--graphics" "spice,port=${SPICE_PORT}")
            fi
        fi
        function waitForSpice() {
            while true; do
                if sudo lsof -i ":${SPICE_PORT}" | grep --quiet LISTEN &> /dev/null; then
                    break
                fi
                sleep 1
            done
        }
    else
        echo "> Not using Spice..."
    fi
}

#####################################################################################
###################### Check if spice client should be started ######################
#####################################################################################
function spiceClientCheck() {
    if [ "$USE_SPICE_CLIENT" = "auto"  ] && [ "$USE_SPICE" = true ]; then
        if [ "$VM_ACTION" = "install" ]; then
            USE_SPICE_CLIENT=true
        elif [ "$USE_LOOKING_GLASS" = true ]; then
            USE_SPICE_CLIENT=true
        fi
    fi
}

#####################################################################################
############ Set QXL parameters if loaded display output plugin wants it ############
#####################################################################################
function setQxl() {
    if [ "$USE_QXL" = true ]; then
        echo "> Using QXL..."
        if [ "$VM_START_MODE" = "qemu" ]; then
            QEMU_PARAMS+=("-device" "qxl,bus=pcie.0,addr=1c.4,id=video.2")
            #QEMU_PARAMS+=("-vga" "qxl")
        elif [ "$VM_START_MODE" = "virt-install" ]; then
            VIRT_INSTALL_PARAMS+=("--video" "qxl")
            #-video qxl --channel spicevmc
        fi
    else
        echo "> Not using QXL..."
    fi
}

#####################################################################################
####### Set Looking Glass parameters if loaded display output plugin wants it #######
#####################################################################################
function setUpLookingGlassParams() {
    if [ "$USE_LOOKING_GLASS" = true ]; then
        echo "> Using Looking Glass..."
        echo "> Calculating required buffer size for ${LOOKING_GLASS_MAX_SCREEN_WIDTH}x${LOOKING_GLASS_MAX_SCREEN_HEIGHT} for Looking Glass..."
        UNROUNDED_BUFFER_SIZE=$((($LOOKING_GLASS_MAX_SCREEN_WIDTH * $LOOKING_GLASS_MAX_SCREEN_HEIGHT * 4 * 2)/1024/1024+10))
        BUFFER_SIZE=1
        while [[ $BUFFER_SIZE -le $UNROUNDED_BUFFER_SIZE ]]; do
            BUFFER_SIZE=$(($BUFFER_SIZE*2))
        done
        LOOKING_GLASS_BUFFER_SIZE="${BUFFER_SIZE}"
        echo "> Looking Glass buffer size set to: ${LOOKING_GLASS_BUFFER_SIZE}MB"
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
}
function autoConnectLookingGlass() {
    while true; do 
        VM_IP="$(sudo nmap -sn -n ${NETWORK} -T5 | grep "MAC Address: ${MAC_ADDRESS}" -B 2 | head -1 | rev | cut -d' ' -f1 | rev)"
        if [ "$VM_IP" != "" ]; then
            while true; do
                if nc -vz "$VM_IP" 3389 &> /dev/null; then
                    sleep 5
                    echo "> [Background task] Starting the Looking Glass client to connect with the VM..."
                    sudo -u "$(logname)" "${THIRDPARTY_DIR}/LookingGlass/client/build/looking-glass-client" -p "${SPICE_PORT}" 2>&1 | grep '^\[E\]' &
                    break
                fi
                sleep 1
            done
            break
        fi
        sleep 1
    done
}

#####################################################################################
########################## Set up fake battery if enabled ###########################
#####################################################################################
setUpFakeBattery() {
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
}

#####################################################################################
########### Create copy of OVMF_VARS_VM which is required for UEFI VMs  #############
#####################################################################################
function createOvmfVarsCopy() {
    if [ ! -f "${OVMF_VARS_VM}" ] || [ "$VM_ACTION" = "install" ]; then
        echo "> Creating fresh OVMF_VARS copy for this VM..."
        sudo rm -f "${OVMF_VARS_VM}"
        sudo cp "${OVMF_VARS}" "${OVMF_VARS_VM}"
        sudo chown "$(whoami):$(id -gn "$(whoami)")" "${OVMF_VARS_VM}"
    fi
}

#####################################################################################
####################### Patch OVMF with vBIOS ROM if enabled ########################
#####################################################################################
function patchOvmf() {
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
            if [ "$VM_ACTION" = "install" ]; then
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
}

#####################################################################################
############################### Set OVMF parameters #################################
#####################################################################################
function setOvmfParams() {
    if [ "$VM_START_MODE" = "qemu" ]; then
        QEMU_PARAMS+=("-drive" "if=pflash,format=raw,readonly=on,file=${OVMF_CODE}")
        QEMU_PARAMS+=("-drive" "if=pflash,format=raw,file=${OVMF_VARS_VM}")
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        VIRT_INSTALL_PARAMS+=("--boot" "loader=${OVMF_CODE},loader.readonly=yes,loader.type=pflash,nvram.template=${OVMF_VARS_VM},loader_secure=no")
    fi
}

#####################################################################################
########################## Set up USB device passthrough ############################
#####################################################################################
function setUpUsbPassthrough() {
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
}

#####################################################################################
############################### Set up input method #################################
#####################################################################################
function setUpInputMethod() {
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
}

#####################################################################################
################################### Set up RDP ######################################
#####################################################################################
function setUpRdp() {
    if [ "$USE_RDP" = true ] && [ "$NETWORK_MODE" != "none" ]; then
        echo "> Using RDP..."
        RDP_USER=Administrator
        RDP_PASSWORD=admin
        # Run it once because the first time it prints a useless message instead of actually encrypting
        echo "$RDP_PASSWORD" | remmina --encrypt-password &> /dev/null
        # Run it again, hoping it always works the second time
        RDP_PASSWORD_ENCRYPTED="$(echo "$RDP_PASSWORD" | remmina --encrypt-password 2>&1 | grep 'Encrypted password: ' | cut -d':' -f2- | tr -d ' ')"

        function autoConnectRdp() {
            while true; do 
                VM_IP="$(sudo nmap -sn -n ${NETWORK} -T5 | grep "MAC Address: ${MAC_ADDRESS}" -B 2 | head -1 | rev | cut -d' ' -f1 | rev)"
                if [ "$VM_IP" != "" ]; then
                    echo ""
                    echo "> [Background task] The IP address of the VM is: ${VM_IP}"
                    echo "> [Background task] Waiting for RDP to be available in the VM..."
                    while true; do
                        if nc -vz "$VM_IP" 3389 &> /dev/null; then
                            echo "> [Background task] Opening Remmina to start an RDP connection with the VM..."
                            remmina -c "rdp://${RDP_USER}:${RDP_PASSWORD_ENCRYPTED}@${VM_IP}" &> /dev/null &
                            break
                        fi
                        sleep 1
                    done
                    break
                fi
                sleep 1
            done
        }
    else
        echo "> Not using RDP..."
    fi
}

#####################################################################################
################# Load vfio-pci and bind dGPU to vfio-pci driver ####################
#####################################################################################
function vfioPci() {
    if [ "$DRY_RUN" = false ]; then
        if [ "$DGPU_PASSTHROUGH" = true ] || [ "$SHARE_IGPU" = true ]; then
            echo "> Loading vfio-pci kernel module..."
            sudo modprobe vfio
            sudo modprobe vfio_pci
            sudo modprobe vfio_iommu_type1
        fi

        if [ "$DGPU_PASSTHROUGH" = true ]; then
            #echo "> Unbinding dGPU from ${HOST_DGPU_DRIVER} driver..."
            #driver unbind 
            #echo "> Binding dGPU to VFIO driver..."
            #driver bind "${DGPU_PCI_ADDRESS}" "vfio-pci"
            
            IOMMU_GROUP="$(echo "$LSIOMMU_OUTPUT" | grep "${DGPU_PCI_ADDRESS}" | cut -d' ' -f3)"
            echo "> IOMMU group for passthrough is ${IOMMU_GROUP}"

            LSPCI_OUTPUT="$(sudo lspci)"
            LSIOMMU_OUTPUT="$(lsiommu)"
            IOMMU_GROUP="$(echo "$LSIOMMU_OUTPUT" | grep "${DGPU_PCI_ADDRESS}" | cut -d' ' -f3)"
            DGPU_IOMMU_GROUP_DEVICES=$(echo "$LSIOMMU_OUTPUT" | grep "IOMMU Group ${IOMMU_GROUP} " | grep -v "PCI bridge" | grep -v "ISA bridge")
            DGPU_FUNCTION_DEVICES=$(echo "$LSIOMMU_OUTPUT" | grep " ${DGPU_PCI_ADDRESS::-1}" | grep -v "PCI bridge" | grep -v "ISA bridge" | grep -v "${DGPU_PCI_ADDRESS}" | grep -v ^$)
            DEVICES_TO_REBIND="$(echo -e "${DGPU_IOMMU_GROUP_DEVICES}\n${DGPU_FUNCTION_DEVICES}" | sort | uniq | grep -v ^$)"
            while IFS= read -r deviceInfo; do
                deviceName="$(echo "$deviceInfo" | cut -d ' ' -f4-)"
                deviceAddress="$(echo "$deviceInfo" | cut -d ' ' -f4)"
                echo "> Unbinding device '${deviceName}' from its driver, then bind it to the vfio-pci driver..."
                sudo driverctl --nosave set-override "0000:${deviceAddress}" vfio-pci
            done <<< "$DEVICES_TO_REBIND"
            
            while IFS= read -r deviceInfo; do
                if [ "${deviceInfo}" != "" ]; then
                    deviceAddress="$(echo "$deviceInfo" | cut -d ' ' -f4)"
                    QEMU_PARAMS+=("-device" "vfio-pci,host=${deviceAddress}")
                fi
            done <<< "$DGPU_FUNCTION_DEVICES"

            #sudo bash -c "echo 'options vfio-pci ids=${DGPU_VENDOR_ID}:${DGPU_DEVICE_ID}' > '/etc/modprobe.d/vfio.conf'"
            # TODO: Make sure to also do the rebind for the other devices that are in the same iommu group (exclude stuff like PCI Bridge root ports that don't have vfio drivers)
        fi
    fi
}

#####################################################################################
############ Clean up before creating a new VM when action is install ###############
#####################################################################################
function preCleanUp() {
    if [ "$VM_ACTION" = "install" ]; then
        echo "> Deleting VM if it already exists..."
        sudo virsh destroy --domain "${VM_NAME}" &> /dev/null
        sudo virsh undefine --domain "${VM_NAME}" --nvram &> /dev/null
    fi
}

#####################################################################################
########################## Start a few background tasks #############################
#####################################################################################
function startBackgroundTasks() {
    if [ "$VM_START_MODE" = "qemu" ]; then
        if [ "$DRY_RUN" = false ]; then
            if [ "$VM_ACTION" = "install" ]; then
                echo "> Repeatedly sending keystrokes to the new VM for 30 seconds to ensure the Windows ISO boots..."
                QEMU_PARAMS+=("-monitor" "unix:/tmp/${VM_NAME}-monitor,server,nowait")
                bash -c "for i in {1..30}; do echo 'sendkey home' | sudo socat - 'UNIX-CONNECT:/tmp/${VM_NAME}-monitor'; sleep 1; done" &> /dev/null &
            fi

            if [ "$USE_SPICE_CLIENT" = true ]; then
                echo "> [Background task] Starting the spice client at localhost:${SPICE_PORT}..."
                bash -c "sleep 2; spicy -h localhost -p ${SPICE_PORT}" &> /dev/null &
            fi
        fi
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        if [ "$DRY_RUN" = false ]; then
            if [ "$VM_ACTION" = "install" ]; then
                echo "> Repeatedly sending keystrokes to the new VM for 30 seconds to ensure the Windows ISO boots..."
                bash -c "for i in {1..30}; do sudo virsh send-key ${VM_NAME} KEY_HOME; sleep 1; done" &> /dev/null &
            fi
        fi
    fi
    if [ "$USE_RDP" = true ] && [ "$NETWORK_MODE" != "none" ]; then
        echo "> [Background task] Starting RDP autoconnect..."
        autoConnectRdp &
    fi
    if [ "$USE_LOOKING_GLASS" = true ]; then
        echo "> [Background task] Starting the Looking Glass client..."
        #while true; do sleep 1 && echo "lg" && sudo lsof -i ":${SPICE_PORT}" | grep --quiet LISTEN &> /dev/null && sleep 5 && sudo -u "$(logname)" "${THIRDPARTY_DIR}/LookingGlass/client/build/looking-glass-client" -p "${SPICE_PORT}" 2>&1 | grep '^\[E\]'; done &
        autoConnectLookingGlass &
    fi
}

#####################################################################################
################################## Start the VM #####################################
#####################################################################################
function startVm() {
    if [ "$VM_START_MODE" = "qemu" ]; then
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
            echo "> Starting the Virtual Machine using qemu..."
            sudo qemu-system-x86_64 "${QEMU_PARAMS[@]}"
        fi
    elif [ "$VM_START_MODE" = "virt-install" ]; then
        #VIRT_INSTALL_PARAMS+=("--debug")
        for param in "${QEMU_PARAMS[@]}"; do
            VIRT_INSTALL_PARAMS+=("--qemu-commandline='${param}'")
        done

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
        elif [ "$VM_ACTION" = "install" ]; then
            echo "> Starting the Virtual Machine using virt-install..."
            sudo virt-install "${VIRT_INSTALL_PARAMS[@]}"
        elif [ "$VM_ACTION" = "start" ]; then
            echo "> Starting the Virtual Machine using virsh..."
            sudo virsh start "${VM_NAME}"
        fi
    fi
}

#####################################################################################
############### The function below gets executed when the vm exits ##################
#####################################################################################
function onExit() {
    echo "Cleaning up..."
    if [ "$DGPU_PASSTHROUGH" = true ]; then
        #echo "> Unbinding dGPU from vfio driver..."
        #driver unbind "${DGPU_PCI_ADDRESS}"
        #if [ "$HOST_DGPU_DRIVER" = "nvidia" ] || [ "$HOST_DGPU_DRIVER" = "nouveau" ]; then
        #    echo "> Turn the dGPU off using bumblebee..."
        #    sudo bash -c "echo 'OFF' >> /proc/acpi/bbswitch"
        #fi
        #echo "> Binding dGPU back to ${HOST_DGPU_DRIVER} driver..."
        #driver bind "${DGPU_PCI_ADDRESS}" "${HOST_DGPU_DRIVER}"
        while IFS= read -r deviceInfo; do
            deviceName="$(echo "$deviceInfo" | cut -d ' ' -f4-)"
            deviceAddress="$(echo "$deviceInfo" | cut -d ' ' -f4)"
            echo "> Unbinding device '${deviceName} from the vfio-pci driver, then bind it back to its original driver..."
            sudo driverctl --nosave unset-override "0000:${deviceAddress}"
        done <<< "$DGPU_IOMMU_GROUP_DEVICES"
    fi

    if [ "$VGPU_UUID" != "" ]; then
        echo "> Keeping Intel vGPU for next VM start..."

        # FIXME: There is a bug in Linux that prevents creating new vGPUs without rebooting after removing one. 
        #        So for now we can't create a new vGPU every time the VM starts.
        #echo "> Remove Intel vGPU..."
        #vgpu remove "${IGPU_PCI_ADDRESS}" "${VGPU_UUID}"

    fi

    if [ "$VM_ACTION" = "install" ]; then
        if sudo fdisk -lu "${DRIVE_IMG}" 2> /dev/null | grep --quiet 'Microsoft'; then
            if [ "$ORIGINAL_VM_ACTION" = "auto" ]; then
                sudo "${MAIN_SCRIPTS_DIR}/vm.sh" start
            fi
            exit 0
        else
            echo "> [Error] Seems like the installation failed..."
            exit 1
        fi
    fi
    
    stty sane
    kill $(jobs -p) &> /dev/null
    stty sane
}


setMiscParams
setUpNetworking
setCpuCores
setRamSize
setInstallMediaParam
setHelperIsoParam
setUpOsDrive
bumblebeeCheck
setUpSambaShare
setDGpuParams
vGpuSetup
loadDisplayOutputPlugin
setIGpuParams
setSpiceParams
spiceClientCheck
setQxl
setUpLookingGlassParams
setUpFakeBattery
createOvmfVarsCopy
patchOvmf
setOvmfParams
setUpUsbPassthrough
setUpInputMethod
setUpRdp
trap onExit EXIT
vfioPci
preCleanUp
startBackgroundTasks
startVm
