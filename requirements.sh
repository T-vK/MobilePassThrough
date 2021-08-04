#####################################################################################################
# This file is supposed to be `source`d by the `scripts/main/setup.sh` bash script.
# It specifies which executables and files and kernel parameters what part of this project depends on
# WARNING: File dependencies can't contain spaces at the moment
# Usage: `source ./requirements.txt`
#####################################################################################################

KERNEL_PARAMS_GENERAL=("iommu=1" "kvm.ignore_msrs=1" "rd.driver.pre=vfio-pci")
KERNEL_PARAMS_INTEL_CPU=("intel_iommu=on")
KERNEL_PARAMS_AMD_CPU=("amd_iommu=on")
KERNEL_PARAMS_INTEL_GPU=("i915.enable_gvt=1")
#KERNEL_PARAMS_AMD_GPU=()
#KERNEL_PARAMS_NVIDIA_GPU=()
KERNEL_PARAMS_BUMBLEBEE_NVIDIA=("nouveau.modeset=0")
#EXEC_DEPS_GENERAL=("sudo" "bash" "mv" "cp" "sed" "awk" "git" "echo" "ls" "wget" "curl" "printf" "cd" "mkdir" "chmod" "chown" "grep" "cut" "which")
EXEC_DEPS_FAKE_BATTERY=("iasl")
EXEC_DEPS_OVMF_VBIOS_PATCH=("git" "docker")
EXEC_DEPS_GENERATE_CONFIG=("crudini")
EXEC_DEPS_VBIOS_FINDER=("git" "wget" "curl" "unzip" "ruby" "gem" "bundle" "7za" "make" "innoextract" "upx")
FILE_DEPS_VBIOS_FINDER=("/usr/include/{ruby,ruby-2.7}/ruby.h")
EXEC_DEPS_VIRTUALIZATION=("qemu-system-x86_x64" "virsh" "virt-viewer" "spicy")
FILE_DEPS_VIRTUALIZATION=("OVMF/OVMF_CODE.fd" "OVMF/OVMF_VARS.fd" "virtio-win/virtio-win.iso") # TODO: get the iso using wget cuz only rhel distros have a package for that anyways
EXEC_DEPS_RDP=("remmina")
EXEC_DEPS_SAMBA=("samba")
EXEC_DEPS_IGPU_PASSTHROUGH=("uuid" "intel-virtual-output")
EXEC_DEPS_HELPER_ISO=("genisoimage")
EXEC_DEPS_UEFI_CHECK=("systool")
EXEC_DEPS_COMPATIBILITY_CHECK=("systool" "lshw" "lspci" "dmidecode" "lsusb" "lsblk" "lscpu")
EXEC_DEPS_CPU_CHECK=("lscpu")
EXEC_DEPS_GPU_CHECK=("lshw")

#############################################################################################################################

ALL_EXEC_DEPS="" # Will contain all content of all variables starting with EXEC_DEPS
ALL_EXEC_DEPS_VARS="$(set -o posix ; set | grep -P '^EXEC_DEPS' | cut -d'=' -f1 | tr '\n' ' ')"
for deps in $ALL_EXEC_DEPS_VARS; do
    ALL_EXEC_DEPS+="$(eval "echo \" \${$deps[*]}\"")"
done

ALL_FILE_DEPS="" # Will contain all content of all variables starting with FILE_DEPS
ALL_FILE_DEPS_VARS="$(set -o posix ; set | grep -P '^FILE_DEPS' | cut -d'=' -f1 | tr '\n' ' ')"
for deps in $ALL_FILE_DEPS_VARS; do
    ALL_FILE_DEPS+="$(eval "echo \" \${$deps[*]}\"")"
done