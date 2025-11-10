#!/bin/bash
################################################################################
# TUI State Management
#
# Manages application state for the ZFSBootMenu TUI
################################################################################

# Current screen
CURRENT_SCREEN="welcome"

# Installation configuration
declare -A TUI_CONFIG=(
    [mode]=""                    # "new" or "existing"
    [pool_name]="zroot"
    [raid_level]="none"          # none, mirror, raidz1, raidz2, raidz3
    [compression]="zstd"         # zstd, lz4, lzjb, gzip, off
    [ashift]=""                  # auto-detect if empty
    [efi_size]="1G"
    [swap_size]="8G"
    [hostname]=""
    [source_root]="/"
    [copy_home]="true"
)

# Selected drives (array)
SELECTED_DRIVES=()

# Custom exclusion paths for existing mode
EXCLUDE_PATHS=()

# Detected system information
declare -A SYSTEM_INFO=(
    [is_efi]="unknown"
    [ram_gb]="0"
    [cpu_count]="0"
    [distro]=""
    [distro_version]=""
)

# Available block devices
declare -A BLOCK_DEVICES=()

################################################################################
# Initialize TUI state
################################################################################
init_tui_state() {
    # Detect system information from /proc and /sys
    detect_system_info

    # Scan for block devices
    scan_block_devices

    # Set initial screen
    CURRENT_SCREEN="welcome"
}

################################################################################
# Detect system information using /proc and /sys
################################################################################
detect_system_info() {
    # Check if EFI
    if [[ -d /sys/firmware/efi ]]; then
        SYSTEM_INFO[is_efi]="yes"
    else
        SYSTEM_INFO[is_efi]="no"
    fi

    # Get RAM in GB
    if [[ -f /proc/meminfo ]]; then
        local mem_kb
        mem_kb=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}')
        SYSTEM_INFO[ram_gb]=$((mem_kb / 1024 / 1024))
    fi

    # Get CPU count
    if [[ -f /proc/cpuinfo ]]; then
        SYSTEM_INFO[cpu_count]=$(grep -c "^processor" /proc/cpuinfo)
    fi

    # Detect distribution
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        SYSTEM_INFO[distro]="$ID"
        SYSTEM_INFO[distro_version]="${VERSION_ID:-unknown}"
    fi
}

################################################################################
# Scan for block devices using /sys/block
################################################################################
scan_block_devices() {
    local device

    for device in /sys/block/*; do
        local dev_name
        dev_name=$(basename "$device")

        # Skip loop, ram, and other virtual devices
        [[ "$dev_name" =~ ^(loop|ram|dm-) ]] && continue

        # Get device information
        local size_bytes model rotational phys_bs

        # Size
        if [[ -f "$device/size" ]]; then
            local sectors
            sectors=$(cat "$device/size")
            size_bytes=$((sectors * 512))
        else
            size_bytes=0
        fi

        # Model
        if [[ -f "$device/device/model" ]]; then
            model=$(cat "$device/device/model" | tr -d '[:space:]')
        else
            model="Unknown"
        fi

        # Rotational (HDD vs SSD)
        if [[ -f "$device/queue/rotational" ]]; then
            rotational=$(cat "$device/queue/rotational")
        else
            rotational="0"
        fi

        # Physical block size
        if [[ -f "$device/queue/physical_block_size" ]]; then
            phys_bs=$(cat "$device/queue/physical_block_size")
        else
            phys_bs="512"
        fi

        # Store device info
        BLOCK_DEVICES["${dev_name}:size"]="$size_bytes"
        BLOCK_DEVICES["${dev_name}:model"]="$model"
        BLOCK_DEVICES["${dev_name}:rotational"]="$rotational"
        BLOCK_DEVICES["${dev_name}:phys_bs"]="$phys_bs"
    done
}

################################################################################
# Get human-readable size
################################################################################
bytes_to_human() {
    local bytes="$1"
    local gb=$((bytes / 1024 / 1024 / 1024))

    if [[ $gb -gt 1024 ]]; then
        echo "$((gb / 1024))TB"
    else
        echo "${gb}GB"
    fi
}

################################################################################
# Get device list for display
################################################################################
get_device_list() {
    local dev
    for dev in "${!BLOCK_DEVICES[@]}"; do
        [[ "$dev" =~ :size$ ]] || continue
        local dev_name="${dev%:size}"
        echo "$dev_name"
    done | sort
}

################################################################################
# Get device display name
################################################################################
get_device_display_name() {
    local dev="$1"
    local size="${BLOCK_DEVICES[${dev}:size]}"
    local model="${BLOCK_DEVICES[${dev}:model]}"
    local rotational="${BLOCK_DEVICES[${dev}:rotational]}"

    local size_human
    size_human=$(bytes_to_human "$size")

    local type_str
    if [[ "$dev" =~ ^nvme ]]; then
        type_str="NVMe"
    elif [[ "$rotational" == "1" ]]; then
        type_str="HDD"
    else
        type_str="SSD"
    fi

    echo "${dev} (${size_human} ${model}) - ${type_str}"
}

################################################################################
# Validate current configuration
################################################################################
validate_current_config() {
    local errors=()

    # Check mode selected
    [[ -z "${TUI_CONFIG[mode]}" ]] && errors+=("Installation mode not selected")

    # Check drives selected
    [[ ${#SELECTED_DRIVES[@]} -eq 0 ]] && errors+=("No drives selected")

    # Check RAID level vs drive count
    local num_drives=${#SELECTED_DRIVES[@]}
    case "${TUI_CONFIG[raid_level]}" in
        mirror)
            [[ $num_drives -lt 2 ]] && errors+=("Mirror requires at least 2 drives")
            ;;
        raidz1)
            [[ $num_drives -lt 3 ]] && errors+=("RAIDZ1 requires at least 3 drives")
            ;;
        raidz2)
            [[ $num_drives -lt 4 ]] && errors+=("RAIDZ2 requires at least 4 drives")
            ;;
        raidz3)
            [[ $num_drives -lt 5 ]] && errors+=("RAIDZ3 requires at least 5 drives")
            ;;
    esac

    # Check EFI system
    if [[ "${SYSTEM_INFO[is_efi]}" != "yes" ]]; then
        errors+=("System is not EFI - BIOS not supported")
    fi

    # Check minimum RAM
    if [[ ${SYSTEM_INFO[ram_gb]} -lt 2 ]]; then
        errors+=("Insufficient RAM (minimum 2GB required)")
    fi

    # Return errors
    if [[ ${#errors[@]} -gt 0 ]]; then
        printf '%s\n' "${errors[@]}"
        return 1
    fi

    return 0
}

################################################################################
# Build CLI command from current state
################################################################################
build_cli_command() {
    local cmd="${CLI_BACKEND}"

    # Mode
    cmd+=" --mode ${TUI_CONFIG[mode]}"

    # Drives
    local drives_str
    drives_str=$(IFS=,; echo "${SELECTED_DRIVES[*]}")
    cmd+=" --drives ${drives_str}"

    # Pool name
    cmd+=" --pool ${TUI_CONFIG[pool_name]}"

    # RAID level
    cmd+=" --raid ${TUI_CONFIG[raid_level]}"

    # Compression
    cmd+=" --compression ${TUI_CONFIG[compression]}"

    # EFI and swap sizes
    cmd+=" --efi-size ${TUI_CONFIG[efi_size]}"
    cmd+=" --swap-size ${TUI_CONFIG[swap_size]}"

    # Ashift if specified
    [[ -n "${TUI_CONFIG[ashift]}" ]] && cmd+=" --ashift ${TUI_CONFIG[ashift]}"

    # Hostname if specified
    [[ -n "${TUI_CONFIG[hostname]}" ]] && cmd+=" --hostname ${TUI_CONFIG[hostname]}"

    # Existing mode options
    if [[ "${TUI_CONFIG[mode]}" == "existing" ]]; then
        cmd+=" --source-root ${TUI_CONFIG[source_root]}"

        [[ "${TUI_CONFIG[copy_home]}" == "false" ]] && cmd+=" --no-copy-home"

        # Add exclusions
        for exclude in "${EXCLUDE_PATHS[@]}"; do
            cmd+=" --exclude '$exclude'"
        done
    fi

    # Verbose mode for TUI
    cmd+=" --verbose"

    echo "$cmd"
}
