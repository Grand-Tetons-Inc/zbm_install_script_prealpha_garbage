#!/bin/bash
################################################################################
# TUI Widgets Library
#
# Reusable UI components for the ZFSBootMenu TUI
################################################################################

################################################################################
# Show system information widget
################################################################################
show_system_info_widget() {
    local info_text="System Information\n\n"
    info_text+="EFI System: ${SYSTEM_INFO[is_efi]}\n"
    info_text+="RAM: ${SYSTEM_INFO[ram_gb]} GB\n"
    info_text+="CPU Cores: ${SYSTEM_INFO[cpu_count]}\n"
    info_text+="Distribution: ${SYSTEM_INFO[distro]} ${SYSTEM_INFO[distro_version]}\n"

    echo "$info_text"
}

################################################################################
# Show configuration summary widget
################################################################################
show_config_summary_widget() {
    local summary="Configuration Summary\n\n"
    summary+="Mode: ${TUI_CONFIG[mode]}\n"
    summary+="Pool Name: ${TUI_CONFIG[pool_name]}\n"
    summary+="RAID Level: ${TUI_CONFIG[raid_level]}\n"
    summary+="Compression: ${TUI_CONFIG[compression]}\n"
    summary+="EFI Size: ${TUI_CONFIG[efi_size]}\n"
    summary+="Swap Size: ${TUI_CONFIG[swap_size]}\n"

    if [[ ${#SELECTED_DRIVES[@]} -gt 0 ]]; then
        summary+="Drives: ${SELECTED_DRIVES[*]}\n"
    else
        summary+="Drives: (none selected)\n"
    fi

    if [[ "${TUI_CONFIG[mode]}" == "existing" ]]; then
        summary+="\nExisting System Mode:\n"
        summary+="  Source: ${TUI_CONFIG[source_root]}\n"
        summary+="  Copy Home: ${TUI_CONFIG[copy_home]}\n"
        if [[ ${#EXCLUDE_PATHS[@]} -gt 0 ]]; then
            summary+="  Exclusions: ${#EXCLUDE_PATHS[@]} paths\n"
        fi
    fi

    echo "$summary"
}

################################################################################
# Show drive selection widget
################################################################################
show_drive_selection_widget() {
    local items=()
    local dev

    while IFS= read -r dev; do
        local display_name
        display_name=$(get_device_display_name "$dev")

        # Check if already selected
        local status="off"
        for selected in "${SELECTED_DRIVES[@]}"; do
            [[ "$selected" == "$dev" ]] && status="on" && break
        done

        items+=("$dev" "$display_name" "$status")
    done < <(get_device_list)

    local selected
    selected=$(show_checklist "Device Selection" \
        "Select one or more drives for installation\n\nWARNING: All data on selected drives will be destroyed!" \
        "${items[@]}")

    if [[ -n "$selected" ]]; then
        # Convert space-separated to array
        SELECTED_DRIVES=()
        for dev in $selected; do
            # Remove quotes
            dev="${dev//\"/}"
            SELECTED_DRIVES+=("$dev")
        done
        return 0
    fi

    return 1
}

################################################################################
# Show RAID level selection widget
################################################################################
show_raid_selection_widget() {
    local num_drives=${#SELECTED_DRIVES[@]}
    local items=()

    # none - always available
    items+=("none" "No RAID (single drive or JBOD)")
    [[ "$num_drives" -eq 1 ]] && items+=("on") || items+=("off")

    # mirror - 2+ drives
    items+=("mirror" "RAID1 Mirror (can lose N-1 drives)")
    [[ "$num_drives" -ge 2 ]] && items+=("off") || items+=("off")

    # raidz1 - 3+ drives
    items+=("raidz1" "RAIDZ1 (RAID5-like, can lose 1 drive)")
    [[ "$num_drives" -ge 3 ]] && items+=("off") || items+=("off")

    # raidz2 - 4+ drives
    items+=("raidz2" "RAIDZ2 (RAID6-like, can lose 2 drives)")
    [[ "$num_drives" -ge 4 ]] && items+=("off") || items+=("off")

    # raidz3 - 5+ drives
    items+=("raidz3" "RAIDZ3 (can lose 3 drives)")
    [[ "$num_drives" -ge 5 ]] && items+=("off") || items+=("off")

    local selected
    selected=$(show_radiolist "RAID Level Selection" \
        "Select RAID level for your ZFS pool\n\nDrives selected: $num_drives" \
        "${items[@]}")

    if [[ -n "$selected" ]]; then
        TUI_CONFIG[raid_level]="$selected"
        return 0
    fi

    return 1
}

################################################################################
# Show settings form widget
################################################################################
show_settings_form_widget() {
    local items=(
        "Pool Name"    1 1 "${TUI_CONFIG[pool_name]}"    1 20 30 0
        "Compression"  2 1 "${TUI_CONFIG[compression]}"  2 20 10 0
        "EFI Size"     3 1 "${TUI_CONFIG[efi_size]}"     3 20 10 0
        "Swap Size"    4 1 "${TUI_CONFIG[swap_size]}"    4 20 10 0
        "Hostname"     5 1 "${TUI_CONFIG[hostname]}"     5 20 30 0
    )

    local result
    result=$(show_form "Advanced Settings" \
        "Configure advanced installation settings" \
        "${items[@]}")

    if [[ -n "$result" ]]; then
        # Parse multi-line result
        local line_num=0
        while IFS= read -r line; do
            case $line_num in
                0) TUI_CONFIG[pool_name]="$line" ;;
                1) TUI_CONFIG[compression]="$line" ;;
                2) TUI_CONFIG[efi_size]="$line" ;;
                3) TUI_CONFIG[swap_size]="$line" ;;
                4) TUI_CONFIG[hostname]="$line" ;;
            esac
            line_num=$((line_num + 1))
        done <<< "$result"
        return 0
    fi

    return 1
}

################################################################################
# Show validation results widget
################################################################################
show_validation_results_widget() {
    local errors
    if ! errors=$(validate_current_config); then
        local error_text="Configuration Validation Failed\n\n"
        error_text+="The following errors were found:\n\n"
        error_text+="$errors\n\n"
        error_text+="Please go back and fix these issues."

        show_msgbox "Validation Failed" "$error_text" 20 70
        return 1
    else
        show_msgbox "Validation Passed" \
            "Configuration is valid and ready for installation!" \
            10 60
        return 0
    fi
}

################################################################################
# Show confirmation widget
################################################################################
show_confirmation_widget() {
    local confirm_text="You are about to install ZFSBootMenu with the following configuration:\n\n"
    confirm_text+=$(show_config_summary_widget)
    confirm_text+="\n\n"

    if [[ "${TUI_CONFIG[mode]}" == "new" ]]; then
        confirm_text+="WARNING: ALL DATA ON THE FOLLOWING DRIVES WILL BE DESTROYED:\n"
        for drive in "${SELECTED_DRIVES[@]}"; do
            confirm_text+="  - /dev/$drive\n"
        done
    else
        confirm_text+="Your existing system will be copied to the new ZFS installation.\n"
    fi

    confirm_text+="\n\nAre you ABSOLUTELY SURE you want to proceed?"

    show_yesno "Final Confirmation" "$confirm_text" 25 75
}
