#!/bin/bash
################################################################################
# System validation functions using /proc and /sys
# Minimizes dependency on external tools that may not exist or change
################################################################################

################################################################################
# Get system memory from /proc/meminfo (in KB)
################################################################################
get_system_memory_kb() {
    if [[ -f /proc/meminfo ]]; then
        grep "MemTotal:" /proc/meminfo | awk '{print $2}'
    else
        log_error "Cannot read /proc/meminfo"
        return 1
    fi
}

################################################################################
# Get CPU count from /proc/cpuinfo
################################################################################
get_cpu_count() {
    if [[ -f /proc/cpuinfo ]]; then
        grep -c "^processor" /proc/cpuinfo
    else
        log_error "Cannot read /proc/cpuinfo"
        return 1
    fi
}

################################################################################
# Check if system is EFI or BIOS using /sys/firmware/efi
################################################################################
is_efi_system() {
    if [[ -d /sys/firmware/efi ]]; then
        return 0
    else
        return 1
    fi
}

################################################################################
# Get block device size from /sys (in bytes)
################################################################################
get_block_device_size() {
    local device="$1"
    local sysfs_path="/sys/block/${device}/size"

    if [[ -f "$sysfs_path" ]]; then
        # Size is in 512-byte sectors, multiply by 512
        local sectors
        sectors=$(cat "$sysfs_path")
        echo $((sectors * 512))
    else
        log_error "Cannot read size for device: $device"
        return 1
    fi
}

################################################################################
# Get block device model from /sys
################################################################################
get_block_device_model() {
    local device="$1"
    local model_path="/sys/block/${device}/device/model"

    if [[ -f "$model_path" ]]; then
        cat "$model_path" | tr -d '[:space:]'
    else
        echo "Unknown"
    fi
}

################################################################################
# Check if block device is rotational (HDD) or not (SSD/NVMe)
################################################################################
is_rotational_device() {
    local device="$1"
    local rotational_path="/sys/block/${device}/queue/rotational"

    if [[ -f "$rotational_path" ]]; then
        local rotational
        rotational=$(cat "$rotational_path")
        [[ "$rotational" == "1" ]]
    else
        # Assume non-rotational if we can't determine
        return 1
    fi
}

################################################################################
# Get optimal I/O size for device from /sys
################################################################################
get_optimal_io_size() {
    local device="$1"
    local io_path="/sys/block/${device}/queue/optimal_io_size"

    if [[ -f "$io_path" ]]; then
        cat "$io_path"
    else
        echo "0"
    fi
}

################################################################################
# Get physical block size from /sys
################################################################################
get_physical_block_size() {
    local device="$1"
    local bs_path="/sys/block/${device}/queue/physical_block_size"

    if [[ -f "$bs_path" ]]; then
        cat "$bs_path"
    else
        echo "512"
    fi
}

################################################################################
# Check if device is mounted by reading /proc/mounts
################################################################################
is_device_mounted() {
    local device="$1"

    if [[ -f /proc/mounts ]]; then
        grep -q "^${device}" /proc/mounts
    else
        log_error "Cannot read /proc/mounts"
        return 1
    fi
}

################################################################################
# Get all partitions for a device from /sys
################################################################################
get_device_partitions() {
    local device="$1"
    local sys_path="/sys/block/${device}"

    if [[ -d "$sys_path" ]]; then
        find "$sys_path" -maxdepth 1 -name "${device}*" -type d | \
            xargs -I{} basename {} | \
            grep -v "^${device}$" || true
    fi
}

################################################################################
# Check if device has any partitions
################################################################################
has_partitions() {
    local device="$1"
    local partitions
    partitions=$(get_device_partitions "$device")
    [[ -n "$partitions" ]]
}

################################################################################
# Comprehensive drive validation using /sys and /proc
################################################################################
validate_drive() {
    local drive="$1"
    local errors=0

    log_info "Validating drive: $drive"

    # Check if device exists in /sys
    if [[ ! -d "/sys/block/$drive" ]]; then
        log_error "Drive $drive does not exist in /sys/block"
        return 1
    fi

    # Check if device node exists
    if [[ ! -b "/dev/$drive" ]]; then
        log_error "Drive /dev/$drive block device does not exist"
        return 1
    fi

    # Get and display device information from /sys
    local size_bytes model
    size_bytes=$(get_block_device_size "$drive")
    model=$(get_block_device_model "$drive")

    log_info "  Model: $model"
    log_info "  Size: $((size_bytes / 1024 / 1024 / 1024)) GB"

    # Check if device is rotational
    if is_rotational_device "$drive"; then
        log_warn "  Device is rotational (HDD) - consider using SSD for better performance"
    else
        log_info "  Device is non-rotational (SSD/NVMe)"
    fi

    # Get physical block size
    local phys_bs
    phys_bs=$(get_physical_block_size "$drive")
    log_info "  Physical block size: $phys_bs bytes"

    # Get optimal I/O size
    local opt_io
    opt_io=$(get_optimal_io_size "$drive")
    if [[ "$opt_io" -gt 0 ]]; then
        log_info "  Optimal I/O size: $opt_io bytes"
    fi

    # Check if any partitions are mounted
    if [[ -f /proc/mounts ]]; then
        local mounted_parts
        mounted_parts=$(grep "^/dev/${drive}" /proc/mounts | awk '{print $1}' || true)
        if [[ -n "$mounted_parts" ]]; then
            log_warn "  Following partitions are mounted:"
            echo "$mounted_parts" | while read -r part; do
                local mpoint
                mpoint=$(grep "^${part}" /proc/mounts | awk '{print $2}')
                log_warn "    $part -> $mpoint"
            done

            if [[ "$INSTALL_MODE" == "new" ]]; then
                log_error "  Cannot proceed with new installation - unmount partitions first"
                errors=$((errors + 1))
            fi
        fi
    fi

    # Check if device is part of any active MD RAID
    if [[ -f /proc/mdstat ]]; then
        if grep -q "$drive" /proc/mdstat 2>/dev/null; then
            log_warn "  Device appears to be part of MD RAID array"
            if [[ "$INSTALL_MODE" == "new" ]]; then
                log_error "  Remove device from RAID array before proceeding"
                errors=$((errors + 1))
            fi
        fi
    fi

    # Check minimum size requirements (8GB minimum)
    local min_size=$((8 * 1024 * 1024 * 1024))
    if [[ "$size_bytes" -lt "$min_size" ]]; then
        log_error "  Device is too small (minimum 8GB required)"
        errors=$((errors + 1))
    fi

    return $errors
}

################################################################################
# Validate all drives before proceeding
################################################################################
validate_all_drives() {
    local drives=("$@")
    local total_errors=0

    log_step "Validating drives using /sys and /proc"

    for drive in "${drives[@]}"; do
        if ! validate_drive "$drive"; then
            total_errors=$((total_errors + 1))
        fi
    done

    if [[ $total_errors -gt 0 ]]; then
        log_error "Drive validation failed with $total_errors error(s)"
        return 1
    fi

    log_success "All drives validated successfully"
    return 0
}

################################################################################
# Validate EFI partition size
################################################################################
validate_efi_size() {
    local size="$1"
    local size_bytes

    size_bytes=$(size_to_bytes "$size")

    # Minimum 100MB, maximum 2GB
    local min_bytes=$((100 * 1024 * 1024))
    local max_bytes=$((2 * 1024 * 1024 * 1024))

    if [[ $size_bytes -lt $min_bytes ]]; then
        log_error "EFI partition size too small (minimum 100MB)"
        return 1
    fi

    if [[ $size_bytes -gt $max_bytes ]]; then
        log_warn "EFI partition size is unusually large (>2GB)"
    fi

    return 0
}

################################################################################
# Validate swap size against system memory
################################################################################
validate_swap_size() {
    local size="$1"

    # Allow 0 for no swap
    if [[ "$size" == "0" ]]; then
        log_info "Swap disabled (size=0)"
        return 0
    fi

    local size_bytes mem_kb
    size_bytes=$(size_to_bytes "$size")
    mem_kb=$(get_system_memory_kb)
    local mem_bytes=$((mem_kb * 1024))

    log_info "System memory: $((mem_bytes / 1024 / 1024)) MB"
    log_info "Requested swap: $((size_bytes / 1024 / 1024)) MB"

    # Warn if swap is more than 2x RAM
    if [[ $size_bytes -gt $((mem_bytes * 2)) ]]; then
        log_warn "Swap size is more than 2x system RAM - is this intentional?"
    fi

    # Warn if swap is less than RAM and system has less than 8GB
    if [[ $mem_bytes -lt $((8 * 1024 * 1024 * 1024)) ]] && [[ $size_bytes -lt $mem_bytes ]]; then
        log_warn "System has <8GB RAM and swap is less than RAM - consider increasing swap"
    fi

    return 0
}

################################################################################
# Validate pool name
################################################################################
validate_pool_name() {
    local pool="$1"

    # Check length
    if [[ ${#pool} -eq 0 ]]; then
        log_error "Pool name cannot be empty"
        return 1
    fi

    if [[ ${#pool} -gt 256 ]]; then
        log_error "Pool name too long (max 256 characters)"
        return 1
    fi

    # Check for invalid characters
    if [[ ! "$pool" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        log_error "Pool name contains invalid characters (use: a-z, A-Z, 0-9, _, ., -)"
        return 1
    fi

    # Check if pool already exists
    if zpool list "$pool" &>/dev/null; then
        log_error "Pool '$pool' already exists"
        if [[ "$FORCE" != "true" ]]; then
            return 1
        else
            log_warn "Proceeding anyway (--force specified)"
        fi
    fi

    return 0
}

################################################################################
# Check system requirements
################################################################################
check_system_requirements() {
    log_step "Checking system requirements"

    local errors=0

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (current EUID: $EUID)"
        errors=$((errors + 1))
    fi

    # Check if system is EFI
    if ! is_efi_system; then
        log_error "This script requires an EFI system (no /sys/firmware/efi found)"
        log_error "Legacy BIOS is not supported"
        errors=$((errors + 1))
    else
        log_success "EFI system detected"
    fi

    # Check minimum RAM (2GB)
    local mem_kb
    mem_kb=$(get_system_memory_kb)
    local mem_gb=$((mem_kb / 1024 / 1024))
    log_info "System memory: ${mem_gb} GB"

    if [[ $mem_gb -lt 2 ]]; then
        log_error "Insufficient RAM (minimum 2GB required, found ${mem_gb}GB)"
        errors=$((errors + 1))
    fi

    # Check CPU count
    local cpu_count
    cpu_count=$(get_cpu_count)
    log_info "CPU count: $cpu_count"

    if [[ $cpu_count -lt 1 ]]; then
        log_error "Cannot determine CPU count"
        errors=$((errors + 1))
    fi

    # Check if /proc and /sys are mounted
    if [[ ! -d /proc ]] || [[ ! -f /proc/version ]]; then
        log_error "/proc is not mounted or accessible"
        errors=$((errors + 1))
    fi

    if [[ ! -d /sys ]] || [[ ! -d /sys/block ]]; then
        log_error "/sys is not mounted or accessible"
        errors=$((errors + 1))
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "System requirements check failed with $errors error(s)"
        return 1
    fi

    log_success "System requirements satisfied"
    return 0
}

################################################################################
# Check required commands (only those we can't avoid)
################################################################################
check_required_commands() {
    log_info "Checking for required commands..."

    local required_cmds=("sgdisk" "mkfs.vfat" "partprobe" "wipefs")
    local missing=0

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "Required command not found: $cmd"
            missing=$((missing + 1))
        fi
    done

    if [[ $missing -gt 0 ]]; then
        log_error "Missing $missing required command(s)"
        log_info "Please install required packages:"
        case "$DETECTED_DISTRO" in
            fedora)
                log_info "  sudo dnf install gdisk dosfstools"
                ;;
            debian|mx)
                log_info "  sudo apt-get install gdisk dosfstools"
                ;;
        esac
        return 1
    fi

    log_success "All required commands available"
    return 0
}

################################################################################
# Comprehensive pre-flight checks
################################################################################
preflight_checks() {
    log_step "Running pre-flight checks"

    # Check system requirements
    if ! check_system_requirements; then
        return 1
    fi

    # Check required commands
    if ! check_required_commands; then
        return 1
    fi

    # Validate drives
    if ! validate_all_drives "${DRIVES[@]}"; then
        return 1
    fi

    # Validate sizes
    if ! validate_efi_size "$EFI_SIZE"; then
        return 1
    fi

    if ! validate_swap_size "$SWAP_SIZE"; then
        return 1
    fi

    # Validate pool name
    if ! validate_pool_name "$POOL_NAME"; then
        return 1
    fi

    log_success "All pre-flight checks passed"
    return 0
}
