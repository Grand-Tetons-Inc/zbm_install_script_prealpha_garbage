#!/bin/bash
################################################################################
# Notcurses Wrapper Library
#
# Provides simplified interface for notcurses with dialog fallback
################################################################################

USE_NOTCURSES=false
NC_INITIALIZED=false

################################################################################
# Initialize notcurses
################################################################################
init_notcurses() {
    # For now, use dialog as it's more widely available
    # Notcurses integration can be added later
    if command -v dialog &>/dev/null; then
        USE_NOTCURSES=false
        NC_INITIALIZED=true
        return 0
    fi

    return 1
}

################################################################################
# Cleanup notcurses
################################################################################
cleanup_notcurses() {
    clear
}

################################################################################
# Show message box
################################################################################
show_msgbox() {
    local title="$1"
    local message="$2"
    local height="${3:-10}"
    local width="${4:-60}"

    dialog --title "$title" \
           --msgbox "$message" \
           "$height" "$width"
}

################################################################################
# Show yes/no dialog
################################################################################
show_yesno() {
    local title="$1"
    local message="$2"
    local height="${3:-10}"
    local width="${4:-60}"

    dialog --title "$title" \
           --yesno "$message" \
           "$height" "$width"
}

################################################################################
# Show menu
################################################################################
show_menu() {
    local title="$1"
    local message="$2"
    shift 2
    local items=("$@")

    local height=$((${#items[@]} / 2 + 10))
    local width=70

    dialog --title "$title" \
           --menu "$message" \
           "$height" "$width" \
           $((${#items[@]} / 2)) \
           "${items[@]}" \
           2>&1 >/dev/tty
}

################################################################################
# Show checklist
################################################################################
show_checklist() {
    local title="$1"
    local message="$2"
    shift 2
    local items=("$@")

    local height=$((${#items[@]} / 3 + 10))
    local width=75

    dialog --title "$title" \
           --checklist "$message" \
           "$height" "$width" \
           $((${#items[@]} / 3)) \
           "${items[@]}" \
           2>&1 >/dev/tty
}

################################################################################
# Show input box
################################################################################
show_inputbox() {
    local title="$1"
    local message="$2"
    local default="${3:-}"
    local height="${4:-10}"
    local width="${5:-60}"

    dialog --title "$title" \
           --inputbox "$message" \
           "$height" "$width" \
           "$default" \
           2>&1 >/dev/tty
}

################################################################################
# Show radiolist
################################################################################
show_radiolist() {
    local title="$1"
    local message="$2"
    shift 2
    local items=("$@")

    local height=$((${#items[@]} / 3 + 10))
    local width=70

    dialog --title "$title" \
           --radiolist "$message" \
           "$height" "$width" \
           $((${#items[@]} / 3)) \
           "${items[@]}" \
           2>&1 >/dev/tty
}

################################################################################
# Show progress gauge
################################################################################
show_gauge() {
    local title="$1"
    local message="$2"
    local percent="${3:-0}"
    local height="${4:-10}"
    local width="${5:-60}"

    dialog --title "$title" \
           --gauge "$message" \
           "$height" "$width" \
           "$percent"
}

################################################################################
# Show info box (non-blocking)
################################################################################
show_infobox() {
    local title="$1"
    local message="$2"
    local height="${3:-10}"
    local width="${4:-60}"

    dialog --title "$title" \
           --infobox "$message" \
           "$height" "$width"
}

################################################################################
# Show tail box (live log viewer)
################################################################################
show_tailbox() {
    local title="$1"
    local file="$2"
    local height="${3:-20}"
    local width="${4:-80}"

    dialog --title "$title" \
           --tailbox "$file" \
           "$height" "$width"
}

################################################################################
# Show form
################################################################################
show_form() {
    local title="$1"
    local message="$2"
    shift 2
    local items=("$@")

    local height=$((${#items[@]} / 4 + 10))
    local width=75

    dialog --title "$title" \
           --form "$message" \
           "$height" "$width" \
           $((${#items[@]} / 4)) \
           "${items[@]}" \
           2>&1 >/dev/tty
}

################################################################################
# Clear screen
################################################################################
clear_screen() {
    clear
}

################################################################################
# Show text from file
################################################################################
show_textbox() {
    local title="$1"
    local file="$2"
    local height="${3:-20}"
    local width="${4:-75}"

    dialog --title "$title" \
           --textbox "$file" \
           "$height" "$width"
}

################################################################################
# Show build list (two columns, move items between)
################################################################################
show_buildlist() {
    local title="$1"
    local message="$2"
    shift 2
    local items=("$@")

    local height=$((${#items[@]} / 3 + 10))
    local width=75

    dialog --title "$title" \
           --buildlist "$message" \
           "$height" "$width" \
           $((${#items[@]} / 3)) \
           "${items[@]}" \
           2>&1 >/dev/tty
}
