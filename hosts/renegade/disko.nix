{
  # CHECK THIS before installing: run `lsblk` from the installer and make sure
  # this is really the internal drive. Most Latitude 5490 units with an NVMe
  # SSD show up as /dev/nvme0n1; SATA/M.2-SATA units show up as /dev/sda.
  disko.devices = {
    disk.main = {
      device = "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              # You'll be prompted for a passphrase during `disko` and again
              # on every boot.
              settings = {
                allowDiscards = true; # needed for SSD TRIM through LUKS
              };
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
