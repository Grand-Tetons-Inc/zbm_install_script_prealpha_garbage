#!/usr/bin/env python3
"""
ZFSBootMenu Notcurses UI Components

Beautiful UI components using notcurses for rich terminal graphics.
"""

import time
from typing import Dict, List, Any, Optional, Tuple
from notcurses import Notcurses, Plane, NCAlign


class BaseScreen:
    """Base class for all screens"""

    def __init__(self, nc: Notcurses):
        self.nc = nc
        self.stdplane = nc.stdplane()
        self.width = self.stdplane.dim_x()
        self.height = self.stdplane.dim_y()

    def clear(self):
        """Clear the screen"""
        self.stdplane.erase()

    def render(self):
        """Render the screen"""
        self.nc.render()

    def draw_box(self, y: int, x: int, height: int, width: int, title: str = ""):
        """Draw a box with optional title"""
        # Draw corners and borders using box-drawing characters
        self.stdplane.putstr_yx(y, x, "╔" + "═" * (width - 2) + "╗")
        for i in range(1, height - 1):
            self.stdplane.putstr_yx(y + i, x, "║")
            self.stdplane.putstr_yx(y + i, x + width - 1, "║")
        self.stdplane.putstr_yx(y + height - 1, x, "╚" + "═" * (width - 2) + "╝")

        # Draw title if provided
        if title:
            title_str = f"  {title}  "
            title_x = x + (width - len(title_str)) // 2
            self.stdplane.putstr_yx(y, title_x, title_str)

    def draw_centered_text(self, y: int, text: str, color: int = 0xffffff):
        """Draw centered text"""
        x = (self.width - len(text)) // 2
        self.stdplane.set_fg_rgb8(color >> 16, (color >> 8) & 0xff, color & 0xff)
        self.stdplane.putstr_yx(y, x, text)
        self.stdplane.set_fg_default()

    def wait_for_key(self) -> str:
        """Wait for a key press"""
        ev = self.nc.getc_blocking()
        if ev.is_release:
            return ""
        return ev.id if hasattr(ev, 'id') else ""


class WelcomeScreen(BaseScreen):
    """Welcome screen with system information"""

    def __init__(self, nc: Notcurses, system_info: Dict[str, Any]):
        super().__init__(nc)
        self.system_info = system_info

    def show(self) -> str:
        """Show welcome screen"""
        self.clear()

        # Title
        y = 2
        self.draw_centered_text(y, "╔═══════════════════════════════════════════════════════════╗", 0x00ff00)
        y += 1
        self.draw_centered_text(y, "║        ZFSBootMenu Installation - Notcurses TUI          ║", 0x00ff00)
        y += 1
        self.draw_centered_text(y, "╚═══════════════════════════════════════════════════════════╝", 0x00ff00)

        # System information box
        y += 2
        box_y = y
        box_height = 12
        box_width = 60
        box_x = (self.width - box_width) // 2

        self.draw_box(box_y, box_x, box_height, box_width, "System Information")

        # Display system info
        y = box_y + 2
        info_x = box_x + 4

        is_efi = self.system_info.get("is_efi", False)
        efi_str = "✓ Yes" if is_efi else "✗ No (BIOS not supported!)"
        efi_color = 0x00ff00 if is_efi else 0xff0000

        self.stdplane.putstr_yx(y, info_x, "EFI System:  ")
        self.stdplane.set_fg_rgb8(efi_color >> 16, (efi_color >> 8) & 0xff, efi_color & 0xff)
        self.stdplane.putstr(efi_str)
        self.stdplane.set_fg_default()

        y += 1
        ram_gb = self.system_info.get("ram_gb", 0)
        ram_ok = ram_gb >= 2
        ram_color = 0x00ff00 if ram_ok else 0xff0000
        self.stdplane.putstr_yx(y, info_x, f"RAM:         ")
        self.stdplane.set_fg_rgb8(ram_color >> 16, (ram_color >> 8) & 0xff, ram_color & 0xff)
        self.stdplane.putstr(f"{ram_gb} GB")
        self.stdplane.set_fg_default()

        y += 1
        cpu_count = self.system_info.get("cpu_count", 0)
        self.stdplane.putstr_yx(y, info_x, f"CPU Cores:   {cpu_count}")

        y += 1
        distro = self.system_info.get("distro", "Unknown")
        version = self.system_info.get("distro_version", "")
        self.stdplane.putstr_yx(y, info_x, f"Distro:      {distro} {version}")

        # Instructions
        y = box_y + box_height + 2
        self.draw_centered_text(y, "This installer will guide you through ZFS installation", 0xaaaaaa)
        y += 1
        self.draw_centered_text(y, "with support for RAID, compression, and system migration", 0xaaaaaa)

        # Controls
        y = self.height - 4
        self.draw_centered_text(y, "─" * 60, 0x666666)
        y += 1
        self.draw_centered_text(y, "[ENTER] Continue    [Q] Quit", 0x00ffff)

        self.render()

        # Wait for input
        while True:
            key = self.wait_for_key()
            if key in ('\n', '\r', ' '):
                return "next"
            elif key.lower() == 'q':
                return "quit"


class ModeSelectionScreen(BaseScreen):
    """Installation mode selection"""

    def __init__(self, nc: Notcurses):
        super().__init__(nc)
        self.selected = 0
        self.modes = [
            ("new", "New Installation", "Install ZFS on empty drives (DESTROYS data)"),
            ("existing", "Migrate System", "Copy running system to new ZFS installation")
        ]

    def show(self) -> str:
        """Show mode selection"""
        while True:
            self.clear()

            # Title
            y = 2
            self.draw_centered_text(y, "═══ Select Installation Mode ═══", 0x00ff00)

            # Mode options
            y += 4
            box_width = 70
            box_height = 8
            box_x = (self.width - box_width) // 2

            for i, (mode_id, mode_name, mode_desc) in enumerate(self.modes):
                # Highlight selected
                if i == self.selected:
                    color = 0x00ffff
                    prefix = "►"
                else:
                    color = 0xffffff
                    prefix = " "

                mode_y = y + (i * 4)
                self.stdplane.set_fg_rgb8(color >> 16, (color >> 8) & 0xff, color & 0xff)
                self.stdplane.putstr_yx(mode_y, box_x, f"{prefix} {mode_name}")
                self.stdplane.set_fg_default()

                self.stdplane.set_fg_rgb8(0xaa, 0xaa, 0xaa)
                self.stdplane.putstr_yx(mode_y + 1, box_x + 4, mode_desc)
                self.stdplane.set_fg_default()

            # Controls
            y = self.height - 4
            self.draw_centered_text(y, "─" * 60, 0x666666)
            y += 1
            self.draw_centered_text(y, "[↑/↓] Navigate  [ENTER] Select  [ESC] Back  [Q] Quit", 0x00ffff)

            self.render()

            # Handle input
            key = self.wait_for_key()

            if key == '\n' or key == '\r':
                return self.modes[self.selected][0]
            elif key in ('j', 'down'):
                self.selected = (self.selected + 1) % len(self.modes)
            elif key in ('k', 'up'):
                self.selected = (self.selected - 1) % len(self.modes)
            elif key == 'escape':
                return "back"
            elif key.lower() == 'q':
                return "quit"


class DeviceSelectionScreen(BaseScreen):
    """Device selection with checkbox list"""

    def __init__(self, nc: Notcurses, devices: Dict[str, Any], selected_drives: List[str]):
        super().__init__(nc)
        self.devices = devices
        self.selected_drives = set(selected_drives)
        self.cursor = 0
        self.device_list = sorted(devices.keys())

    def format_size(self, size_bytes: int) -> str:
        """Format size in human-readable form"""
        gb = size_bytes // (1024**3)
        if gb > 1024:
            return f"{gb // 1024}TB"
        return f"{gb}GB"

    def show(self) -> Any:
        """Show device selection"""
        while True:
            self.clear()

            # Title
            y = 2
            self.draw_centered_text(y, "═══ Select Target Drives ═══", 0x00ff00)
            y += 1
            self.draw_centered_text(y, "⚠ WARNING: Selected drives will be WIPED! ⚠", 0xff0000)

            # Device list
            y += 3
            if not self.device_list:
                self.draw_centered_text(y, "No drives detected!", 0xff0000)
            else:
                for i, dev in enumerate(self.device_list):
                    dev_info = self.devices[dev]
                    size_str = self.format_size(dev_info["size_bytes"])
                    model = dev_info["model"]
                    dev_type = dev_info["type"]

                    # Highlight cursor position
                    if i == self.cursor:
                        color = 0x00ffff
                        cursor = "►"
                    else:
                        color = 0xffffff
                        cursor = " "

                    # Checkbox
                    checked = "☑" if dev in self.selected_drives else "☐"

                    line = f"{cursor} {checked} {dev:<12} ({size_str:>6}  {model[:20]:<20}  {dev_type})"
                    x = (self.width - len(line)) // 2

                    self.stdplane.set_fg_rgb8(color >> 16, (color >> 8) & 0xff, color & 0xff)
                    self.stdplane.putstr_yx(y + i, x, line)
                    self.stdplane.set_fg_default()

            # Selected count
            y = self.height - 7
            count_text = f"Selected: {len(self.selected_drives)} drive(s)"
            self.draw_centered_text(y, count_text, 0x00ff00)

            # Controls
            y = self.height - 4
            self.draw_centered_text(y, "─" * 80, 0x666666)
            y += 1
            self.draw_centered_text(y, "[↑/↓] Navigate  [SPACE] Toggle  [ENTER] Continue  [ESC] Back  [Q] Quit", 0x00ffff)

            self.render()

            # Handle input
            key = self.wait_for_key()

            if key == '\n' or key == '\r':
                if len(self.selected_drives) > 0:
                    return list(self.selected_drives)
            elif key == ' ':
                if self.device_list:
                    dev = self.device_list[self.cursor]
                    if dev in self.selected_drives:
                        self.selected_drives.remove(dev)
                    else:
                        self.selected_drives.add(dev)
            elif key in ('j', 'down'):
                if self.device_list:
                    self.cursor = (self.cursor + 1) % len(self.device_list)
            elif key in ('k', 'up'):
                if self.device_list:
                    self.cursor = (self.cursor - 1) % len(self.device_list)
            elif key == 'escape':
                return "back"
            elif key.lower() == 'q':
                return "quit"


# Placeholder screens (to be implemented)
class SettingsScreen(BaseScreen):
    def __init__(self, nc, state):
        super().__init__(nc)
        self.state = state

    def show(self):
        self.clear()
        self.draw_centered_text(5, "Settings Screen - Coming Soon!", 0x00ff00)
        self.draw_centered_text(self.height - 3, "[ENTER] Continue  [ESC] Back", 0x00ffff)
        self.render()

        while True:
            key = self.wait_for_key()
            if key in ('\n', '\r'):
                return "next"
            elif key == 'escape':
                return "back"
            elif key.lower() == 'q':
                return "quit"


class ValidationScreen(BaseScreen):
    def __init__(self, nc, state, system_info):
        super().__init__(nc)
        self.state = state
        self.system_info = system_info

    def show(self):
        self.clear()
        self.draw_centered_text(5, "Validation Screen - Coming Soon!", 0x00ff00)
        self.draw_centered_text(self.height - 3, "[ENTER] Continue  [ESC] Back", 0x00ffff)
        self.render()

        while True:
            key = self.wait_for_key()
            if key in ('\n', '\r'):
                return "valid"
            elif key == 'escape':
                return "back"
            elif key.lower() == 'q':
                return "quit"


class ConfirmationScreen(BaseScreen):
    def __init__(self, nc, state):
        super().__init__(nc)
        self.state = state

    def show(self):
        self.clear()
        self.draw_centered_text(5, "Confirmation Screen - Coming Soon!", 0x00ff00)
        self.draw_centered_text(self.height - 3, "[Y] Proceed  [N] Back", 0x00ffff)
        self.render()

        while True:
            key = self.wait_for_key()
            if key.lower() == 'y':
                return "proceed"
            elif key.lower() == 'n' or key == 'escape':
                return "back"
            elif key.lower() == 'q':
                return "quit"


class InstallationScreen(BaseScreen):
    def __init__(self, nc, state):
        super().__init__(nc)
        self.state = state

    def show(self):
        self.clear()
        self.draw_centered_text(5, "Installation Screen - Coming Soon!", 0x00ff00)
        self.draw_centered_text(7, "Simulating installation...", 0xffff00)
        self.render()

        # Simulate installation
        time.sleep(3)
        return "success"


class CompletionScreen(BaseScreen):
    def __init__(self, nc, state):
        super().__init__(nc)
        self.state = state

    def show(self):
        self.clear()
        self.draw_centered_text(5, "✓ Installation Complete!", 0x00ff00)
        self.draw_centered_text(7, "Your system is ready to reboot", 0xffffff)
        self.draw_centered_text(self.height - 3, "[ENTER] Exit", 0x00ffff)
        self.render()

        self.wait_for_key()
        return "quit"
