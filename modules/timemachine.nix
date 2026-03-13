{ config, pkgs, ... }:

{
  # ═══════════════════════════════════════════════════════════════════════════
  # SAMBA - TIME MACHINE BACKUP FOR MACOS
  # ═══════════════════════════════════════════════════════════════════════════
  # Provides a Time Machine target on the SSD at /mnt/nextcloud-data/timemachine
  # Cap set to 1.5TB leaving plenty of room for Nextcloud (capped 1TB) and
  # future VM/ISO storage (~1TB). ~2.5TB remains as buffer on the 6TB drive.
  # ═══════════════════════════════════════════════════════════════════════════

 services.samba = {
    enable = true;
    settings = {    
      timemachine = {
        path = "/mnt/nextcloud-data/timemachine";
        browseable = "yes";
        writable = "yes";
        "valid users" = "tmuser";
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:time machine" = "yes";
        "fruit:time machine max size" = "2000G";
      };
    };
  };
 
  # ═══════════════════════════════════════════════════════════════════════════
  # TIME MACHINE USER
  # ═══════════════════════════════════════════════════════════════════════════
  # Dedicated system user for Samba auth. Added to syncthing group to match
  # the existing group ownership pattern on this server.

  users.users.tmuser = {
    isSystemUser = true;
    group = "tmuser";
    extraGroups = [ "syncthing" ];
    description = "Time Machine Samba user";
  };

  users.groups.tmuser = {};

  # ═══════════════════════════════════════════════════════════════════════════
  # DIRECTORY
  # ═══════════════════════════════════════════════════════════════════════════
  # 2775 = setgid + rwxrwsr-x
  # New files inherit syncthing group, consistent with other shared dirs.

  systemd.tmpfiles.rules = [
    "d /mnt/nextcloud-data/timemachine 2775 tmuser syncthing - -"
  ];
}
