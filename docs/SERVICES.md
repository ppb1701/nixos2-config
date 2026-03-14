# Services Guide - NixOS2 Secondary Server

This guide covers the services on nixos2, the secondary/backup server.

## Server Role

**NIXOS2 is the secondary server with:**
- Gitea as the PRIMARY Git hosting server
- QEMU/libvirt VM host for the iso-builder VM
- Samba shares for ISO distribution and macOS Time Machine
- Remote desktop access via x11vnc + noVNC
- Most other services disabled but configured for failover
- Syncthing for data replication from primary server

## Enabled Services

### Gitea (Port 3300) - PRIMARY

Gitea is the main Git hosting server. Repositories here mirror to GitHub.

**Status:** ENABLED (Primary instance)

**Access:**
- Via Nginx: http://git.home
- Direct: http://YOUR_IP:3300

**Configuration in `modules/services.nix`:**
```nix
services.gitea = {
  enable = true;
  database.type = "sqlite3";
  settings.server = {
    DOMAIN = "git.home";
    ROOT_URL = "http://git.home";
    HTTP_PORT = 3300;
    HTTP_ADDR = "127.0.0.1";
  };
};
```

**Required Secrets (`/etc/nixos/private/secrets.nix`):**
```nix
{
  giteaSecret = "your-secret-key";
  giteaInternalToken = "your-internal-token";
}
```

**Generate secrets:**
```bash
# Secret key
openssl rand -hex 32

# Internal token
openssl rand -hex 32
```

### AdGuard Home (Port 3000)

Backup DNS filtering server.

**Status:** ENABLED

**Access:** http://adguard2.home or http://YOUR_IP:3000

### Syncthing (Port 8384)

File synchronization for data replication.

**Status:** ENABLED

**Access:** http://syncthing2.home or http://YOUR_IP:8384

**Purpose on this server:**
- Mirror data from primary server
- Provide backup copies for disaster recovery
- Sync Gitea repositories if configured

### Homepage Dashboard (Port 8582)

Centralized service dashboard with real-time system resource monitoring.

**Status:** ENABLED

**Access:**
- Via Nginx: http://home2.home
- Direct: http://YOUR_IP:8582

**Features:**
- Auto-discovers enabled services using NixOS module system
- Real-time CPU, memory, and disk usage widgets
- Dark theme with organized categories (Network, Services, Monitoring)
- Only shows tiles for services that are enabled

**Configuration:** `modules/homepage.nix`

**DNS Setup:** Add DNS rewrite in AdGuard Home:
```
home2.home → YOUR_SECONDARY_SERVER_IP
```

### Tailscale

VPN mesh network for remote access.

**Status:** ENABLED

### Nginx (Port 80)

Reverse proxy for clean URLs.

**Status:** ENABLED

### x11vnc + noVNC (Ports 5900, 6080)

Remote desktop access via browser. x11vnc connects to the running LXQT/X11 session and serves it over VNC; noVNC wraps it in a websocket proxy so it's accessible via any browser.

**Status:** ENABLED

**Access:** `http://YOUR_IP:6080/vnc.html`

**Authentication:** Password-protected via `/etc/nixos/private/vncpasswd`

**Setup (first time after rebuild):**
```bash
# Generate the vncpasswd file
x11vnc -storepasswd /etc/nixos/private/vncpasswd
```

**Service management:**
```bash
systemctl status x11vnc        # VNC server (connects to :0)
systemctl status novnc         # noVNC websockify proxy
journalctl -u x11vnc -f        # VNC logs
journalctl -u novnc -f         # noVNC logs
```

**Configuration in `modules/services.nix`:**
```nix
systemd.services.x11vnc = {
  enable = true;
  serviceConfig.ExecStart = "${pkgs.x11vnc}/bin/x11vnc -display :0 -auth /run/lightdm/root/:0 -forever -noxdamage -repeat -rfbauth /etc/nixos/private/vncpasswd -rfbport 5900 -shared -localhost";
};

systemd.services.novnc = {
  enable = true;
  serviceConfig.ExecStart = "${pkgs.python3Packages.websockify}/bin/websockify --web ${pkgs.novnc}/share/webapps/novnc localhost:6080 localhost:5900";
};
```

**Note:** x11vnc listens only on localhost. noVNC proxies from localhost:6080 → localhost:5900. Access is via port 6080 from the LAN. Open port 6080 in `modules/networking.nix` if not already done.

### QEMU/libvirt VM Host (iso-builder)

nixos2 hosts the iso-builder VM, which runs the `vm` branch of nixos-config and builds custom NixOS ISOs. Finished ISOs are written directly to `/mnt/nextcloud-data/isos/` via a virtiofs share, where they immediately appear on the `isos` Samba share.

**Status:** ENABLED — configured in `modules/vm.nix`

**VM management aliases:**
```bash
vmls     # List VMs and state
vmstart  # Start iso-builder
vmstop   # Graceful shutdown
vmkill   # Hard stop if hung
vminfo   # Domain info
vmssh    # SSH into the VM (auto-resolves DHCP address)
```

**ISO build workflow:**
```bash
vmstart                                          # Boot the VM
vmssh                                            # SSH in
cd /etc/nixos && sudo git pull && bash build-iso.sh
# ISO appears at \\nixos2\isos automatically
vmstop
```

**Services that need to be running on nixos2:**
```bash
systemctl status libvirtd                # QEMU/KVM hypervisor
systemctl status virtiofsd-iso-builder   # virtiofs shared filesystem
systemctl status libvirt-network-setup   # NAT network (virbr0)
systemctl status libvirt-pool-setup      # SSD storage pool
```

**See `docs/VM-SETUP.md` for initial setup, virtiofs XML edits, and disk/channel details.**

### Samba (Ports 139, 445)

Two shares on nixos2. Global Samba config (Apple extensions, workgroup, security) lives in `modules/services.nix`. The Time Machine share and its dedicated user live in `modules/timemachine.nix`. `samba-wsdd` (WS-Discovery) is in `services.nix`.

**Status:** ENABLED

**Shares:**

| Share | Path | Access |
|-------|------|--------|
| `isos` | `/mnt/nextcloud-data/isos` | LAN user `ppb1701` |
| `timemachine` | `/mnt/nextcloud-data/timemachine` | Samba user `tmuser` |

**ISO share:** `\\nixos2\isos` or `\\192.168.50.218\isos`
```bash
# Set Samba password for ppb1701 (one-time, survives rebuilds)
sudo smbpasswd -a ppb1701
```

**Time Machine share:** `\\nixos2\timemachine`
- Cap: 2TB (`fruit:time machine max size = 2000G`)
- Macros Time Machine discovers the share automatically via samba-wsdd (WS-Discovery)
- Or connect manually: **Finder → Go → Connect to Server → `smb://nixos2.local`**
- Authenticate with `tmuser` and the password set via `sudo smbpasswd -a tmuser`

**Firewall ports (already open in `modules/networking.nix`):**
- TCP: 139, 445 (Samba)
- UDP: 137, 138, 5353 (NetBIOS + WSDD/mDNS)

**Service management:**
```bash
systemctl status samba        # Samba daemon
systemctl status samba-wsdd   # WS-Discovery (Finder auto-discovery)
journalctl -u samba -f        # Samba logs
```

**Config split between files:**
- `modules/services.nix` — `settings.global`, `isos` share, `samba-wsdd`
- `modules/timemachine.nix` — `timemachine` share, `tmuser` user/group, directory via `systemd.tmpfiles`

**Note on nixos-unstable:** `services.samba.extraConfig` and `securityType` are removed on unstable. Use `settings.global` with `security = "user"` inside it. See `docs/TROUBLESHOOTING.md` for the migration details.

## Disabled Services (Failover-Ready)

These services are fully configured but disabled. They run on the primary server.

### Nextcloud

**Status:** DISABLED (runs on primary)

**To enable for failover:**
```bash
# 1. Edit services.nix
sudo micro /etc/nixos/modules/services.nix

# 2. Change:
services.nextcloud.enable = true;

# 3. Also enable PostgreSQL:
services.postgresql.enable = true;

# 4. Ensure mount point exists for data drive

# 5. Rebuild
sudo nixos-rebuild switch
```

### Vaultwarden

**Status:** DISABLED (runs on primary)

**To enable for failover:**
```bash
# 1. Edit services.nix
sudo micro /etc/nixos/modules/services.nix

# 2. Change:
services.vaultwarden.enable = true;

# 3. Configure secrets in /etc/nixos/private/vaultwarden.env

# 4. Rebuild
sudo nixos-rebuild switch

# 5. Update Tailscale Funnel to point to this server
sudo tailscale funnel --bg --https=443 http://127.0.0.1:8222
```

### SearX

**Status:** DISABLED (runs on primary)

**To enable for failover:**
```nix
services.searx.enable = true;
```

### Linkwarden

**Status:** DISABLED (runs on primary)

**To enable for failover:**
```bash
# 1. Remove 'enable = false;' from systemd.services.linkwarden
# 2. Enable PostgreSQL
# 3. Configure database password
# 4. Rebuild
```

### Collabora Online

**Status:** DISABLED (runs on primary with Nextcloud)

Collabora provides LibreOffice-based document editing within Nextcloud. It requires nixos-unstable channel.

**To enable for failover (enable together with Nextcloud):**
```bash
# 1. Edit services.nix
sudo micro /etc/nixos/modules/services.nix

# 2. Change:
services.collabora-online.enable = true;

# 3. Ensure Nextcloud is also enabled and running

# 4. Rebuild
sudo nixos-rebuild switch

# 5. Configure in Nextcloud admin:
#    Settings → Office → Use your own server → http://collabora.home
#    Allow list for WOPI requests → 127.0.0.1

# 6. Add DNS rewrite: collabora.home → YOUR_IP
```

**Note:** The systemd service name is `coolwsd`, not `collabora-online`. Use aliases: `cos` (status), `cor` (restart), `col` (logs).

See `docs/TROUBLESHOOTING.md` for Collabora-specific troubleshooting (SSL config quirks, WOPI errors, etc.)

### NoteDiscovery

**Status:** DISABLED (runs on primary)

**To enable for failover:**
```bash
# 1. Remove 'enable = false;' from systemd.services.notediscovery
# 2. Configure notes path in /etc/nixos/private/notediscovery-config.nix
# 3. Rebuild
```

### ntfy-sh

**Status:** DISABLED (runs on primary)

**To enable for failover:**
```nix
services.ntfy-sh.enable = true;
```

### PostgreSQL

**Status:** DISABLED

**Enable if running:** Nextcloud, Linkwarden

```nix
services.postgresql.enable = true;
```

## Service Management

### Check Service Status

```bash
# Gitea
systemctl status gitea
journalctl -u gitea -f

# AdGuard Home
systemctl status adguardhome

# Syncthing
systemctl status syncthing
```

### Shell Aliases

```bash
gts  # Gitea status
gtr  # Gitea restart
gtl  # Gitea logs

ags  # AdGuard status
agr  # AdGuard restart
agl  # AdGuard logs

sts  # Syncthing status
str  # Syncthing restart
stl  # Syncthing logs
```

## Failover Checklist

When primary server fails:

1. [ ] Verify Syncthing has latest data synced
2. [ ] Enable required services in services.nix
3. [ ] Configure/verify secrets
4. [ ] Rebuild: `sudo nixos-rebuild switch`
5. [ ] Update DNS rewrites in AdGuard Home
6. [ ] Update Tailscale Funnel if using Vaultwarden
7. [ ] Test services are working
8. [ ] Notify users of temporary server change

When returning to primary:

1. [ ] Sync any data changes back to primary
2. [ ] Disable failover services
3. [ ] Rebuild: `sudo nixos-rebuild switch`
4. [ ] Update DNS back to primary
5. [ ] Verify primary is working

## See Also

For detailed service documentation, see the primary server docs:
- [nixos-config/docs/SERVICES.md](https://github.com/ppb1701/nixos-config/blob/main/docs/SERVICES.md)
- [nixos-config/docs/NEXTCLOUD-SETUP.md](https://github.com/ppb1701/nixos-config/blob/main/docs/NEXTCLOUD-SETUP.md)
