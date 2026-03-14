# Troubleshooting Guide - NixOS2

Common issues and solutions for the secondary server.

## Quick Diagnostics

```bash
# Check all service status
systemctl status gitea adguardhome syncthing tailscaled nginx

# Check open ports
ss -tlnp

# Check disk space
df -h

# Check memory
free -h
```

## Gitea Issues

### Web UI Not Accessible

```bash
# Check service status
systemctl status gitea

# View logs
journalctl -u gitea -f

# Check port binding
ss -tlnp | grep 3300

# Verify Nginx config
sudo nginx -t
```

### Repository Sync Issues

```bash
# Check git remote
cd /var/lib/gitea/repositories/USER/REPO.git
git remote -v

# Test push to GitHub
git push --mirror github
```

### Database Issues (SQLite)

```bash
# Check database file
ls -la /var/lib/gitea/data/gitea.db

# Verify permissions
sudo -u gitea sqlite3 /var/lib/gitea/data/gitea.db ".tables"
```

## AdGuard Home Issues

### DNS Not Working

```bash
# Check service
systemctl status adguardhome

# Test DNS locally
dig @127.0.0.1 google.com

# Check port 53
ss -ulnp | grep :53
```

### Web UI Not Accessible

```bash
# Check port 3000
ss -tlnp | grep 3000

# View logs
journalctl -u adguardhome -f
```

## Syncthing Issues

### Devices Not Connecting

```bash
# Check service
systemctl status syncthing

# View logs
journalctl -u syncthing -f

# Check firewall ports
ss -tlnp | grep 22000
ss -ulnp | grep 21027
```

### Files Not Syncing

1. Check web UI for sync status
2. Verify device IDs match
3. Check folder paths exist
4. Review conflict files (*.sync-conflict-*)

## Tailscale Issues

### Not Connected

```bash
# Check status
tailscale status

# Reconnect
sudo tailscale up

# View logs
journalctl -u tailscaled -f
```

## Failover Service Issues

### Service Won't Start After Enabling

1. Check all required secrets are configured
2. Verify dependencies are enabled (e.g., PostgreSQL for Nextcloud)
3. Check logs for specific errors:
   ```bash
   journalctl -u SERVICE_NAME -f
   ```

### PostgreSQL Connection Issues

```bash
# Check PostgreSQL is running
systemctl status postgresql

# Test connection
sudo -u postgres psql -c "SELECT 1;"

# Check databases exist
sudo -u postgres psql -c "\l"
```

## Network Issues

### Can't Reach Server

```bash
# Check IP address
ip addr show

# Check default route
ip route

# Test connectivity
ping 1.1.1.1
ping google.com
```

### Nginx Errors

```bash
# Test configuration
sudo nginx -t

# View error log
sudo tail -f /var/log/nginx/error.log

# Restart
sudo systemctl restart nginx
```

## Disk Space Issues

```bash
# Check usage
df -h

# Find large files
sudo du -sh /var/lib/* | sort -h

# Clean old generations
sudo nix-collect-garbage -d
sudo nix-store --optimize
```

## General Debugging

### View All Logs

```bash
# Recent system logs
journalctl -xe

# Follow all logs
journalctl -f

# Specific service
journalctl -u SERVICE_NAME -f
```

### Rebuild Issues

```bash
# Test configuration first
sudo nixos-rebuild test

# Build without switching
sudo nixos-rebuild build

# Rollback if needed
sudo nixos-rebuild switch --rollback
```

## ISO Build Issues

### Missing Modules Cause Install Failure (`is too short to be a valid store path`)

**Symptom:**
```
'nginx-virtualhosts.nix' is too short to be a valid store path
```
or the installed system fails to rebuild with a similar error after first boot.

**Cause:** `iso-config.nix` lists every module file explicitly in `environment.etc`. If a new module is added to the repo but not added to that list, it won't be on the ISO. Additionally, if a module uses a relative import like `./nginx-virtualhosts.nix` instead of an absolute path, Nix lazy evaluation silently skips it while the referencing service is disabled — but as soon as evaluation order changes, it blows up.

**Fix:**
1. Ensure every module in any imports block is also listed in `iso-config.nix`
2. Use absolute paths (`/etc/nixos/modules/...`) for all module imports in `services.nix` — not relative paths like `./modulename.nix`
3. Rebuild the ISO after fixing and test on a fresh VM

### Wrong Boot Config (`GRUB error: cannot find a GRUB drive`)

**Symptom:** `nixos-rebuild switch` fails with GRUB not finding `/dev/sda` on a UEFI machine.

**Cause:** `configuration-uefi.nix` has `boot-bios.nix` in its imports instead of `boot-uefi.nix` — a copy/paste error that's invisible until you try to rebuild.

**Fix:** Open `configuration-uefi.nix` and check the boot import:
```nix
# Wrong
"${modulesDir}/boot-bios.nix"

# Correct
"${modulesDir}/boot-uefi.nix"
```

## Samba Issues (nixos-unstable)

### `services.samba.extraConfig` and `securityType` No Longer Work

**Symptom:**
```
The option definition `services.samba.extraConfig' in `.../timemachine.nix'
no longer has any effect; please remove it.
Use services.samba.settings instead.
```

**Cause:** On nixos-unstable (circa 2025), `services.samba.extraConfig` was removed. `securityType` was also removed — security now lives inside `settings.global`.

**Fix:**
```nix
services.samba = {
  enable = true;
  settings = {
    global = {
      workgroup = "WORKGROUP";
      "server string" = "nixos2";
      "server role" = "standalone server";
      security = "user";
      "fruit:metadata" = "stream";
      "fruit:model" = "MacSamba";
      "fruit:posix_rename" = "yes";
      "fruit:veto_appledouble" = "no";
      "fruit:wipe_intentionally_left_blank_rfork" = "yes";
      "fruit:delete_empty_adfiles" = "yes";
    };
    isos = {
      path = "/mnt/nextcloud-data/isos";
      browseable = "yes";
      writable = "yes";
      "valid users" = "ppb1701";
    };
  };
};
```

The `timemachine` share lives in `timemachine.nix` — NixOS merges `settings` across modules as long as no attribute has conflicting values in both files.

### Duplicate Samba Share Attribute Conflict

**Symptom:**
```
error: The option `services.samba.settings.timemachine."fruit:time machine max size"'
has conflicting definition values
```

**Cause:** The same share was defined in two module files with different values.

**Fix:** Each share should be owned by exactly one file. `global` block + `isos` share + `samba-wsdd` live in `services.nix`. The `timemachine` share + `tmuser` + directory live in `timemachine.nix`.

## NixOS Unstable Channel (Required by Collabora)

### Why Unstable?

The `collabora-online` NixOS module is only available on the **nixos-unstable** channel. Adding Collabora required switching from stable to unstable, which means the entire system pulls packages from the unstable branch.

**Current channel setup:**
```bash
# Check your channels
sudo nix-channel --list

# Expected output:
# nixos https://nixos.org/channels/nixos-unstable
# home-manager https://github.com/nix-community/home-manager/archive/master.tar.gz
```

**Important:** When running unstable, the Home Manager channel must use `master` (not a release branch like `release-25.05`).

### Risks of Running Unstable

- Packages update more frequently and may introduce regressions
- Services may change configuration options between updates
- `nixos-rebuild switch` can occasionally hang during service activation after large updates — a hard reboot resolves this, all services come up clean on next boot
- Redis (a Nextcloud dependency) has stopped unexpectedly after system updates — if Nextcloud goes down, check Redis first: `sudo systemctl start redis-nextcloud`

### Partially Stabilizing an Unstable System

If a specific package breaks on unstable, you can pin individual packages to a known-good nixpkgs commit:

```nix
# In configuration.nix or a module file
let
  # Pin to a specific nixpkgs commit where the package works
  pinnedPkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/COMMIT_HASH.tar.gz";
    sha256 = "SHA256_HASH";
  }) { config.allowUnfree = true; };
in
{
  # Use the pinned version of a specific package
  environment.systemPackages = [
    pinnedPkgs.some-broken-package  # Pinned to stable commit
    pkgs.everything-else            # From unstable channel
  ];
}
```

**Finding a good commit to pin to:**
1. Go to https://github.com/NixOS/nixpkgs/commits/nixos-unstable
2. Find a commit from before the breakage
3. Use its full hash in the `fetchTarball` URL
4. Get the sha256 by setting it to `""` first, then copying from the error message

### Safe Rebuild Practices on Unstable

The `rebuild-safe` alias handles the case where `nixos-rebuild switch` hangs on service activation:

```bash
rebuild-safe  # Rebuilds, auto-reboots if activation hangs
```

Before major channel updates:
```bash
# Update channels
sudo nix-channel --update

# Test build first (doesn't activate)
sudo nixos-rebuild build

# If build succeeds, switch
sudo nixos-rebuild switch

# If switch hangs, hard reboot — services will start cleanly
```

### Reverting to a Previous Generation

If an update breaks things badly:
```bash
# List available generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Roll back to previous generation
sudo nixos-rebuild switch --rollback

# Or use the alias
rollback
```

You can also select a previous generation from the boot menu (GRUB/systemd-boot) if the system won't start.

## Collabora Online Issues

### Service Name is `coolwsd`, Not `collabora-online`

The systemd service is named `coolwsd.service`, not `collabora-online.service`:

```bash
# Correct
sudo systemctl status coolwsd
sudo journalctl -u coolwsd -f

# Wrong — this won't find anything
sudo systemctl status collabora-online
```

### 502 Bad Gateway from Nginx

**Root cause:** Coolwsd starts with SSL enabled despite the NixOS config setting `ssl.enable = false`.

The NixOS module generates XML config, and coolwsd has both XML **attributes** and **inner element values** for SSL settings. Both must be explicitly set to false:

```nix
settings = {
  # XML attributes (what NixOS module primarily sets)
  ssl."@enable" = false;
  ssl."@termination" = false;
  # Inner element values (what coolwsd actually reads)
  ssl.enable = false;
  ssl.termination = false;
};
```

**Diagnosis:**
```bash
# Find the actual config file coolwsd is using
sudo cat /proc/$(pgrep -f coolwsd | head -1)/cmdline | tr '\0' ' '

# Check what SSL settings are in the generated config
sudo grep -A3 "termination\|ssl enable" /nix/store/<hash>-coolwsd.xml
```

### Discovery URLs Serving HTTPS Instead of HTTP

If documents fail to load and the discovery endpoint returns HTTPS URLs:

```bash
# Check discovery URLs (should show http://, not https://)
curl -s http://127.0.0.1:9980/hosting/discovery | grep -o 'src="[^"]*"' | head -3
```

**Fix:** Add `server_name` to the Collabora settings:
```nix
settings = {
  server_name = "collabora.home";
  # ... other settings
};
```

### Unauthorized WOPI Host Errors

Two separate issues can cause the same "Unauthorized WOPI host" error:

**1. Coolwsd side — alias_groups mode:**

The default `mode="first"` only allows one host pattern. Change to `"groups"`:
```nix
storage.wopi.alias_groups."@mode" = "groups";
storage.wopi.host = [ "cloud\\.home" "127\\.0\\.0\\.1" ];
```

**2. Nextcloud side — WOPI allow-list IP:**

Coolwsd connects to Nextcloud from **loopback** (`127.0.0.1`), NOT from the server's LAN IP. In Nextcloud admin:
- Settings → Office → Allow list for WOPI requests → `127.0.0.1`

### Redis Stops After System Update (Takes Nextcloud Down)

Redis is a dependency of Nextcloud. If Redis stops, Nextcloud stops working:

```bash
# Check if Redis is running
sudo systemctl status redis-nextcloud

# Restart Redis (Nextcloud will recover automatically)
sudo systemctl start redis-nextcloud

# Check Nextcloud is back
sudo systemctl status phpfpm-nextcloud
```

### Useful Collabora Debug Commands

```bash
# Service status and logs
sudo systemctl status coolwsd
sudo journalctl -u coolwsd -f --no-pager

# Check config file path
sudo cat /proc/$(pgrep -f coolwsd | head -1)/cmdline | tr '\0' ' '

# Verify discovery endpoint (URLs should be http://)
curl -s http://127.0.0.1:9980/hosting/discovery | grep -o 'src="[^"]*"' | head -3

# Check coolwsd is listening on port 9980
sudo ss -tulpn | grep 9980

# Watch WOPI-related logs
sudo journalctl -u coolwsd -f --no-pager | grep -i "wopi\|unauth\|host"

# Clear cached Nextcloud Office config (nuclear option)
sudo nextcloud-occ config:app:delete richdocuments wopi_url
sudo nextcloud-occ config:app:delete richdocuments public_wopi_url
```

## See Also

For more detailed troubleshooting, see:
- [nixos-config/docs/TROUBLESHOOTING.md](https://github.com/ppb1701/nixos-config/blob/main/docs/TROUBLESHOOTING.md)
