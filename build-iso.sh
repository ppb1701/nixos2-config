#!/usr/bin/env bash
set -e

echo "Building NixOS custom ISO..."
echo ""

# Build the ISO
nix-build '<nixpkgs/nixos>' \
  -A config.system.build.isoImage \
  -I nixos-config=./iso-config.nix \
  --log-format bar-with-logs \
  --option substituters "https://cache.nixos.org https://nix-community.cachix.org"

# Find the ISO
ISO_PATH=$(find result/iso -name "*.iso" | head -n 1)

if [ -z "$ISO_PATH" ]; then
    echo "Error: ISO not found in result/iso/"
    exit 1
fi

echo ""
echo "ISO built successfully!"
echo "Location: $ISO_PATH"
echo ""

if mountpoint -q /mnt/host-isos 2>/dev/null; then
    DEST="/mnt/host-isos/nixos-config-$(date +%Y%m%d-%H%M).iso"
    echo "Copying ISO to nixos2 share..."
    cp "$ISO_PATH" "$DEST"
    echo ""
    echo "Available via Samba:  \\\\nixos2\\isos\\$(basename $DEST)"
    echo "Available via path:   /mnt/nextcloud-data/isos/$(basename $DEST)"
else
    echo "Copy to Ventoy USB with:"
    echo "sudo cp $ISO_PATH /path/to/ventoy/"
    echo "Use Rufus to install the ISO to USB"
    echo "(Use dd image option)"
fi
