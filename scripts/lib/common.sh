#!/usr/bin/env bash

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly CYAN='\033[1;36m'
    readonly MAGENTA='\033[1;35m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' CYAN='' MAGENTA='' BOLD='' DIM='' NC=''
fi
declare -a TEMP_PATHS=()

info() { printf '%b  ✓%b  %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%b  !%b  %s\n' "$YELLOW" "$NC" "$*" >&2; }
die() { printf '\n%b  ✕  %s%b\n' "$RED" "$*" "$NC" >&2; exit 1; }

ui_clear() {
    if [[ -t 1 && ${TERM:-dumb} != dumb ]]; then
        printf '\033[2J\033[H'
    fi
}

ui_rule() {
    printf '%b  ────────────────────────────────────────────────────────────────────%b\n' "$DIM" "$NC"
}

ui_screen() {
    local step=$1 title=$2 description=${3:-}
    ui_clear
    printf '%b  AKASH // PROVIDER SETUP%b' "$BOLD" "$NC"
    printf '%b%*s%s%b\n' "$MAGENTA" "$((48 - ${#step}))" '' "$step" "$NC"
    ui_rule
    printf '\n%b  %s%b\n' "$BOLD" "$title" "$NC"
    if [[ -n $description ]]; then
        printf '%b  %s%b\n' "$DIM" "$description" "$NC"
    fi
    printf '\n'
}

ui_pause() {
    local message=${1:-Continue}
    printf '\n%b  ›%b %s %b[Enter]%b  ' "$CYAN" "$NC" "$message" "$DIM" "$NC" >&2
    read -r
}

ui_banner_line() {
    local text=${1:-} style=${2:-} indent=${3:-5} inner_width=70 padding
    padding=$((inner_width - indent - ${#text}))
    if ((padding < 0)); then
        padding=0
    fi
    printf '%b│%b%*s%b%s%b%*s%b│%b\n' \
        "$CYAN" "$NC" "$indent" '' "$style" "$text" "$NC" "$padding" '' "$CYAN" "$NC"
}

ui_section() {
    local number=$1 title=$2 description=${3:-}
    printf '\n%b  %s%b  %b%s%b\n' "$MAGENTA" "$number" "$NC" "$BOLD" "$title" "$NC"
    if [[ -n $description ]]; then
        printf '%b      %s%b\n' "$DIM" "$description" "$NC"
    fi
    ui_rule
}

ui_option() {
    local number=$1 title=$2 description=$3
    printf '      %b%s%b  %b%-24s%b %b%s%b\n' \
        "$CYAN" "$number" "$NC" "$BOLD" "$title" "$NC" "$DIM" "$description" "$NC"
}

ui_key_value() {
    printf '      %b%-22s%b %s\n' "$DIM" "$1" "$NC" "$2"
}

ui_selected() {
    local enabled=$1 label=$2 description=$3
    if [[ $enabled == true ]]; then
        printf '      %b●%b  %b%-18s%b %s\n' "$GREEN" "$NC" "$BOLD" "$label" "$NC" "$description"
    else
        printf '      %b○%b  %b%-18s%b %bNot selected%b\n' "$DIM" "$NC" "$BOLD" "$label" "$NC" "$DIM" "$NC"
    fi
}

ui_note() {
    printf '\n%b      %s%b\n' "$DIM" "$*" "$NC"
}

on_error() {
    local exit_code=$?
    printf '%b[✗]%b Setup failed at line %s (exit %s).\n' "$RED" "$NC" "${BASH_LINENO[0]}" "$exit_code" >&2
    exit "$exit_code"
}

cleanup_temp_paths() {
    local path
    for path in "${TEMP_PATHS[@]}"; do
        [[ $path == /tmp/* || $path == /private/tmp/* || $path == /private/var/folders/* ]] || continue
        rm -f -- "$path"
    done
}

ask() {
    local prompt=$1 default=${2:-} value
    if [[ -n "$default" ]]; then
        printf '%b  ›%b %s %b[%s]%b  ' "$CYAN" "$NC" "$prompt" "$DIM" "$default" "$NC" >&2
        read -r value
        printf '%s' "${value:-$default}"
    else
        printf '%b  ›%b %s  ' "$CYAN" "$NC" "$prompt" >&2
        read -r value
        printf '%s' "$value"
    fi
}

ask_required() {
    local prompt=$1 default=${2:-} value
    while true; do
        value=$(ask "$prompt" "$default")
        if [[ $value =~ [^[:space:]] ]]; then
            printf '%s' "$value"
            return
        fi
        warn "$prompt cannot be empty."
    done
}

ask_validated() {
    local prompt=$1 default=$2 pattern=$3 error_message=$4 value
    while true; do
        value=$(ask "$prompt" "$default")
        if [[ $value =~ $pattern ]]; then
            printf '%s' "$value"
            return
        fi
        warn "$error_message"
    done
}

ask_secret() {
    local prompt=$1 value
    printf '%b  ›%b %s %b(hidden)%b  ' "$CYAN" "$NC" "$prompt" "$DIM" "$NC" >&2
    read -r -s value
    printf '\n' >&2
    printf '%s' "$value"
}

ask_secret_required() {
    local prompt=$1 value
    while true; do
        value=$(ask_secret "$prompt")
        if [[ $value =~ [^[:space:]] ]]; then
            printf '%s' "$value"
            return
        fi
        warn "$prompt cannot be empty."
    done
}

is_valid_base64() {
    local value=$1
    [[ -n $value && $value =~ ^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$ ]]
}

ask_secret_base64() {
    local prompt=$1 value
    while true; do
        value=$(ask_secret_required "$prompt")
        if is_valid_base64 "$value"; then
            printf '%s' "$value"
            return
        fi
        warn "$prompt must be non-empty standard base64."
    done
}

ask_secret_confirmed() {
    local prompt=$1 value confirmation
    while true; do
        value=$(ask_secret "$prompt")
        if [[ -z $value ]]; then
            warn "$prompt cannot be empty."
            continue
        fi
        confirmation=$(ask_secret "Confirm $prompt")
        if [[ $value == "$confirmation" ]]; then
            printf '%s' "$value"
            return
        fi
        warn "Passwords did not match. Try again."
    done
}

confirm() {
    local prompt=$1 default=${2:-n} answer hint
    [[ $default == y ]] && hint='Y/n' || hint='y/N'
    while true; do
        printf '%b  ?%b %s %b[%s]%b  ' "$CYAN" "$NC" "$prompt" "$DIM" "$hint" "$NC" >&2
        read -r answer
        answer=${answer:-$default}
        case "$answer" in
            y|Y) return 0 ;;
            n|N) return 1 ;;
            *) warn "Please answer y or n." ;;
        esac
    done
}

require_nonempty() {
    local name=$1 value=$2
    [[ -n "$value" ]] || die "$name cannot be empty."
}

validate_ipv4() {
    local ip=$1 octet
    [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    for octet in ${ip//./ }; do
        ((octet >= 0 && octet <= 255)) || return 1
    done
}

yaml_quote() {
    local value=${1//\'/\'\'}
    printf "'%s'" "$value"
}

version_value() {
    local key=$1
    awk -F ': *' -v key="$key" '$1 == key {gsub(/^"|"$/, "", $2); print $2}' "$REPO_ROOT/versions.yml"
}

run() {
    local message=$1 output_file exit_code
    shift
    output_file=$(mktemp)
    TEMP_PATHS+=("$output_file")

    if [[ -t 1 ]]; then
        printf '%b  ◌%b  %s…' "$CYAN" "$NC" "$message"
    fi

    if "$@" >"$output_file" 2>&1; then
        if [[ -t 1 ]]; then
            printf '\r\033[2K'
        fi
        info "$message"
        rm -f "$output_file"
        return 0
    else
        exit_code=$?
    fi

    if [[ -t 1 ]]; then
        printf '\r\033[2K'
    fi
    printf '%b  ✕%b  %s\n' "$RED" "$NC" "$message" >&2
    if [[ -s $output_file ]]; then
        printf '%b      Command output%b\n' "$DIM" "$NC" >&2
        sed 's/^/      /' "$output_file" >&2
    else
        printf '%b      The command exited without producing output.%b\n' "$DIM" "$NC" >&2
    fi
    rm -f "$output_file"
    return "$exit_code"
}

require_root_linux() {
    [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run setup_provider.sh as root. Remote SSH users may still use sudo."
    [[ $(uname -s) == Linux ]] || die "The installer supports Ubuntu Linux only."
    [[ $(uname -m) == x86_64 ]] || die "Only x86_64 is currently supported."
    [[ -r /etc/os-release ]] || die "Cannot identify the operating system."
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ ${ID:-} == ubuntu && ${VERSION_ID:-} == 24.04 ]] || die "Ubuntu 24.04 LTS is required."
}
