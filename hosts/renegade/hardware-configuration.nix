{ config, lib, pkgs, modulesPath, ... }:

# STARTER FILE — replace with the real output of `nixos-generate-config`
# run on the actual Latitude 5490 (see README.md). Filesystems/swap are
# already handled declaratively by disko.nix, so you mainly need to merge
# in whatever kernel modules the generator detects for your exact unit.
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Common modules needed on the Latitude 5490 (NVMe boot drive, USB, and
  # the Realtek SD card reader most of these ship with). Merge with
  # whatever `nixos-generate-config` detects on your unit.
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
