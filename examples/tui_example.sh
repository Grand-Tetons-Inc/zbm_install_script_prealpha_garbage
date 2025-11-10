#!/bin/bash
################################################################################
# Example: Using the ZFSBootMenu TUI
#
# This demonstrates launching the interactive TUI installer
################################################################################

# Basic launch (requires root)
sudo ../zbm-tui.sh

# The TUI will guide you through:
#
# 1. Welcome Screen
#    - Shows system info
#    - EFI, RAM, CPU detection
#
# 2. Mode Selection
#    - New installation
#    - Migrate existing system
#
# 3. Device Selection
#    - Visual drive picker
#    - Shows size, model, type (SSD/HDD/NVMe)
#    - Multi-select with checkboxes
#
# 4. Settings Configuration
#    - RAID level (automatically validates drive count)
#    - Pool name and compression
#    - EFI and swap sizes
#    - Existing system options (if applicable)
#
# 5. Validation
#    - Checks all requirements
#    - Shows errors if any
#
# 6. Confirmation
#    - Summary of all settings
#    - Final warning before destructive operations
#
# 7. Installation
#    - Live progress viewer
#    - Real-time log scrolling
#    - Success/failure notification
#    - Option to reboot
#
################################################################################

# Tips:
#
# - Use arrow keys to navigate
# - Space bar to select/deselect
# - Tab to move between fields
# - Esc to go back
# - Enter to confirm
#
# The TUI uses the same backend as the CLI, so all safety
# features, validation, and /proc and /sys detection work
# identically!
