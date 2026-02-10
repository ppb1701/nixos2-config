# Services Guide - NixOS2 Secondary Server

This guide covers the services on nixos2, the secondary/backup server.

## Server Role

**NIXOS2 is the secondary server with:**
- Gitea as the PRIMARY Git hosting server
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

### Tailscale

VPN mesh network for remote access.

**Status:** ENABLED

### Nginx (Port 80)

Reverse proxy for clean URLs.

**Status:** ENABLED

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
