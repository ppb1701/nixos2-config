{ config, pkgs, lib, ... }:

{
  # Force the hostname
  networking.hostName = lib.mkForce "nixos2";

  # Boot loader (systemd-boot for UEFI)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # User config (override what's being imported)
  users.users.ppb1701 = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    group = "ppb1701";
  };

  users.groups.ppb1701 = {};

  system.stateVersion = "24.11";
}
