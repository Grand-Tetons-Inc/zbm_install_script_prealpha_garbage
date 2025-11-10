# ZFSBootMenu TUI (Text User Interface)

Beautiful, interactive installer for ZFSBootMenu using dialog-based TUI (with future notcurses support).

## Features

- 🎨 **Interactive Device Selection** - Visual drive picker with size/model/type info
- ⚙️ **Guided Configuration** - Step-by-step settings with validation
- 🔍 **Pre-flight Validation** - Checks configuration before installation
- 📊 **Live Progress Monitoring** - Real-time installation log viewer
- 🛡️ **Safety Confirmations** - Multiple confirmation steps for destructive operations
- 🚀 **Powered by Dialog** - Works everywhere, notcurses support coming soon

## Requirements

### Current (Dialog-based)
```bash
# Debian/Ubuntu
sudo apt-get install dialog

# Fedora
sudo dnf install dialog
```

### Future (Notcurses - for advanced UI)
```bash
# Debian/Ubuntu
sudo apt-get install libnotcurses-dev notcurses-bin

# Fedora
sudo dnf install notcurses-devel notcurses
```

## Usage

### Launch TUI
```bash
sudo ./zbm-tui.sh
```

### Navigation
- **Arrow Keys**: Navigate menus and options
- **Space**: Select/deselect items in checklists
- **Enter**: Confirm selection
- **Tab**: Move between form fields
- **Esc**: Go back / Cancel

## Workflow

The TUI guides you through a 7-step process:

### 1. Welcome Screen
- Shows system information (RAM, CPU, EFI status)
- Displays compatibility check results

### 2. Mode Selection
```
[ ] New Installation
    - Fresh ZFS install on empty drives
    - All data will be destroyed

[ ] Migrate Existing System
    - Copy running system to ZFS
    - Preserves your current setup
```

### 3. Device Selection
```
Select one or more drives:

[X] sda (512GB Samsung SSD) - SSD
[X] sdb (512GB Samsung SSD) - SSD
[ ] sdc (2TB WD HDD) - HDD
[ ] nvme0n1 (1TB Samsung NVMe) - NVMe
```

### 4. Settings Configuration
```
Configuration Menu:
  1. RAID Level
  2. Pool & Compression Settings
  3. Existing System Options
  4. Continue to Validation
```

#### RAID Level Selection
- **none** - Single drive (no redundancy)
- **mirror** - RAID1 mirroring (2+ drives)
- **raidz1** - RAID5-like (3+ drives, lose 1)
- **raidz2** - RAID6-like (4+ drives, lose 2)
- **raidz3** - Triple parity (5+ drives, lose 3)

#### Pool & Compression Settings
- Pool Name (default: `zroot`)
- Compression: `zstd`, `lz4`, `lzjb`, `gzip`, `off`
- EFI Size (default: `1G`)
- Swap Size (default: `8G`, `0` to disable)
- Hostname (optional)

#### Existing System Options
*Only available in "existing" mode*
- Toggle copy home directories
- Add custom exclusion paths
- View current exclusions

### 5. Validation
Checks for:
- ✅ Installation mode selected
- ✅ At least one drive selected
- ✅ RAID level compatible with drive count
- ✅ EFI system detected
- ✅ Sufficient RAM (2GB minimum)
- ✅ Sufficient disk space (8GB minimum per drive)

### 6. Confirmation
Shows complete configuration summary with warnings:
```
Configuration Summary:
  Mode: existing
  Pool: zroot
  RAID: mirror
  Drives: sda, sdb
  Compression: zstd

WARNING: ALL DATA ON THE FOLLOWING DRIVES WILL BE DESTROYED:
  - /dev/sda
  - /dev/sdb

Are you ABSOLUTELY SURE?
```

### 7. Installation
- Builds CLI command from TUI settings
- Executes `zbm_install.sh` backend
- Shows live log viewer (scrolling)
- Displays success/failure message
- Offers reboot option

## Architecture

```
zbm-tui.sh                    # Main TUI entry point
├── tui/lib/
│   ├── notcurses_wrapper.sh  # Dialog/notcurses abstraction
│   ├── tui_state.sh          # State management (/proc and /sys detection)
│   ├── tui_widgets.sh        # Reusable UI components
│   └── tui_screens.sh        # Screen implementations
└── zbm_install.sh            # Backend CLI (unchanged)
```

## Key Features

### Uses /proc and /sys for Detection
Just like the CLI, the TUI uses kernel interfaces directly:
- `/proc/meminfo` - Memory detection
- `/proc/cpuinfo` - CPU count
- `/proc/mounts` - Mount point checking
- `/sys/firmware/efi` - EFI detection
- `/sys/block/*` - Block device information
- `/sys/block/*/queue/*` - Drive characteristics

### State Management
All configuration is stored in associative arrays:
```bash
TUI_CONFIG[mode]="existing"
TUI_CONFIG[pool_name]="zroot"
TUI_CONFIG[raid_level]="mirror"
TUI_CONFIG[compression]="zstd"
SELECTED_DRIVES=(sda sdb)
EXCLUDE_PATHS=(/home/*/Downloads /var/cache)
```

### Backend Integration
The TUI builds and executes CLI commands:
```bash
./zbm_install.sh \
  --mode existing \
  --drives sda,sdb \
  --raid mirror \
  --compression zstd \
  --verbose
```

## Examples

### Fresh Install on Mirrored SSDs
1. Launch: `sudo ./zbm-tui.sh`
2. Select: "New Installation"
3. Choose: `sda` and `sdb` (both SSDs)
4. Set RAID: `mirror`
5. Configure: `zstd` compression
6. Validate and confirm
7. Install!

### Migrate Existing System
1. Launch: `sudo ./zbm-tui.sh`
2. Select: "Migrate Existing System"
3. Choose target drive(s)
4. Set RAID level
5. Configure exclusions:
   - Add: `/home/*/Downloads`
   - Add: `/var/cache`
6. Toggle: "Copy Home: false"
7. Validate and confirm
8. Migrate!

## Advantages Over CLI

### For New Users
- ✅ No need to remember flags
- ✅ Visual drive selection
- ✅ Inline validation
- ✅ Step-by-step guidance
- ✅ Can't accidentally skip important steps

### For Power Users
- ✅ Faster than typing long commands
- ✅ Visual confirmation of config
- ✅ Live log monitoring
- ✅ Can still use CLI for automation

## Future Enhancements (Notcurses)

When notcurses support is added, the TUI will feature:
- 🎨 24-bit true color
- 📊 Real-time graphs (CPU, disk I/O)
- 🔥 Animated progress bars
- 📈 Live bandwidth monitoring
- 🖱️ Mouse support
- 🎬 Smooth animations
- 📸 Screenshots/logos

## Troubleshooting

### Dialog Not Found
```bash
sudo apt-get install dialog  # Debian/Ubuntu
sudo dnf install dialog       # Fedora
```

### TUI Crashes/Garbled
```bash
# Reset terminal
reset

# Check terminal size (minimum 80x24)
echo $COLUMNS $LINES

# Try different terminal emulator
# - xterm
# - gnome-terminal
# - konsole
```

### Installation Fails
Check the log file shown in error message:
```bash
tail -f /tmp/zbm_install_tui_*.log
```

## Development

### Testing Without Installation
Use dry-run mode in the CLI backend:
```bash
# Edit tui/lib/tui_state.sh
# Add to build_cli_command():
cmd+=" --dry-run"
```

### Adding New Screens
1. Add screen function to `tui/lib/tui_screens.sh`
2. Add navigation logic to main loop in `zbm-tui.sh`
3. Update `CURRENT_SCREEN` transitions

### Adding New Widgets
1. Add widget function to `tui/lib/tui_widgets.sh`
2. Call from screen functions
3. Update state in `tui/lib/tui_state.sh`

## Contributing

When adding TUI features:
1. Keep backend (CLI) unchanged - it's the source of truth
2. Use dialog wrappers from `notcurses_wrapper.sh`
3. Update `TUI_CONFIG` state
4. Build CLI command in `build_cli_command()`
5. Test with dry-run first

## License

MIT License - Same as main project

## Credits

- Dialog: Thomas E. Dickey
- Notcurses (future): Nick Black (@dankamongmen)
- ZFSBootMenu: zbm-dev team
