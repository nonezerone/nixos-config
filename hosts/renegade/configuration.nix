{ config, lib, pkgs, inputs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot = {
    initrd.kernelModules = [ "i915" ];
    kernelParams = [ "i915.enable_psr=0" ];

  };

  zramSwap.enable = true; # no hibernation, just RAM-backed swap

  hardware.trackpoint = {
    enable = true;
    device = "DualPoint Stick";
  };

  networking.hostName = "renegade";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Tbilisi";
  i18n.defaultLocale = "en_IE.UTF-8";

  console = {
    enable = true;
    packages = [ pkgs.terminus_font ];
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v18n.psf.gz";
    keyMap = "us";
  };

  programs.zsh = {
    enable = true;
  };

  users.users.nonezerone = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "input" ];
    initialPassword = "changeme";
    shell = pkgs.zsh;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      openssl
      curl
      bzip2
      xz
      libxml2
      icu
    ];
  };

  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    (final: prev: {
      ghostty = prev.ghostty.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          rm -f $out/share/terminfo
        '';
      });
    })
  ];

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "nonezerone" ];
    ensureUsers = [
      {
        name = "nonezerone";
        ensureDBOwnership = true;
      }
    ];
  };

  services.redis.servers."" = {
    enable = true;
  };

  services.usbmuxd = {
    enable = true;
    package = pkgs.usbmuxd2;
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # VAAPI, iHD — primary driver for this GPU
      intel-vaapi-driver # legacy i965 fallback (renamed from vaapiIntel, which nixpkgs now throws on)
      libvdpau-va-gl
    ];
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  programs.niri.enable = true;
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --asterisks --cmd ${config.programs.niri.package}/bin/niri-session";
      user = "greeter";
    };
  };

  programs.noctalia = {
    enable = true;
    recommendedServices.enable = true;
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  programs.ssh.startAgent = true;
  services.gnome.gcr-ssh-agent.enable = false;
  environment.sessionVariables.SSH_AUTH_SOCK = "/run/user/\${UID}/ssh-agent";

  fonts.packages = with pkgs; [ inter
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    liberation_ttf
  ];

  environment.systemPackages = [
    pkgs.git
    config.services.postgresql.package
    pkgs.libinput
    pkgs.libimobiledevice
  ];

  # Do not change after initial install — see the NixOS manual.
  system.stateVersion = "25.05";
}
