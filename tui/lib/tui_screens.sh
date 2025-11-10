#!/bin/bash
################################################################################
# TUI Screens Library
#
# Individual screen implementations for the ZFSBootMenu TUI workflow
################################################################################

################################################################################
# Welcome screen
################################################################################
show_welcome_screen() {
    local welcome_text="Welcome to the ZFSBootMenu Installation TUI!\n\n"
    welcome_text+="This interactive installer will guide you through:\n\n"
    welcome_text+="  1. Selecting installation mode (new or existing system)\n"
    welcome_text+="  2. Choosing target drives\n"
    welcome_text+="  3. Configuring ZFS settings\n"
    welcome_text+="  4. Validating your configuration\n"
    welcome_text+="  5. Installing ZFSBootMenu\n\n"

    welcome_text+=$(show_system_info_widget)
    welcome_text+="\n\nPress OK to continue or Cancel to quit."

    if show_yesno "Welcome to ZFSBootMenu Installer" "$welcome_text" 22 75; then
        CURRENT_SCREEN="mode_select"
    else
        CURRENT_SCREEN="quit"
    fi
}

################################################################################
# Installation mode selection screen
################################################################################
select_installation_mode() {
    local items=(
        "new" "New Installation - Install ZFS on empty drives"
        "existing" "Migrate Existing System - Copy running system to ZFS"
    )

    local selected
    selected=$(show_menu "Installation Mode" \
        "Select installation mode:\n\n'new' will create a fresh installation.\n'existing' will copy your current system to ZFS." \
        "${items[@]}")

    if [[ -n "$selected" ]]; then
        TUI_CONFIG[mode]="$selected"
        CURRENT_SCREEN="device_select"
    else
        CURRENT_SCREEN="welcome"
    fi
}

################################################################################
# Device selection screen
################################################################################
select_devices() {
    if show_drive_selection_widget; then
        CURRENT_SCREEN="settings"
    else
        # User cancelled
        CURRENT_SCREEN="mode_select"
    fi
}

################################################################################
# Settings configuration screen
################################################################################
configure_settings() {
    local items=(
        "1" "RAID Level"
        "2" "Pool & Compression Settings"
        "3" "Existing System Options"
        "4" "Continue to Validation"
        "5" "Back to Device Selection"
    )

    local selected
    selected=$(show_menu "Configuration" \
        "Configure installation settings\n\nCurrent Configuration:\n$(show_config_summary_widget)" \
        "${items[@]}")

    case "$selected" in
        1)
            show_raid_selection_widget
            ;;
        2)
            show_settings_form_widget
            ;;
        3)
            if [[ "${TUI_CONFIG[mode]}" == "existing" ]]; then
                configure_existing_options
            else
                show_msgbox "Not Applicable" \
                    "Existing system options are only available in 'existing' mode" \
                    10 60
            fi
            ;;
        4)
            CURRENT_SCREEN="validation"
            ;;
        5)
            CURRENT_SCREEN="device_select"
            ;;
        *)
            CURRENT_SCREEN="device_select"
            ;;
    esac
}

################################################################################
# Configure existing system options
################################################################################
configure_existing_options() {
    local items=(
        "1" "Copy Home Directories: ${TUI_CONFIG[copy_home]}"
        "2" "Add Exclusion Paths"
        "3" "View Current Exclusions"
        "4" "Back to Settings"
    )

    local selected
    selected=$(show_menu "Existing System Options" \
        "Configure options for existing system migration" \
        "${items[@]}")

    case "$selected" in
        1)
            # Toggle copy home
            if [[ "${TUI_CONFIG[copy_home]}" == "true" ]]; then
                TUI_CONFIG[copy_home]="false"
            else
                TUI_CONFIG[copy_home]="true"
            fi
            ;;
        2)
            # Add exclusion
            local path
            path=$(show_inputbox "Add Exclusion Path" \
                "Enter path to exclude from copy:" \
                "" 10 60)
            if [[ -n "$path" ]]; then
                EXCLUDE_PATHS+=("$path")
            fi
            ;;
        3)
            # View exclusions
            local exclusions_text="Current Exclusion Paths:\n\n"
            if [[ ${#EXCLUDE_PATHS[@]} -eq 0 ]]; then
                exclusions_text+="(none)\n"
            else
                for path in "${EXCLUDE_PATHS[@]}"; do
                    exclusions_text+="  - $path\n"
                done
            fi
            show_msgbox "Exclusion Paths" "$exclusions_text" 20 70
            ;;
        4)
            return
            ;;
    esac
}

################################################################################
# Validation screen
################################################################################
validate_configuration() {
    if show_validation_results_widget; then
        CURRENT_SCREEN="confirm"
    else
        CURRENT_SCREEN="settings"
    fi
}

################################################################################
# Confirmation screen
################################################################################
confirm_installation() {
    if show_confirmation_widget; then
        CURRENT_SCREEN="execute"
    else
        CURRENT_SCREEN="settings"
    fi
}

################################################################################
# Execute installation screen
################################################################################
execute_installation() {
    # Build CLI command
    local cli_cmd
    cli_cmd=$(build_cli_command)

    # Create log file for installation
    local install_log="/tmp/zbm_install_tui_${$}.log"

    # Show info that installation is starting
    show_infobox "Installation Starting" \
        "Starting ZFSBootMenu installation...\n\nThis may take several minutes.\nPlease wait..." \
        10 60

    sleep 2

    # Execute in background and show live log
    {
        echo "Executing: $cli_cmd"
        echo "=========================================="
        eval "$cli_cmd" 2>&1
        echo "=========================================="
        echo "Exit code: $?"
    } > "$install_log" &

    local bg_pid=$!

    # Show live log viewer
    show_tailbox "Installation Progress" "$install_log" 20 80

    # Wait for completion
    wait $bg_pid
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        show_msgbox "Installation Complete" \
            "ZFSBootMenu installation completed successfully!\n\nYou can now reboot your system.\n\nLog file: $install_log" \
            12 70
        CURRENT_SCREEN="complete"
    else
        show_msgbox "Installation Failed" \
            "Installation failed with exit code: $exit_code\n\nPlease check the log file:\n$install_log" \
            12 70
        CURRENT_SCREEN="settings"
    fi
}

################################################################################
# Completion screen
################################################################################
show_completion_screen() {
    local completion_text="ZFSBootMenu Installation Complete!\n\n"
    completion_text+="Your system has been configured with:\n\n"
    completion_text+=$(show_config_summary_widget)
    completion_text+="\n\nNext steps:\n"
    completion_text+="1. Review the installation log\n"
    completion_text+="2. Reboot your system\n"
    completion_text+="3. Select ZFSBootMenu from the boot menu\n\n"
    completion_text+="Would you like to reboot now?"

    if show_yesno "Installation Complete" "$completion_text" 25 75; then
        clear
        echo "Rebooting in 5 seconds..."
        echo "Press Ctrl+C to cancel"
        sleep 5
        reboot
    fi

    CURRENT_SCREEN="quit"
}

################################################################################
# Cleanup TUI
################################################################################
cleanup_tui() {
    cleanup_notcurses
    clear
    echo "Thank you for using ZFSBootMenu TUI Installer!"
}
