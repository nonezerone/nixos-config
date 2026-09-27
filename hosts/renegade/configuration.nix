{ config, lib, pkgs, inputs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # CachyOS's BORE-scheduler kernel (via the chaotic-cx overlay already used
  # for mesa-git below) — tuned for desktop/gaming latency over stock CFS.
  boot.kernelPackages = pkgs.linuxPackages_cachyos-bore;

  boot = {
    initrd.kernelModules = [ "i915" ];
    kernelParams = [
      "i915.enable_psr=0"
      "mitigations=off"
      "nowatchdog"
    ];
    kernelModules = [ "ntsync" ];

    kernel.sysctl."vm.max_map_count" = 2147483642;
  };

  zramSwap.enable = true;

  hardware.trackpoint = {
    enable = true;
    device = "DualPoint Stick";
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        ControllerMode = "bredr";
      };
    };
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
    extraGroups = [ "wheel" "networkmanager" "video" "input" "battery_ctl" ];
    initialPassword = "changeme";
    shell = pkgs.zsh;
  };

  users.groups.battery_ctl = { };

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="BAT0", \
      RUN+="${pkgs.coreutils}/bin/chgrp battery_ctl /sys$devpath/charge_control_end_threshold", \
      RUN+="${pkgs.coreutils}/bin/chmod g+w /sys$devpath/charge_control_end_threshold"
  '';

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
      libxcrypt
      pkgs.libxcrypt-legacy
      vips
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

      # v0.8.2 has a regression that makes Steam's dropdown/context menus
      # close ~35ms after opening (pointer-leave misreported for
      # override-redirect popups). Fixed upstream in Supreeeme/xwayland-satellite#494
      # but not yet in a release or in nixpkgs — pin to that commit until it lands.
      xwayland-satellite = prev.xwayland-satellite.overrideAttrs (old: rec {
        version = "0.8.2-unstable-2026-09-09";
        src = prev.fetchFromGitHub {
          owner = "Supreeeme";
          repo = "xwayland-satellite";
          rev = "add2795134593faafce60e404a0a75df68e9ee0c";
          hash = "sha256-0TxfMgqW0/BLD4M942c5DCKYrtPvzsPJwvdcco4LQUM=";
        };
        cargoDeps = prev.rustPlatform.fetchCargoVendor {
          inherit src;
          hash = "sha256-s1gl9eR6Mt2QLrhfcowstPFjzwE/lz4PJhJzWYHoIHg=";
        };
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
        ensureClauses.superuser = true;
      }
    ];
  };

  services.mysql.enable = true;
  services.mysql.package = pkgs.mariadb;

  services.redis.servers."" = {
    enable = true;
  };

  services.usbmuxd = {
    enable = true;
    package = pkgs.usbmuxd2;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # needed for Steam/Proton
    extraPackages = with pkgs; [
      intel-media-driver # VAAPI, iHD — primary driver for this GPU
      intel-vaapi-driver # legacy i965 fallback (renamed from vaapiIntel, which nixpkgs now throws on)
      libvdpau-va-gl
    ];
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # Nightly mesa-git build from chaotic-cx/nyx for the latest Intel driver code.
  chaotic.mesa-git.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
    gamescopeSession.enable = true;
    extraPackages = [ pkgs.mangohud ];
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.gamemode = {
    enable = true;
    enableRenice = true;
  };

  programs.niri = {
    enable = true;
    # niri-session calls `systemctl --user import-environment` with no
    # variable names, which recent systemd flags as deprecated (a warning
    # on every login/logout via greetd). Wrap the package so that call
    # gets an explicit name list instead - same behavior, no warning.
    # Upstream tracking: https://github.com/niri-wm/niri/issues/254
    package = pkgs.symlinkJoin {
      name = "niri-${pkgs.niri.version}-session-fixed";
      paths = [ pkgs.niri ];
      passthru = { inherit (pkgs.niri) providedSessions; };
      postBuild = ''
        rm $out/bin/niri-session
        substitute ${pkgs.niri}/bin/niri-session $out/bin/niri-session \
          --replace-fail 'systemctl --user import-environment' \
            'systemctl --user import-environment $(printenv | sed -n "s/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p")'
        chmod +x $out/bin/niri-session
      '';
    };
  };
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk pkgs.kdePackages.xdg-desktop-portal-kde ];
    # Everything defaults to the GTK backend except the file picker, which
    # uses KDE's Qt-based dialog instead. "common" applies regardless of
    # what XDG_CURRENT_DESKTOP niri reports.
    config.common = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
    };
  };

  qt = {
    enable = true;
    platformTheme = "qt5ct";
    style = "adwaita-dark";
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
    jetbrains-mono
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    liberation_ttf
  ];

  fonts.fontconfig.defaultFonts.monospace = [ "TX-02" "Comic Code" "JetBrains Mono" ];

  environment.systemPackages = [
    pkgs.git
    config.services.postgresql.package
    pkgs.libinput
    pkgs.libimobiledevice
    pkgs.p7zip
    pkgs.vips
  ];

  # Do not change after initial install — see the NixOS manual.
  system.stateVersion = "25.05";
}
