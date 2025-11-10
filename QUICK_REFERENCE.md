# ZFSBootMenu Installation Quick Reference

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/Grand-Tetons-Inc/zbm_install_script_prealpha_garbage.git
cd zbm_install_script_prealpha_garbage

# 2. Make executable
chmod +x zbm_install.sh

# 3. Run with desired options (as root)
sudo ./zbm_install.sh -m new -d sda
```

## Common Commands

### Single Drive
```bash
sudo ./zbm_install.sh -m new -d sda
```

### Mirrored Drives (RAID1)
```bash
sudo ./zbm_install.sh -m new -d sda,sdb -r mirror
```

### RAIDZ1 (3+ drives)
```bash
sudo ./zbm_install.sh -m new -d sda,sdb,sdc -r raidz1
```

### Custom Configuration
```bash
sudo ./zbm_install.sh -m new -d sda,sdb -r mirror -p mytank -e 512M -s 16G
```

### Advanced Configuration (SSD with zstd compression)
```bash
sudo ./zbm_install.sh -m new -d nvme0n1 -a 12 -c zstd -s 16G -v
```

### No Swap Installation
```bash
sudo ./zbm_install.sh -m new -d sda -s 0
```

### Test Without Changes (Dry Run)
```bash
sudo ./zbm_install.sh -m new -d sda,sdb -r mirror --dry-run
```

### Verbose Mode (for debugging)
```bash
sudo ./zbm_install.sh -m new -d sda -v
```

## Option Reference

### Required Options
| Option | Values | Description |
|--------|--------|-------------|
| `-m, --mode` | `new`, `existing` | Installation mode |
| `-d, --drives` | `sda`, `sda,sdb`, etc. | Comma-separated drive list |

### Storage Configuration
| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `-p, --pool` | Any string | `zroot` | ZFS pool name |
| `-r, --raid` | `none`, `mirror`, `raidz1`, `raidz2`, `raidz3` | `none` | RAID level |
| `-e, --efi-size` | `512M`, `1G`, etc. | `1G` | EFI partition size |
| `-s, --swap-size` | `8G`, `16G`, `0` | `8G` | Swap size (0=disable) |

### ZFS Tuning
| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `-a, --ashift` | `9-16` | auto-detect | ZFS block alignment (9=512B, 12=4K, 13=8K) |
| `-c, --compression` | `zstd`, `lz4`, `lzjb`, `gzip`, `off` | `zstd` | Compression algorithm |

### System Configuration
| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `-H, --hostname` | Any string | - | Set hostname for new installation |
| `-l, --log-file` | File path | `/var/log/zbm_install.log` | Custom log file location |

### Execution Control
| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `-n, --dry-run` | flag | `false` | Test mode (no changes) |
| `-f, --force` | flag | `false` | Skip confirmations |
| `-v, --verbose` | flag | `false` | Enable verbose output |
| `-S, --skip-preflight` | flag | `false` | Skip pre-flight checks (not recommended) |
| `-B, --no-backup` | flag | `false` | Don't backup existing configuration |
| `-h, --help` | flag | - | Show help message |

## RAID Requirements

| RAID Level | Min Drives | Redundancy | Description |
|------------|------------|------------|-------------|
| `none` | 1 | None | Single drive |
| `mirror` | 2+ | N-1 drives | Full mirroring |
| `raidz1` | 3+ | 1 drive | RAID5-like |
| `raidz2` | 4+ | 2 drives | RAID6-like |
| `raidz3` | 5+ | 3 drives | Triple parity |

## Pre-Installation Checklist

- [ ] Backup all important data
- [ ] Identify target drive(s) with `lsblk`
- [ ] Verify system is EFI (check `/sys/firmware/efi` exists)
- [ ] Ensure sufficient RAM (minimum 2GB)
- [ ] Verify sufficient disk space (minimum 8GB per drive)
- [ ] Ensure system has network access
- [ ] Test with `--dry-run` first
- [ ] Understand that target drives will be COMPLETELY WIPED

## Post-Installation

1. Verify installation:
   ```bash
   zpool status
   zfs list
   ```

2. Check boot configuration:
   ```bash
   ls -l /boot/efi/EFI/zbm/
   bootctl status  # or: efibootmgr
   ```

3. Reboot system:
   ```bash
   reboot
   ```

4. At boot, select ZFSBootMenu

## Troubleshooting

### Check logs
```bash
cat /var/log/zbm_install.log
# or
cat /tmp/zbm_install.log
```

### View disk layout
```bash
lsblk
fdisk -l
```

### Check ZFS status
```bash
zpool status
zfs list
```

### Verify EFI boot
```bash
efibootmgr -v
ls -l /boot/efi/EFI/
```

## Example Workflow

```bash
# 1. Check system requirements
cat /proc/meminfo | grep MemTotal
ls /sys/firmware/efi  # Verify EFI system

# 2. Check available disks
lsblk
ls -l /sys/block/  # See all block devices

# 3. Test configuration (dry run)
sudo ./zbm_install.sh -m new -d sda,sdb -r mirror --dry-run -v

# 4. Run actual installation
sudo ./zbm_install.sh -m new -d sda,sdb -r mirror -v

# 5. Verify after installation
zpool status zroot
zfs list -r zroot
cat /var/log/zbm_install.log  # Check logs

# 6. Reboot
sudo reboot
```

## Advanced Examples

### High-Performance SSD Setup
```bash
# NVMe SSD with optimal settings
sudo ./zbm_install.sh \
  -m new \
  -d nvme0n1,nvme1n1 \
  -r mirror \
  -a 12 \
  -c zstd \
  -s 32G \
  -H myserver \
  -v
```

### Minimal Installation (No Swap)
```bash
# Single drive, no swap, smaller EFI
sudo ./zbm_install.sh \
  -m new \
  -d sda \
  -e 512M \
  -s 0 \
  -c lz4
```

### RAIDZ2 for Data Integrity
```bash
# 6-drive RAIDZ2 (can lose 2 drives)
sudo ./zbm_install.sh \
  -m new \
  -d sda,sdb,sdc,sdd,sde,sdf \
  -r raidz2 \
  -c zstd \
  -v
```

## Need Help?

- Read full documentation: `README.md`
- Check examples: `examples/` directory
- Review logs: `/var/log/zbm_install.log`
- Visit: https://docs.zfsbootmenu.org/

## Safety Tips

⚠️ **ALWAYS:**
- Backup data before installation
- Test in VM first
- Use `--dry-run` to preview
- Verify drive names with `lsblk`
- Double-check RAID configuration

❌ **NEVER:**
- Run on production without backup
- Use wrong drive identifiers
- Interrupt installation process
- Ignore error messages
