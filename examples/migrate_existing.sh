#!/bin/bash
################################################################################
# Example: Migrate existing system to ZFS
#
# This example demonstrates migrating a running system to a new ZFS
# installation with ZFSBootMenu
#
# ⚠️ WARNING: Make sure you have backups before running this!
################################################################################

# Example 1: Basic migration to single drive
# Copies entire system including home directories
sudo ./zbm_install.sh \
  --mode existing \
  --drives sda \
  --pool zroot \
  --compression zstd \
  --verbose

# Example 2: Migration to mirrored drives
# Best for production systems needing redundancy
sudo ./zbm_install.sh \
  --mode existing \
  --drives sda,sdb \
  --raid mirror \
  --compression zstd \
  --hostname myserver \
  --verbose

# Example 3: Migration excluding large directories
# Useful when you don't want to copy downloads, caches, etc.
sudo ./zbm_install.sh \
  --mode existing \
  --drives nvme0n1 \
  --exclude /home/*/Downloads \
  --exclude /home/*/Videos \
  --exclude /var/cache \
  --exclude /var/tmp \
  --compression zstd \
  --verbose

# Example 4: Server migration without home directories
# For servers where /home will be mounted separately
sudo ./zbm_install.sh \
  --mode existing \
  --drives sda,sdb,sdc \
  --raid raidz1 \
  --no-copy-home \
  --compression lz4 \
  --hostname prodserver \
  --verbose

# Example 5: Dry run to see what would be copied
# Always test first!
sudo ./zbm_install.sh \
  --mode existing \
  --drives sda,sdb \
  --raid mirror \
  --dry-run \
  --verbose

################################################################################
# What gets excluded by default:
#
# - /dev/*           (device files)
# - /proc/*          (process information)
# - /sys/*           (system information)
# - /tmp/*           (temporary files)
# - /run/*           (runtime data)
# - /mnt/*           (mount points)
# - /media/*         (removable media)
# - /lost+found      (fsck recovery)
# - /boot/efi/*      (will be recreated)
# - /var/tmp/*       (temporary files)
# - /var/cache/*     (cache files)
# - Swap files
# - Docker overlay2 storage
#
# Additional exclusions can be added with --exclude
################################################################################

# Note: Replace drive identifiers (sda, sdb, etc.) with your actual drives
# Use 'lsblk' to identify your drives
