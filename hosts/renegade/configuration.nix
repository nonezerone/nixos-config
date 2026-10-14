{ config, lib, pkgs, inputs, ... }:

# Headless home server (Latitude 5490): media streaming + file storage, see
# services.nix. The old niri desktop setup lives in git history (423a939).
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # systemd initrd so the LUKS root can unlock from the TPM with no one at the
  # keyboard. One-time enrollment on the machine (passphrase stays as fallback):
  #   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/sda2
  boot.initrd.systemd.enable = true;
  boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = [ "tpm2-device=auto" ];

  boot.initrd.kernelModules = [ "i915" ];
  # Blank the internal panel after a minute; nobody's looking at it.
  boot.kernelParams = [ "consoleblank=60" ];

  zramSwap.enable = true;

  # Runs lid-closed on the shelf: never suspend.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  networking.hostName = "renegade";
  # Wi-Fi only (no ethernet). Connect from the console with `nmtui`.
  networking.networkmanager = {
    enable = true;
    # Power-save naps on the radio cause stalls/dropouts for a server.
    wifi.powersave = false;
  };

  time.timeZone = "Asia/Tbilisi";
  i18n.defaultLocale = "en_IE.UTF-8";

  console = {
    enable = true;
    packages = [ pkgs.terminus_font ];
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v18n.psf.gz";
    useXkbConfig = true;
  };

  # Only feeds the console keymap via useXkbConfig — no X server is enabled.
  services.xserver.xkb = {
    layout = "us,ru";
    options = "caps:ctrl_modifier,grp:win_space_toggle";
  };

  programs.zsh = {
    enable = true;
  };

  users.users.nonezerone = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "render" "media" "battery_ctl" ];
    initialPassword = "changeme";
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "jlmk"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.groups.battery_ctl = { };

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="BAT0", \
      RUN+="${pkgs.coreutils}/bin/chgrp battery_ctl /sys$devpath/charge_control_end_threshold", \
      RUN+="${pkgs.coreutils}/bin/chmod g+w /sys$devpath/charge_control_end_threshold"
  '';

  # Permanently on AC now, so hold the battery lower to slow wear.
  systemd.services.battery-charge-threshold = {
    description = "Set battery charge stop threshold";
    wantedBy = [ "multi-user.target" ];
    after = [ "sysinit.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold'";
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Lets `nixos-rebuild --target-host` from exorcist copy store paths in.
  nix.settings.trusted-users = [ "root" "@wheel" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;

  nixpkgs.config.allowUnfree = true;

  # Intel UHD 620: iHD for VA-API decode/encode, legacy compute runtime for
  # Jellyfin's OpenCL tone-mapping (Gen8–11 GPUs).
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime-legacy1
    ];
  };

  services.smartd.enable = true;

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;                        # `docker` CLI alias backed by podman
    defaultNetwork.settings.dns_enabled = true;  # container-to-container DNS resolution
  };

  virtualisation.containers.registries.settings.unqualified-search-registries = [ "docker.io" ];

  environment.systemPackages = with pkgs; [
    git
    htop
    btop
    ncdu
    rsync
    tmux
    libva-utils # vainfo: check hardware transcoding support
    smartmontools
  ];

  # Do not change after initial install — see the NixOS manual.
  system.stateVersion = "25.05";
}
