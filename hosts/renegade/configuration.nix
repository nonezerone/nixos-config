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
      "i915.enable_dc=0"
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

  # Many AVRCP headsets (KOSS Porta Pro Wireless confirmed) lose a race in
  # bluetoothd's avctp.c right when A2DP connects: both sides try to open the
  # AVRCP control channel at once, bluetoothd logs "avctp_control_confirm()
  # Control: Refusing unexpected connect" / "Connection refused (111)", and
  # MediaControl1.Connected on the device sticks at false - so the headset's
  # play/pause/next/prev buttons do nothing even though audio works fine.
  # A delayed, explicit ConnectProfile(AVRCP) retry after the device connects
  # avoids the race and brings the control channel up (verified live).
  systemd.services.bluetooth-avrcp-reconnect = {
    description = "Retry AVRCP control connect after BlueZ's avctp cross-connect race";
    after = [ "bluetooth.service" ];
    requires = [ "bluetooth.service" ];
    wantedBy = [ "bluetooth.target" ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 3;
      ExecStart = pkgs.writeShellScript "bluetooth-avrcp-reconnect" ''
        set -uo pipefail
        export PATH="${pkgs.systemd}/bin:${pkgs.glib}/bin:${pkgs.gawk}/bin:${pkgs.coreutils}/bin"

        avrcp_uuid="0000110e-0000-1000-8000-00805f9b34fb"

        try_connect_avrcp() {
          local path="$1" uuids connected
          uuids=$(busctl --system get-property org.bluez "$path" org.bluez.Device1 UUIDs 2>/dev/null) || return 0
          case "$uuids" in *"$avrcp_uuid"*) ;; *) return 0 ;; esac

          for _ in 1 2 3 4 5; do
            connected=$(busctl --system get-property org.bluez "$path" org.bluez.MediaControl1 Connected 2>/dev/null | awk '{print $2}')
            [ "$connected" = "true" ] && return 0
            busctl --system call org.bluez "$path" org.bluez.Device1 ConnectProfile s "$avrcp_uuid" >/dev/null 2>&1
            sleep 2
          done
        }

        gdbus monitor --system --dest org.bluez 2>/dev/null | while IFS= read -r line; do
          case "$line" in
            *"org.bluez.Device1"*"'Connected':"*"<true>"*)
              path="''${line%%:*}"
              ( sleep 2; try_connect_avrcp "$path" ) &
              ;;
          esac
        done
      '';
    };
  };

  # Xbox Series wireless controller over Bluetooth. xpadneo replaces the
  # in-kernel xpad driver with full per-trigger (impulse trigger) rumble
  # support instead of just the two main motors.
  hardware.xpadneo = {
    enable = true;
    settings = {
      # 0 = extended trigger feedback: rumble each trigger independently by
      # pressure and the active FF effect. 2 disables trigger rumble.
      trigger_rumble_mode = 0;
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
    useXkbConfig = true;
  };

  services.xserver.xkb = {
    layout = "us,ru";
    options = "caps:ctrl_modifier,grp:win_space_toggle";
  };

  programs.zsh = {
    enable = true;
  };

  users.users.nonezerone = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "input" "battery_ctl" "libvirtd" "kvm" ];
    initialPassword = "changeme";
    shell = pkgs.zsh;
  };

  users.groups.battery_ctl = { };

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="BAT0", \
      RUN+="${pkgs.coreutils}/bin/chgrp battery_ctl /sys$devpath/charge_control_end_threshold", \
      RUN+="${pkgs.coreutils}/bin/chmod g+w /sys$devpath/charge_control_end_threshold"
  '';

  systemd.services.battery-charge-threshold = {
    description = "Set battery charge stop threshold";
    wantedBy = [ "multi-user.target" "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    after = [ "sysinit.target" "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo 90 > /sys/class/power_supply/BAT0/charge_control_end_threshold'";
    };
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

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;                        # `docker` CLI alias backed by podman
    defaultNetwork.settings.dns_enabled = true;  # container-to-container DNS resolution
    dockerSocket.enable = true;                  # /run/docker.sock for tools that talk to the Docker API directly
  };

  virtualisation.containers.registries.settings.unqualified-search-registries = [ "docker.io" ];

  # KVM/QEMU via libvirt, managed with virt-manager — for Windows 11 guests.
  # Win11 needs TPM 2.0 (swtpm) and UEFI Secure Boot; OVMF (incl. the
  # secure-boot variant) ships with QEMU and is exposed by libvirtd by default.
  virtualisation.libvirtd = {
    enable = true;
    onBoot = "ignore";           # don't autostart guests at boot
    onShutdown = "shutdown";     # cleanly shut guests down instead of suspending them
    qemu = {
      package = pkgs.qemu_kvm;   # host-arch only, smaller than full qemu
      runAsRoot = false;
      swtpm.enable = true;
    };
  };
  programs.virt-manager.enable = true;
  virtualisation.spiceUSBRedirection.enable = true; # pass USB devices into the guest from virt-viewer/virt-manager

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
    ipafont
  ];

  fonts.fontconfig.defaultFonts.monospace = [ "TX-02" "Comic Code" "JetBrains Mono" ];

  fonts.fontconfig.localConf = ''
    <match target="pattern">
      <test name="lang"><string>ja</string></test>
      <test qual="any" name="family"><string>sans-serif</string></test>
      <edit name="family" mode="prepend" binding="strong"><string>IPAGothic</string></edit>
    </match>
    <match target="pattern">
      <test name="lang"><string>ja</string></test>
      <test qual="any" name="family"><string>serif</string></test>
      <edit name="family" mode="prepend" binding="strong"><string>IPAMincho</string></edit>
    </match>
  '';

  environment.pathsToLink = [ "/include" ];
  environment.extraOutputsToInstall = [ "dev" ];

  environment.systemPackages = [
    pkgs.git
    config.services.postgresql.package
    pkgs.libinput
    pkgs.libimobiledevice
    pkgs.p7zip
    pkgs.vips
    pkgs.virtio-win # Windows guest drivers ISO: attach $(nix eval --raw nixpkgs#virtio-win)/virtio-win.iso
  ];

  # Do not change after initial install — see the NixOS manual.
  system.stateVersion = "25.05";
}
