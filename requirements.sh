#####################################################################################################
# This file is supposed to be `source`d by the `scripts/main/setup.sh` bash script.
# It specifies which executables and files and kernel parameters which part of this project depends on
# WARNING: File dependencies can't contain spaces at the moment
# Usage: `source ./requirements.txt`
#####################################################################################################

# TODO: #sudo dnf install -y msr-tools tunctl # TODO: check if these are still needed and if so what for

# TODO: check if there even is a case where is would be necessary
#INITRAMFS_DRIVERS=("vfio_virqfd" "vfio_pci" "vfio_iommu_type1" "addInitramfsDriver" "vfio") #vfio stub drivers

# Docs: https://www.kernel.org/doc/Documentation/admin-guide/kernel-parameters.txt
# More docs: https://lwn.net/Articles/252826/
# https://www.kernel.org/doc/Documentation/x86/x86_64/boot-options.txt
KERNEL_PARAMS_GENERAL=("iommu=1") # '1' is not a documented option. stop confusing me wendell! Maybe the "force" option should be used instead?
KERNEL_PARAMS_GENERAL+=("kvm.ignore_msrs=1") # prevent bluescreens when a VM does MSR reads / writes directly
KERNEL_PARAMS_GENERAL+=("rd.driver.pre=vfio-pci") # tell dracut to load vfio-pci first
#KERNEL_PARAMS_GENERAL+=("pcie_acs_override=downstream") # fix /dev/vfio/1 not found error # shouldn't be necessary
#KERNEL_PARAMS_GENERAL+=("acpi_osi=!") # may fix problems with AMI style UEFIs
#KERNEL_PARAMS_GENERAL+=("acpi_osi='Windows 2009'") # may fix problems with AMI style UEFIs
KERNEL_PARAMS_INTEL_CPU=("intel_iommu=on") # enable Intel VT-D   ;# using "intel_iommu=on,igfx_off" iGPU gets no iommu group...
#KERNEL_PARAMS_INTEL_CPU+=("915.preliminary_hw_support=1") # add skylake support; probably only necessary with older kernels
KERNEL_PARAMS_AMD_CPU=("amd_iommu=on") # 'on' is not a docuemnted option for this parameter either! This is insanely confusing!
KERNEL_PARAMS_INTEL_GPU=("i915.enable_gvt=1") # enable mediated iGPU passthrough support (GVT-g) on Intel iGPUs
#KERNEL_PARAMS_AMD_GPU=()
#KERNEL_PARAMS_NVIDIA_GPU=()
KERNEL_PARAMS_BUMBLEBEE_NVIDIA=("nouveau.modeset=0")


# TODO: check if we should use relative paths to be more distribution-gnostic
#EXEC_DEPS_GENERAL=("sudo" "bash" "mv" "cp" "sed" "awk" "git" "echo" "ls" "echo" "printf" "cd" "mkdir" "chmod" "chown" "grep" "cut" "which")
EXEC_DEPS_FAKE_BATTERY=("iasl") # acpica-tools
EXEC_DEPS_OVMF_VBIOS_PATCH=("git" "docker") # git moby-engine
EXEC_DEPS_GENERATE_CONFIG=("crudini") # crudini
EXEC_DEPS_VBIOS_FINDER=("git" "wget" "curl" "unzip" "ruby" "gem" "bundle" "7za" "make" "innoextract" "upx") # git wget curl-minimal unzip ruby rubygems rubygem-bundler p7zip make innoextract upx
FILE_DEPS_VBIOS_FINDER=("/usr/include/rub*/ruby.h") # ruby-devel
EXEC_DEPS_VIRTUALIZATION=("qemu-system-x86_64" "virsh" "virt-viewer" "spicy") # qemu-system-x86-core libvirt-client virt-viewer spice-gtk-tools
FILE_DEPS_VIRTUALIZATION=("/usr/share/OVMF/OVMF_CODE.fd" "/usr/share/OVMF/OVMF_VARS.fd") # edk2-ovmf 
FILE_DEPS_VIRTUALIZATION=("/usr/share/virtio-win/virtio-win.iso") # virtio-win # TODO: get the iso using wget cuz only rhel distros have a package for that anyways
EXEC_DEPS_RDP=("remmina") # remmina
EXEC_DEPS_SAMBA=("samba") # samba
EXEC_DEPS_IGPU_PASSTHROUGH=("uuid" "intel-virtual-output") # uuid xorg-x11-drv-intel
EXEC_DEPS_HELPER_ISO=("genisoimage") # genisoimage
EXEC_DEPS_UEFI_CHECK=("systool") # sysfsutils
EXEC_DEPS_COMPATIBILITY_CHECK=("systool" "lshw" "lspci" "dmidecode" "lsusb" "lsblk" "lscpu") # sysfsutils lshw pciutils dmidecode usbutils util-linux util-linux
EXEC_DEPS_CPU_CHECK=("lscpu") # util-linux
EXEC_DEPS_GPU_CHECK=("lshw") # lshw
EXEC_DEPS_LOOKING_GLASS=("cmake" "gcc" "wayland-scanner" "makensis" "x86_64-w64-mingw32-g++") # cmake gcc-g++ wayland-devel mingw32-nsis mingw64-gcc-c++
FILE_DEPS_LOOKING_GLASS+=("/usr/include/bfd.h" "/usr/lib64/libbfd.a" "/usr/lib64/libiberty.a") # binutils-devel
FILE_DEPS_LOOKING_GLASS+=("/usr/include/fontconfig/fontconfig.h") # fontconfig-devel
FILE_DEPS_LOOKING_GLASS+=("/usr/include/spice-1/spice/protocol.h" "/usr/include/spice-1/spice/vd_agent.h" "") # spice-protocol
FILE_DEPS_LOOKING_GLASS+=("/usr/include/X11/Xlib.h" "/usr/include/X11/Xutil.h") # libX11-devel
FILE_DEPS_LOOKING_GLASS+=("/usr/include/nettle/asn1.h" "/usr/include/nettle/sha1.h" "/usr/include/nettle/rsa.h" "/usr/include/nettle/bignum.h") # nettle-devel
FILE_DEPS_LOOKING_GLASS+=("/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml" "/usr/share/wayland-protocols/unstable/idle-inhibit/idle-inhibit-unstable-v1.xml" "/usr/share/wayland-protocols/unstable/keyboard-shortcuts-inhibit/keyboard-shortcuts-inhibit-unstable-v1.xml" "/usr/share/wayland-protocols/unstable/xdg-decoration/xdg-decoration-unstable-v1.xml") # wayland-protocols-devel
FILE_DEPS_LOOKING_GLASS+=("/usr/lib/gcc/x86_64-redhat-linux/11/include/stdatomic.h" "/usr/lib/gcc/x86_64-redhat-linux/11/include/emmintrin.h" "/usr/lib/gcc/x86_64-redhat-linux/11/include/smmintrin.h" "/usr/lib/gcc/x86_64-redhat-linux/11/include/stdarg.h" "/usr/lib/gcc/x86_64-redhat-linux/11/include/stdbool.h" "/usr/lib/gcc/x86_64-redhat-linux/11/include/stddef.h" "/usr/lib/gcc/x86_64-redhat-linux/11/include/stdint.h") # gcc
FILE_DEPS_LOOKING_GLASS+=("/usr/include/X11/extensions/scrnsaver.h") # libXScrnSaver-devel
FILE_DEPS_LOOKING_GLASS+=("/usr/include/X11/extensions/Xfixes.h") # libXfixes-devel
FILE_DEPS_LOOKING_GLASS+=("/usr/include/X11/extensions/XInput2.h") # libXi-devel
FILE_DEPS_LOOKING_GLASS+=("/usr/include/wayland-client.h" "/usr/include/wayland-cursor.h" "/usr/include/wayland-egl.h") # wayland-devel
FILE_DEPS_LOOKING_GLASS+=("/usr/include/X11/extensions/Xinerama.h") # libXinerama-devel
FILE_DEPS_LOOKING_GLASS+=("/usr/include/SDL2/SDL.h" "/usr/include/SDL2/SDL_syswm.h") # SDL2-devel (will be removed in B5 probably)
FILE_DEPS_LOOKING_GLASS+=("/usr/include/SDL2/SDL_ttf.h") # SDL2_ttf-devel (will be removed in B5 probably)
#FILE_DEPS_LOOKING_GLASS+=("/usr/share/texlive/texmf-dist/fonts/opentype/public/gnu-freefont/FreeMono.otf") # this file is not actually a dependency # texlive-gnu-freefont # TODO: check if texlive-gnu-freefont is actually a dependency

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