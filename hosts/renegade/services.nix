{ config, lib, pkgs, ... }:

# Media streaming + home file storage. Everything lives under /srv, owned by
# the `media` group so Jellyfin/Navidrome can read what gets dropped in over
# Samba. Reached on the LAN directly and from outside via Tailscale.
#
#   Jellyfin   http://renegade:8096  video (+ music), VA-API transcoding
#   Navidrome  http://renegade:4533  music, Subsonic API (Symfonium, Amperfy…)
#   Samba      smb://renegade/media, smb://renegade/files
{
  users.groups.media = { };

  # setgid dirs so anything written inside stays group `media`.
  systemd.tmpfiles.rules = [
    "d /srv/media        2775 nonezerone media - -"
    "d /srv/media/music  2775 nonezerone media - -"
    "d /srv/media/movies 2775 nonezerone media - -"
    "d /srv/media/shows  2775 nonezerone media - -"
    "d /srv/files        2775 nonezerone media - -"
  ];

  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };
  # render/video for /dev/dri/renderD128 (hardware transcoding).
  users.users.jellyfin.extraGroups = [ "media" "render" "video" ];
  systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "iHD";

  services.navidrome = {
    enable = true;
    openFirewall = true;
    settings = {
      Address = "0.0.0.0";
      Port = 4533;
      MusicFolder = "/srv/media/music";
      ScanSchedule = "@every 1h";
    };
  };
  users.users.navidrome.extraGroups = [ "media" ];

  # Samba keeps its own password DB: run `sudo smbpasswd -a nonezerone` once.
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "server string" = "renegade";
        "server min protocol" = "SMB3";
        # LAN + loopback + Tailscale's 100.64.0.0/10 range.
        "hosts allow" = "192.168. 10. 172.16. 100. 127.";
        "hosts deny" = "0.0.0.0/0";
        "map to guest" = "never";
      };
      media = {
        path = "/srv/media";
        "valid users" = "nonezerone";
        "read only" = "no";
        "force group" = "media";
        "create mask" = "0664";
        "directory mask" = "2775";
      };
      files = {
        path = "/srv/files";
        "valid users" = "nonezerone";
        "read only" = "no";
        "force group" = "media";
        "create mask" = "0664";
        "directory mask" = "2775";
      };
    };
  };

  # Lets Windows' network browser and Linux/macOS file managers discover the shares.
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  # `sudo tailscale up` once to log the machine into the tailnet.
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
