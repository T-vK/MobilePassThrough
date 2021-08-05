# MobilePassThrough

## Introduction
The goal of this project is to make GPU passthrough on x64 notebooks/tablets as easy and accessible as possible.  
To achieve that goal I have written a collection of scripts [accessible via mbpt.sh](https://github.com/T-vK/MobilePassThrough#how-to-use-mbptsh) that:

### On the host system (Linux):

- [x] Automatically install the required dependencies
- [x] Automatically configure the kernel parameters to support GPU passthrough
- [x] Automatically install Bumblebee and the Nvidia GPU driver if required
- [x] Automatically check if and to what extend your device is compatible with GPU passthrough.
- [x] Automatically create and configure a virtual machine that is fully configured for GPU passthrough.
- [x] Automatically download the Windows 10 installation iso from Microsoft.
- [x] Automatically compile/set up LookingGlass
- [x] Automatically build an ACPI fake battery (to circumvent Nvidia's Error 43)
- [x] Automatically patch OVMF with your vBIOS ROM (to circumvent Nvidia's Error 43)

### In the virtual machine (Windows)

- [x] Automatically install the required drivers (ivshmem, other vfio drivers, Intel/Nvidia display drivers)
- [x] Automatically compile/install/start LookingGlass
- [x] Automatically configure the network
- [ ] Automatically set up RDP
- [x] Automatically install and autostart LookingGlass

And there is also a lot of advanced stuff that I managed to fully automate, like:

 - [x] Automatically rebinding the dGPU to the vfio drivers (when the VM starts)
 - [x] Automatically rebinding the dGPU to the nvidia/amd drivers (when the VM exits)
 - [x] Automatically creating a vGPU from the (Intel) iGPU (when the VM starts) to allow sharing the iGPU with the VM (aka "mediated iGPU passthough" using GVT-g) (So your VM can safe a ton of battery life when it doesn't need the dGPU.)

## Screenshot of the compatibility check (./mbpt.sh check)
![example output](screenshots/example-output.png)

## Currently supported distributions

 - Fedora 34
 - Ubuntu 21.04 (not tested in a while)

## Limitations

- The project is currently only compatible with Fedora and Ubuntu out of the box (Support for older Fedora/Ubuntu versions may break over time because I don't test changes made to this repo against older distributions.). (To add support for a new distro, copy one of the folders found in [utils](utils)) and adjust it for your distro.)
- This project currently only supports Windows 10 x64 VMs and hopefully Windows 11 x64 VMs at some point. (For older Windows versions you have to figure out the driver installation etc. on your own.)
- Only tested for Intel+Nvidia and Intel+AMD systems. (Although the compatibility-check (./mbpt.sh check) should actually work on any hardware.)
- Expect bugs. I have only tested this on a handful of devices and I have constantly changed the scripts without testing everything every time.
- Automated vBIOS ROM extraction will fail in most cases. You might have to extract it from a BIOS update. (You may not need the vBIOS ROM though.)
- This project takes a couple of measures to circumvent Nvidia's infamous Error 43, which you normally see in the Windows device manager when you pass a mobile Nvidia GPU through to a Windows VM. But even with these measures, some systems will still show Error 43. 
- Some AMD GPUs will give you an Error 43 as well (e.g. Radeon RX Vega M GL). I have no idea how to circumvent that one yet.

## Measures taken agains error 43

 - Hide that the VM is a VM
 - Change the vendor ID
 - Provide the VM with a fake battery
 - Provide the VM with the vBios ROMs
 - Patch OVMF, hardcoding your dGPU vBIOS ROM in it
 - (Another measure you can scripttake yourself is installing a recent Nvidia driver in your VM. See [this](https://nvidia.custhelp.com/app/answers/detail/a_id/5173/~/geforce-gpu-passthrough-for-windows-virtual-machine-%28beta%29))
 - Other projects that may help, but are very outdated and currently don't work: [NVIDIA-vBIOS-VFIO-Patcher](https://github.com/Matoking/NVIDIA-vBIOS-VFIO-Patcher), [nvidia-kvm-patcher](https://github.com/sk1080/nvidia-kvm-patcher).  

## How to use?

### BIOS/UEFI configuration
- On some (gaming) notebooks the integrated graphics of the CPU are disabled. If that is the case for you, you need to enable them in the BIOS/UEFI.
  (Some vendors actually disable the CPU integrated GPU completely and don't offer UEFI options to enable it. Modding your BIOS could potentially fix that. See the "UEFI / BIOS modding" for more information on that.)
- You might also have to disable secure boot in the UEFI.
  (Mainly to use Nvida's proprietary driver on Linux while your VM is not running.)
- It might also be necessary to disable fastboot in the UEFI.
- It is highly recommended to have your Linux installed in UEFI mode (rather than in legacy mode).
  If you drive doesn't show up during the installation in UEFI mode, make sure the SATA mode is set to AHCI in the UEFI, even if you don't use SATA.

### Installation and configuration
- Download and install [standard Fedora](https://getfedora.org/) or the [KDE version](https://spins.fedoraproject.org/kde/) or [Ubuntu](https://ubuntu.com/download/desktop) (ideally in UEFI mode!)
- Make sure to create a user account (with administrator rights) (in case you are asked) so that you can use sudo
- Open a terminal and install git by typing the following, pressing enter after each line:

``` bash
sudo dnf install git -y # Install git
git clone https://github.com/T-vK/MobilePassThrough.git # Clone the project
cd MobilePassThrough # Enter the project directory
./mbpt.sh setup # Install dependencies
./mbpt.sh configure # Create a config file interactively
./mbpt.sh auto # Dependency installation; kernel param config; bumblebee / nvidia driver installation; windows ISO download; reboot to load new kernel params; create a helper iso with drivers and autounattended config for Windows; create and start VM; install Windows in the VM fully unattended; install drivers and looking glass in the VM automatically; check for error 43 automatically and show a warning if it occurs
# In the future start the VM with `./mbpt.sh start`
```

- Once the installation finished you should be able to open Remmina and connect to `rdp://192.168.99.2`

- Then in the second terminal run:
``` bash
cd MobilePassThrough # Enter the project directory
cd ./thirdparty/LookingGlass/client/build/ # Enter the directoy containing the looking glass client executable
./looking-glass-client # Run the looking glass client
```

## How to use mbpt.sh

```
$ ./mbpt.sh help
mbpt.sh COMMAND [ARG...]
mbpt.sh [ -h | --help ]

mbpt.sh is a wrapper script for a collection of tools that help with GPU passthrough on mobile devices like notebooks and convertibles.

Options:
  -h, --help       Print usage
  -v, --version    Print version information

Commands:
    setup        Install required dependencies and set required kernel parameters
    check        Check if and to what degree your notebook is capable of running a GPU passthrough setup
    configure    Interactively guides you through the creation of your config file
    iso          Generate a helper iso file that contains required drivers and a helper-script for your Windows VM
    start        Start your VM
    vbios        Dump the vBIOS ROM from the running system or extract it from a BIOS update

Examples:
    # Install required dependencies and set required kernel parameters
    mbpt.sh setup

    # Check if and to what degree your notebook is capable of running a GPU passthrough setup
    mbpt.sh check

    # Interactively guides you through the creation of your config file
    mbpt.sh confi`gure

    # Generate a helper iso file that contains required drivers and a helper-script for your Windows VM
    mbpt.sh iso

    # Start your VM
    mbpt.sh start

    # Dump the vBIOS ROM of the GPU with the PCI address 01:00.0 to ./my-vbios.rom (This will most likely fail)
    mbpt.sh vbios dump 01:00.0 ./my-vbios.rom

    # Extract all the vBIOS ROMs of a given BIOS update to the directory ./my-roms
    mbpt.sh vbios extract /path/to/my-bios-update.exe ./my-roms
```

## Requirements to get GPU-passthrough to work on mobile

- Device needs to be (mostly) compatible with Linux.  
    Note: most Laptops should be these days  

- At least two GPUs (typically Intel's iGPU and an Nvidia GPU)  
    Note: If you have Thunderbolt 3, you might be able to use an eGPU. See: https://egpu.io  
    Note2: Theoretically it's possible to get this to work with only one GPU, but then you wouldn't be able to use your host system directly while running the VM, not to mention the like 50 other issues you'll run into.  

- CPU needs to support `Intel VT-x` / `AMD-V`  
    Note: Unless your notebook is like 10 years old, the CPU should support this.    
    Note2: If it supports `Intel VT-d` / AMD's `IOMMU` it should automatically also support `Intel VT-x` / `AMD-V`.    
- Chipset to support `Intel VT-x` / `AMD-V`    
    Note: Unless your notebook is like 10 years old, it should support this.    
    Note2: If it supports `Intel VT-d` / AMD's `IOMMU` it should automatically also support `Intel VT-x` / `AMD-V`.    
- BIOS/UEFI option to enable `Intel VT-x` / `AMD-V` must exist or it has to be enabled    
    Note: Unless your notebook is like 10 years old, it should support this.    
    Note2: If it supports `Intel VT-d` / AMD's `IOMMU` it should automatically also support `Intel VT-x` / `AMD-V`.    
    Possible workaround: Modding your BIOS/UEFI using tools like UEFITool, AMIBCP etc.  (See "UEFI / BIOS modding" below)   

- CPU needs to support `Intel VT-d` / AMD's `IOMMU`  
    Note: If you have an Intel CPU, you can [check if it's in this list](https://ark.intel.com/Search/FeatureFilter?productType=processors&VTD=true&MarketSegment=Mobile).  
- Chipset to support `Intel VT-d` / AMD's `IOMMU`  
    Note: If your CPU/chipset is from Intel, you search it in [this list](https://www.intel.com/content/www/us/en/products/chipsets/view-all.html) to check if it supports VT-d.  
- BIOS/UEFI needs to support `Intel VT-d` / AMD's `IOMMU`  
    Possible workaround: Modding your BIOS/UEFI using tools like UEFITool, AMIBCP etc. (See "UEFI / BIOS modding" below)  

- When using an iGPU + dGPU setup, the iGPU needs to be enabled or the BIOS/UEFI needs to have an option to do so.  
    Possible workaround: Modding your BIOS/UEFI using tools like UEFITool, AMIBCP etc. (See "UEFI / BIOS modding" below)   

- The GPU you want to pass through, has to be in an IOMMU group that doesn't have other devices in it that the host system needs.  
    Possible workaround: You might be able to tear the groups further apart using the ACS override patch, but it's no magic cure, there are drawbacks.  


The last point really seems to be the biggest hurdle, but since it's just a software issue, it should be possible to get this to work.  
We just need some smart people to fix one of these patches or to make them more accessible.


## Potentially useful hardware tools

[USB Programmer for BIOS/UEFI flashing or unbricking](https://www.aliexpress.com/item/4001045543107.html)
EDID Dummy Plugs for [HDMI](https://www.aliexpress.com/item/-/32919567161.html) and [Mini DisplayPort](https://www.aliexpress.com/item/-/32822066472.html) can be used to make your dGPU write to the framebuffer so that you can use [Looking Glass](https://looking-glass.hostfission.com/). (Your dGPU needs to be connected to your external HDMI or Display Port for that to work though... [This may be possible with some UEFI/BIOS modding](https://github.com/jscinoz/optimus-vfio-docs/issues/2#issuecomment-471234538).)

## List of devices tested for GPU-passthrough compatibility

Check out: https://gpu-passthrough.com/

## UEFI / BIOS modding

By modding your BIOS/UEFI, you can make features available and change settings that are hidden or non-existent by default. For example: show VT-d settings, show secure boot settings, show muxing related settings and much more. There is a good collection of modding tools on [this site here in the BIOS / UEFI tools section](https://forums.tweaktown.com/gigabyte/30530-overclocking-programs-system-info-benchmarking-stability-tools-post284763.html#post284763).  
There are many BIOS modding forums out there with lots of people who are more than willing to help even if you're a complete beginner.

## Known issues
- Sometimes the `./mbpt.sh start` command will fail to start the VM because of this error: "echo: write error: No space left on device". It happens while attempting to create a vGPU for the iGPU. I have no clue why this happens. Sometimes it works if you just try it again, sometimes you need to wait a few minutes before retrying, but other times you actually have to reboot the host system.

## Credits

Credits to [Wendell from Level1Techs](https:`//level1techs.com/) for his GPU passthrough guides/videos and [Misairu-G for his Optimus laptop dGPU passthrough guide](https://gist.github.com/Misairu-G/616f7b2756c488148b7309addc940b28).
Without them I would have never even thought about creating this project. Thank you so much!!

Credits to [korewaChino](https://github.com/T-vK/MobilePassThrough/pull/13) for adding support for Ubuntu!

## TODO

### High prio
- Install guest tools
- Fix automatic Nvidia driver installation in the VM (fix chocolatey)
- Add vm remove option to vm.sh
- Finish the requirements.json
- Automatically find and install dependencies by parsing the requirements.json
- Fix static IP
- Fix RDP
- Fix Samba sharing
- Generate libvirt XML

### Low prio
- Add nuveau driver compatibility
- Allow the user to decide if he wants bumblebee or not (for Nvidia GPUs)
- More detailed output about how the device is muxed
- Create a bootable live version of this project
- Create packages (deb, rpm, etc)
- Add compatibility for Arch, Debian, etc...
- Make this project work better on systems that already have a non-default GPU driver installed
- Make it easy to uninstall the dependencies and undo the changes to the systm config (like kernel parameters)
- Find a way to circumvent Error 43 for AMD GPUs like the `Radeon RX Vega M GL`
- Reduce the size of the ovmf-vbios-patch Docker image
- Make the USB passthrough device selection easier (i.e. display a list of devices that can be selected)
- Look into hotplugging and check if the GPU can be hotplugged during VM runtime
- Check if required dependencies are installed for each script
- Add support for multiple VMs
- Add support for Linux guests