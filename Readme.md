# NixOS2 - Secondary/Backup Server

A fully declarative, reproducible NixOS server configured as a **secondary/backup server** with failover capability. This is the companion to the primary [nixos-config](https://github.com/ppb1701/nixos-config) server.

## Server Role

**This is NIXOS2 - the secondary server in a two-server setup:**

- **Primary Git Server:** Gitea runs HERE (mirrors to GitHub)
- **Backup/Failover:** Most services are disabled but fully configured for quick failover
- **Data Replication:** Syncthing mirrors data from the primary server
- **Redundant DNS:** AdGuard Home provides backup DNS filtering

## Security Warning

This configuration uses a **temporary, publicly-known password** for initial convenience:

**Default Password:** `nixos`

**After installation, you MUST:**

1. SSH into the system: `ssh ppb1701@YOUR_IP` (password: `nixos`)
2. Change your password: `passwd`
3. Edit `/etc/nixos/configuration.nix`:
   - Remove: `initialPassword = "nixos";`
   - Change: `security.sudo.wheelNeedsPassword = true;`
4. Rebuild: `sudo nixos-rebuild switch`

**DO NOT expose this system to the internet before changing the password!**

## Service States

### Enabled Services (Running)

- **AdGuard Home:** Network-wide ad blocking and DNS filtering
  - Backup DNS server for the network
  - Web UI at http://adguard2.home or port 3000
- **Gitea:** Self-hosted Git server (PRIMARY INSTANCE)
  - This is the main Git server, mirrors to GitHub
  - Web UI at http://git.home or port 3300
- **Syncthing:** Cross-platform file synchronization
  - Mirrors data from primary server for disaster recovery
  - Web UI at http://syncthing2.home or port 8384
- **Tailscale:** Secure mesh VPN
  - Remote access to this server
- **Nginx:** Reverse proxy for clean local URLs

### Disabled Services (Failover-Ready)

These services are fully configured but disabled. Enable for failover if the primary server fails:

- **Nextcloud:** Private cloud storage (runs on primary)
- **Vaultwarden:** Password manager (runs on primary)
- **SearX:** Self-hosted search (runs on primary)
- **Linkwarden:** Bookmark manager (runs on primary)
- **NoteDiscovery:** Knowledge base (runs on primary)
- **ntfy-sh:** Push notifications (runs on primary)
- **PostgreSQL:** Database (enable if running Linkwarden/Nextcloud)

### Enabling a Failover Service

```bash
# 1. Edit services.nix
sudo micro /etc/nixos/modules/services.nix

# 2. Find the service and change:
#    enable = false;  -->  enable = true;

# 3. Configure required secrets in /etc/nixos/private/

# 4. Rebuild
sudo nixos-rebuild switch
```

## Quick Start

### Manual Installation

On an existing NixOS system:

```bash
git clone https://github.com/ppb1701/nixos2-config /etc/nixos
cd /etc/nixos
sudo nixos-rebuild switch
```

> **Note:** You'll need to adjust `hardware-configuration.nix` for your hardware.

### From ISO

1. Boot from USB
2. Login (user: `nixos`, password: `nixos`)
3. Run: `sudo /etc/nixos-config/install-nixos.sh`
4. Follow prompts
5. Reboot

## Configuration

### Network Settings

Edit `modules/networking.nix`:

```nix
networking = {
  useDHCP = false;
  interfaces.eno1 = {
    ipv4.addresses = [{
      address = "192.168.50.218";  # Your secondary server IP
      prefixLength = 24;
    }];
  };
  defaultGateway = "192.168.50.1";
  nameservers = [ "127.0.0.1" ];
};
```

### Gitea (Primary Git Server)

Gitea is enabled and configured as the primary Git hosting server:

```nix
services.gitea = {
  enable = true;
  settings.server = {
    DOMAIN = "git.home";
    ROOT_URL = "http://git.home";
    HTTP_PORT = 3300;
  };
};
```

**Access:** http://git.home or http://YOUR_IP:3300

**Required secrets in `/etc/nixos/private/secrets.nix`:**
```nix
{
  giteaSecret = "your-gitea-secret-key";
  giteaInternalToken = "your-gitea-internal-token";
}
```

### Syncthing (Data Replication)

Syncthing mirrors data from the primary server:

1. Configure devices in `/etc/nixos/private/syncthing-devices.nix`
2. Add the primary server as a device
3. Share folders for replication

**Access:** http://syncthing2.home or http://YOUR_IP:8384

## Repository Structure

```
nixos2-config/
├── configuration.nix              # Main system configuration
├── configuration-bios.nix         # BIOS/Legacy boot variant
├── configuration-uefi.nix         # UEFI boot variant
├── hardware-configuration.nix     # Hardware-specific settings
├── build-iso.sh                   # ISO build script
├── install-nixos.sh               # Automated installation script
├── modules/
│   ├── services.nix              # Service configurations (Gitea enabled, others failover-ready)
│   ├── nginx-virtualhosts.nix    # Nginx reverse proxy configuration
│   ├── monitoring.nix            # Prometheus, Grafana, etc.
│   ├── backups.nix               # Restic backup configuration
│   ├── networking.nix            # Network & firewall settings
│   ├── system.nix                # System packages, users, SSH
│   ├── boot-bios.nix             # BIOS boot configuration
│   └── boot-uefi.nix             # UEFI boot configuration
├── home/
│   └── ppb1701.nix               # User environment (ZSH, aliases)
├── private/                       # Private config (gitignored)
│   ├── secrets.nix               # Service passwords, Gitea secrets
│   ├── ssh-keys.nix              # SSH authorized keys
│   ├── syncthing-devices.nix     # Syncthing device IDs
│   └── alertmanager.env          # SMTP credentials
├── private-example/               # Example templates
└── README.md                      # This file
```

## Failover Procedures

### If Primary Server Fails

1. **DNS Failover:**
   - AdGuard Home is already running on this server
   - Update DHCP to point clients to this server's IP for DNS

2. **Nextcloud Failover:**
   ```bash
   # Enable Nextcloud
   sudo micro /etc/nixos/modules/services.nix
   # Change: services.nextcloud.enable = true;
   # Also enable PostgreSQL if not already
   sudo nixos-rebuild switch
   ```

3. **Vaultwarden Failover:**
   ```bash
   # Enable Vaultwarden
   sudo micro /etc/nixos/modules/services.nix
   # Change: services.vaultwarden.enable = true;
   sudo nixos-rebuild switch
   # Update Tailscale Funnel to point to this server
   ```

4. **Other Services:**
   - Follow same pattern: edit services.nix, enable service, rebuild

### Returning to Primary

1. Ensure primary server is back online
2. Sync any data changes back to primary
3. Disable failover services on this server
4. Update DNS/DHCP to point back to primary

## System Maintenance

### Shell Aliases

```bash
rebuild   # Rebuild and switch configuration
cleanup   # Clean old generations and optimize store
diskspace # Check disk usage

# Service management
ags/agr/agl  # AdGuard status/restart/logs
sts/str/stl  # Syncthing status/restart/logs
gts/gtr/gtl  # Gitea status/restart/logs
```

### Cleaning Up Old Generations

```bash
cleanup  # Or manually:
sudo nix-collect-garbage -d
sudo nix-store --optimize
```

## Related Repositories

- **Primary Server:** [nixos-config](https://github.com/ppb1701/nixos-config) - Main production server
- **Blog:** https://blog.ppb1701.com/building-a-resilient-home-server-series

## License

MIT License

---

**Built with NixOS - Secondary/Backup Server Configuration**
