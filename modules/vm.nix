{ config, pkgs, lib, ... }:

{
  # ═══════════════════════════════════════════════════════════════════════════
  # LIBVIRT / QEMU - VM HOST FOR ISO BUILDS
  # ═══════════════════════════════════════════════════════════════════════════
  # Hosts the iso-builder VM (nixos-config vm branch) on the 6TB SSD.
  #
  # Workflow:
  #   vmstart          → boot the iso-builder VM
  #   vmssh            → SSH into it (auto-resolves DHCP address via virsh)
  #   run build-iso.sh → ISO copied to /mnt/host-isos/ inside the VM,
  #                      backed by /mnt/nextcloud-data/isos/ on this host
  #                      via virtiofs — appears on the Samba share instantly
  #   grab via Samba   → \\nixos2\isos or isos.home from any machine
  #
  # One-time setup after first rebuild — see docs/VM-SETUP.md
  # ═══════════════════════════════════════════════════════════════════════════

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package      = pkgs.qemu_kvm;
      runAsRoot    = false;
      swtpm.enable = true;
      verbatimConfig = ''
        namespaces = []
      '';
    };
    onBoot     = "start";
    onShutdown = "shutdown";
  };

  programs.virt-manager.enable = true;

  users.users.ppb1701.extraGroups = lib.mkAfter [ "libvirtd" "kvm" ];

  # ═══════════════════════════════════════════════════════════════════════════
  # VIRTIOFSD - SHARED FILESYSTEM FROM HOST TO VM
  # ═══════════════════════════════════════════════════════════════════════════
  # Exposes /mnt/nextcloud-data/isos to the iso-builder VM as /mnt/host-isos.
  # build-iso.sh copies output there — ISO appears on Samba share instantly.
  systemd.services.virtiofsd-iso-builder = {
    description = "virtiofsd shared filesystem for iso-builder VM";
    after       = [
      "libvirtd.service"
      "mnt-nextcloud\\x2ddata.mount"
    ];
    wants    = [ "libvirtd.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type      = "simple";
      ExecStart = ''
        ${pkgs.virtiofsd}/bin/virtiofsd \
          --socket-path=/run/libvirt/qemu/virtiofs-iso-builder.sock \
          --shared-dir=/mnt/nextcloud-data/isos \
          --cache=auto \
          --sandbox=chroot
      '';
      Restart    = "on-failure";
      RestartSec = "5s";
      User  = "root";
      Group = "root";
    };
  };

  systemd.services.libvirt-network-setup = {
    description = "Configure libvirt default NAT network";
    after       = [ "libvirtd.service" ];
    requires    = [ "libvirtd.service" ];
    wantedBy    = [ "multi-user.target" ];
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      VIRSH="${pkgs.libvirt}/bin/virsh"
    
      if ! $VIRSH net-info default >/dev/null 2>&1; then
        $VIRSH net-define /dev/stdin <<EOF
    <network>
      <name>default</name>
      <forward mode='nat'>
        <nat>
          <port start='1024' end='65535'/>
        </nat>
      </forward>
      <bridge name='virbr0' stp='on' delay='0'/>
      <ip address='192.168.122.1' netmask='255.255.255.0'>
        <dhcp>
          <range start='192.168.122.2' end='192.168.122.254'/>
        </dhcp>
      </ip>
    </network>
    EOF
        $VIRSH net-autostart default
        $VIRSH net-start default
      elif ! $VIRSH net-info default | grep -q "^Active:.*yes"; then
        $VIRSH net-start default
      fi
    '';
  };

  # ═══════════════════════════════════════════════════════════════════════════
  # VM STORAGE DIRECTORIES ON THE 6TB SSD
  # ═══════════════════════════════════════════════════════════════════════════
  systemd.tmpfiles.rules = [
    "d /mnt/nextcloud-data/vms  0755 ppb1701 libvirtd - -"
    "d /mnt/nextcloud-data/isos 0775 ppb1701 libvirtd - -"
    "d /run/libvirt/qemu        0755 root root - -"
  ];

  # ═══════════════════════════════════════════════════════════════════════════
  # LIBVIRT STORAGE POOL
  # ═══════════════════════════════════════════════════════════════════════════
  systemd.services.libvirt-pool-setup = {
    description = "Register SSD VM storage pool with libvirt";
    after       = [ "libvirtd.service" ];
    requires    = [ "libvirtd.service" ];
    wantedBy    = [ "multi-user.target" ];
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      VIRSH="${pkgs.libvirt}/bin/virsh"
      if ! $VIRSH pool-info ssd-vms >/dev/null 2>&1; then
        $VIRSH pool-define-as ssd-vms dir --target /mnt/nextcloud-data/vms
        $VIRSH pool-autostart ssd-vms
        $VIRSH pool-start ssd-vms
      elif ! $VIRSH pool-info ssd-vms | grep -q "^State:.*running"; then
        $VIRSH pool-start ssd-vms
      fi
    '';
  };
}
