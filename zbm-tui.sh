#!/bin/bash
################################################################################
# ZFSBootMenu TUI (Text User Interface)
#
# Interactive installer using notcurses for a beautiful terminal experience
#
# This TUI provides:
# - Visual device selection
# - Interactive settings configuration
# - Pre-flight validation checks
# - Real-time installation progress
# - Error handling and recovery
#
# Backend: Uses zbm_install.sh for actual operations
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source TUI libraries
# shellcheck source=tui/lib/notcurses_wrapper.sh
source "${SCRIPT_DIR}/tui/lib/notcurses_wrapper.sh"
# shellcheck source=tui/lib/tui_state.sh
source "${SCRIPT_DIR}/tui/lib/tui_state.sh"
# shellcheck source=tui/lib/tui_screens.sh
source "${SCRIPT_DIR}/tui/lib/tui_screens.sh"
# shellcheck source=tui/lib/tui_widgets.sh
source "${SCRIPT_DIR}/tui/lib/tui_widgets.sh"

# Backend CLI
CLI_BACKEND="${SCRIPT_DIR}/zbm_install.sh"

################################################################################
# Check dependencies
################################################################################
check_dependencies() {
    local missing=()

    # Check for notcurses-demo (indicates notcurses is installed)
    if ! command -v notcurses-demo &>/dev/null; then
        missing+=("notcurses")
    fi

    # Check for dialog as fallback
    if ! command -v dialog &>/dev/null; then
        missing+=("dialog")
    fi

    # Check backend exists
    if [[ ! -f "$CLI_BACKEND" ]]; then
        echo "ERROR: Backend CLI not found: $CLI_BACKEND"
        exit 1
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Missing required dependencies:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Install notcurses:"
        echo "  Debian/Ubuntu: sudo apt-get install libnotcurses-dev notcurses-bin"
        echo "  Fedora: sudo dnf install notcurses-devel notcurses"
        echo ""
        echo "Fallback to dialog:"
        echo "  Debian/Ubuntu: sudo apt-get install dialog"
        echo "  Fedora: sudo dnf install dialog"
        exit 1
    fi
}

################################################################################
# Check if running as root
################################################################################
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: This TUI must be run as root"
        echo "Please run: sudo $0"
        exit 1
    fi
}

################################################################################
# Main TUI workflow
################################################################################
main() {
    # Check dependencies and permissions
    check_dependencies
    check_root

    # Initialize TUI state
    init_tui_state

    # Initialize notcurses (or fallback to dialog)
    if init_notcurses; then
        USE_NOTCURSES=true
    else
        USE_NOTCURSES=false
        echo "Notcurses initialization failed, using dialog fallback"
    fi

    # Main workflow loop
    while true; do
        case "${CURRENT_SCREEN:-welcome}" in
            welcome)
                show_welcome_screen
                ;;
            mode_select)
                select_installation_mode
                ;;
            device_select)
                select_devices
                ;;
            settings)
                configure_settings
                ;;
            validation)
                validate_configuration
                ;;
            confirm)
                confirm_installation
                ;;
            execute)
                execute_installation
                ;;
            complete)
                show_completion_screen
                break
                ;;
            quit)
                cleanup_tui
                exit 0
                ;;
        esac
    done

    # Cleanup
    cleanup_tui
}

# Run main
main "$@"
