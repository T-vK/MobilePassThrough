# MobilePassThrough

## Introduction
The goal of this project is to make GPU pass-through on notebooks as easy and accessible as possible.  
To achieve that goal I have created a collection of scripts that automate:

- The installation of required dependencies
- The changes required to the kernel parameters
- The installation of Bumblebee and the Nvidia GPU driver
- The checking required to find out to what extend your device is compatible with GPU pass-through.
- The extraction of your GPU's VBIOS ROM
- The creation and configuration of a virtual machine that is fully configured for GPU pass-through.
- The required rebinding of the GPU to either the vfio drivers (when the VM starts) or the nvidia drivers (when the VM exits).

## Limitations

- The project is currently only compatible to Fedora 29 out of the box. 
- Your device needs to have an Intel CPU and an Nvidia GPU. (The compatibility-check script should work on any hardware. The other scripts would need some adjustment though.) 
- Expect bugs. I have only tested this on a handful of devices and I have constantly changed the scripts without testing everything every time.
- VBIOS ROM extraction will likely fail because the nvidia kernel module is loaded. (You may not need the VBIOS ROM though.)
- There is no scripted way to get rid of Error 43, which you might see in the Windows device manager when you pass a mobile GPU through to a Windows VM.

## Screenshot of the compatibility-check script
![example output](screenshots/example-output.png)


## Usage
- On the computer you want to check you first have to go to the UEFI and enable virtualization. On AMD CPU systems: AMD-V and IOMMU. And on Intel CPU systems: VT-x and VT-d. (Beware: Some motherboard vendors get pretty creative when it comes to giving these options other names.)
- You should enable the internal GPU of the CPU so that you have two (one for the host one for the guest system)
  (some vendors actually disable the CPU internal GPU completely and don't offer UEFI options to enable it)
- You might also have to disable secure boot in the UEFI.
- It might also be necessary to disable fastboot in the UEFI.
- Next you need to install Fedora 29.
- Download this project and run the `setup.sh` script.
- Reboot.
- Run the compatibility-check script.
- Change the options at the top of the `start-vm.sh` script and `prepare-vm` script to your liking. 
  (If you don't have a VBIOS ROM, don't use the GPU_ROM option.)
- Run the `start-vm.sh` script.


## Requirements to get GPU-passthrough to work on mobile

- [ ] Device needs to be (mostly) compatible with Linux.  
    Note: most Laptops should be these days  

- [ ] At least two GPUs (typically Intel's iGPU and an Nvidia GPU)  
    Note: If you have Thunderbolt 3, you might be able to use an eGPU. See: https://egpu.io  
    Note2: Theoretically it's possible to get this to work with only one GPU, but then you wouldn't be able to use your host system directly while running the VM, not the mention like 50 other issues you'll run into.  

- [ ] CPU needs to support `Intel VT-x` / `AMD-V`  
    Note: Unless your notebook is like 10 years old, the CPU should support this.    
    Note2: If it supports `Intel VT-d` / AMD's `IOMMU` it should automatically also support `Intel VT-x` / `AMD-V`.    
- [ ] Chipset to support `Intel VT-x` / `AMD-V`    
    Note: Unless your notebook is like 10 years old, it should support this.    
    Note2: If it supports `Intel VT-d` / AMD's `IOMMU` it should automatically also support `Intel VT-x` / `AMD-V`.    
- [ ] BIOS/UEFI option to enable `Intel VT-x` / `AMD-V` must exist or it has to be enabled    
    Note: Unless your notebook is like 10 years old, it should support this.    
    Note2: If it supports `Intel VT-d` / AMD's `IOMMU` it should automatically also support `Intel VT-x` / `AMD-V`.    
    Possible workaround: Modding your BIOS/UEFI using tools like UEFITool, AMI Aptio MMTool etc.    

- [ ] CPU needs to support `Intel VT-d` / AMD's `IOMMU`  
    Note: If you have an Intel CPU, you can [check if it's in this list](https://ark.intel.com/Search/FeatureFilter?productType=processors&VTD=true&MarketSegment=Mobile).  
- [ ] Chipset to support `Intel VT-d` / AMD's `IOMMU`  
    Note: If your CPU/chipset is from Intel, you search it in [this list](https://www.intel.com/content/www/us/en/products/chipsets/view-all.html) to check it it supports VT-d.  
- [ ] BIOS/UEFI needs to support `Intel VT-d` / AMD's `IOMMU`  
    Possible workaround: Modding your BIOS/UEFI using tools like UEFITool, AMI Aptio MMTool etc.  

- [ ] When using an iGPU + dGPU setup, the iGPU needs to be enabled or the BIOS/UEFI needs to have an option to do so.  
    Possible workaround: Modding your BIOS/UEFI using tools like UEFITool, AMI Aptio MMTool etc.  

- [ ] The GPU you want to pass through, has to be in an IOMMU group that doesn't have other devices in it that the host system needs.  
    Possible workaround: You might be able to tear the groups further apart using the ACS override patch, but it's no magic cure, there are drawbacks.  

- [ ] When using an Nvidia dGPU for the passthrough, you'll most likely have to patch your GPU VBIOS ROM using [NVIDIA-vBIOS-VFIO-Patcher](https://github.com/Matoking/NVIDIA-vBIOS-VFIO-Patcher) or the OvmfPkg using [arne-claey's OvmfPkg patch](https://github.com/jscinoz/optimus-vfio-docs/issues/2) or path the Nvidia driver using [nvidia-kvm-patcher](https://github.com/sk1080/nvidia-kvm-patcher).  
    Note: Loading modded VBIOS ROMS should be pretty safe as the ROM gets deleted after every GPU shutdown anyway.  
    Note2: The `nvidia-kvm-patcher` is pretty buggy and very outdated and you'll most likely not get it to work especially with recent drivers. I haven't had any success with any driver so far.  
    Note3: I haven't been able to get arne-claey's OvmfPkg patch to build on my Fedora machine so far.  
    Note4: I haven't been able to get `NVIDIA-vBIOS-VFIO-Patcher` either yet.  


The last point really seems to be the biggest hurdle, but since it's just a software issue, it should be possible to get this to work.  
We just need some smart people to fix one of these patches or to make them more accessable.

In order to force your GPU to create a frame buffer while not having an external monitor hooked up, you can get fairly cheap EDID Dummy Plugs for [HDMI](https://www.aliexpress.com/item/-/32919567161.html) and [Mini DisplayPort](https://www.aliexpress.com/item/-/32822066472.html). You need that frame buffer in order to use [Looking Glass](https://looking-glass.hostfission.com/).

## GPU-passthrough Compatibility List

```
+-----------------------------+-----------------------------+------------------+--------------------------------------------------+
| Device                      | dGPU passthrough            | iGPU passthrough | Checklist                                        |
+-----------------------------+-----------------------------+------------------+--------------------------------------------------+
| Razer Blade 15 (2018 Basic  | Linux guest: Probably works | Probably works   | +Linux compatible                                |
| model)                      | Windows guest: Works, but   |                  | +At least two GPUs                               |
| CPU: Intel Core i7-8750H    | Nvidia driver fails with    |                  | +CPU supports `Intel VT-d` / AMD's `IOMMU`       |
| GPU: GTX 1060 Mobile        | error 43.                   |                  | +Chipset supports `Intel VT-d` / AMD's `IOMMU`   |
| with Max-Q design (6GB)     |                             |                  | +UEFI/BIOS supports `Intel VT-d` / AMD's `IOMMU` |
|                             |                             |                  | +iGPU is enabled                                 |
|                             |                             |                  | (+probably MUXed)                                |
+-----------------------------+-----------------------------+------------------+--------------------------------------------------+
| MSI GF72 8RE-032            | Linux guest: Probably works | Probably works   | +Linux compatible                                |
| CPU: Intel Core i7-8750H    | Windows guest: Works, but   |                  | +At least two GPUs                               |
| GPU: GTX 1060 Mobile (6GB)  | Nvidia driver fails with    |                  | +CPU supports `Intel VT-d` / AMD's `IOMMU`       |
|                             | error 43.                   |                  | +Chipset supports `Intel VT-d` / AMD's `IOMMU`   |
|                             |                             |                  | +UEFI/BIOS supports `Intel VT-d` / AMD's `IOMMU` |
|                             |                             |                  | +iGPU is enabled                                 |
|                             |                             |                  | (+probably MUXed)                                |
+-----------------------------+-----------------------------+------------------+--------------------------------------------------+
| HP Pavilion G6-2348SG       | Not possible                | Not possible     | +Linux compatible                                |
| CPU: Intel Core i7 3632QM   |                             |                  | +At least two GPUs                               |
| GPU: AMD Radeon HD 7670M    |                             |                  | +CPU supports `Intel VT-d` / AMD's `IOMMU`       |
|                             |                             |                  | -Chipset supports `Intel VT-d` / AMD's `IOMMU`   |
|                             |                             |                  | -UEFI/BIOS supports `Intel VT-d` / AMD's `IOMMU` |
|                             |                             |                  | +iGPU is enabled                                 |
|                             |                             |                  | (+probably MUXed)                                |
+-----------------------------+-----------------------------+------------------+--------------------------------------------------+
```

## Credits

Credits to Wendell from Level1Techs for his GPU pass-through guides/videos and Misairu-G for his Optimus laptop dGPU passthrough guide.
Without them I would have never even thought about creating this project. Thank you so much!!
