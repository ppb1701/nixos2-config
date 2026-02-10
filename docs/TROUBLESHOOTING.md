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

## See Also

For more detailed troubleshooting, see:
- [nixos-config/docs/TROUBLESHOOTING.md](https://github.com/ppb1701/nixos-config/blob/main/docs/TROUBLESHOOTING.md)
