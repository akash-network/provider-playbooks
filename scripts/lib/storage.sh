#!/usr/bin/env bash
# shellcheck disable=SC2034 # Configuration globals are consumed by setup_provider.sh.

# Storage discovery is intentionally read-only. It rejects devices with any
# recognized ownership and passes only the operator's explicit selection to
# Rook-Ceph.

format_disk_size() {
    local bytes=$1
    awk -v bytes="$bytes" 'BEGIN {
        split("B KiB MiB GiB TiB PiB", units, " ")
        value = bytes + 0
        unit = 1
        while (value >= 1024 && unit < 6) { value /= 1024; unit++ }
        if (value >= 100 || unit == 1) printf "%.0f %s", value, units[unit]
        else printf "%.1f %s", value, units[unit]
    }'
}

storage_node_name_for_index() {
    local node_index=$1
    printf '%s' \
        "${KUBERNETES_STORAGE_NODE_NAMES[$node_index]:-${KUBERNETES_NODE_NAMES[$node_index]:-node$((node_index + 1))}}"
}

scan_storage_node() {
    local index=$1
    ssh_to_node "$index" 'sudo -n bash -s' <<'REMOTE_STORAGE_SCAN'
set -u
export LC_ALL=C

add_reason() {
    if [[ -n ${reason:-} ]]; then
        reason+=", $1"
    else
        reason=$1
    fi
}

for sys_device in /sys/class/block/*; do
    name=${sys_device##*/}
    device=/dev/$name
    [[ -b $device ]] || continue
    [[ $(lsblk -dnro TYPE "$device" 2>/dev/null) == disk ]] || continue

    size=$(lsblk -bdnro SIZE "$device" 2>/dev/null || printf 0)
    rota=$(lsblk -dnro ROTA "$device" 2>/dev/null || printf 1)
    transport=$(lsblk -dnro TRAN "$device" 2>/dev/null || true)
    model=$(lsblk -dn -o MODEL "$device" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/[[:space:]][[:space:]]*/ /g;s/[\t|]/ /g')
    reason=

    [[ $(lsblk -dnro RO "$device" 2>/dev/null || printf 1) == 0 ]] || add_reason 'read-only'
    [[ $(lsblk -dnro RM "$device" 2>/dev/null || printf 1) == 0 ]] || add_reason 'removable'
    ((size >= 5368709120)) || add_reason 'smaller than 5 GiB'
    if [[ $(lsblk -nrpo NAME "$device" 2>/dev/null | wc -l | tr -d ' ') -gt 1 ]]; then
        add_reason 'contains partitions or mapped children'
    fi
    if findmnt -rn -S "$device" >/dev/null 2>&1; then
        add_reason 'mounted'
    fi
    if swapon --noheadings --raw --output NAME 2>/dev/null | grep -Fxq "$device"; then
        add_reason 'used as swap'
    fi
    if wipefs --no-act "$device" 2>/dev/null | grep -q .; then
        add_reason 'contains a filesystem, RAID, LVM, or Ceph signature'
    fi
    if find "$sys_device/holders" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .; then
        add_reason 'has active block-device holders'
    fi
    if command -v pvs >/dev/null 2>&1 &&
        pvs --noheadings -o pv_name 2>/dev/null | awk '{$1=$1; print}' | grep -Fxq "$device"; then
        add_reason 'belongs to LVM'
    fi

    if [[ $name == nvme* || $transport == nvme ]]; then
        device_type=nvme
    elif [[ $rota == 0 ]]; then
        device_type=ssd
    else
        device_type=hdd
    fi

    stable_path=
    for link in /dev/disk/by-id/*; do
        [[ -L $link && ${link##*/} != *-part* ]] || continue
        [[ $(readlink -f -- "$link" 2>/dev/null) == "$device" ]] || continue
        stable_path=$link
        break
    done
    if [[ -z $stable_path ]]; then
        add_reason 'does not expose a stable /dev/disk/by-id identity'
        stable_path=$device
    fi

    if [[ -n $reason ]]; then status=excluded; else status=eligible; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$status" "$device" "$stable_path" "$device_type" "$size" "${model:-Unknown model}" "$reason"
done
REMOTE_STORAGE_SCAN
}

reset_storage_discovery() {
    STORAGE_CANDIDATE_NODE_INDEXES=()
    STORAGE_CANDIDATE_PATHS=()
    STORAGE_CANDIDATE_IDS=()
    STORAGE_CANDIDATE_TYPES=()
    STORAGE_CANDIDATE_SIZES=()
    STORAGE_CANDIDATE_MODELS=()
    STORAGE_EXCLUDED_NODE_INDEXES=()
    STORAGE_EXCLUDED_PATHS=()
    STORAGE_EXCLUDED_REASONS=()
}

discover_storage_devices() {
    local i output status path stable_path device_type size model reason
    reset_storage_discovery
    for i in "${!NODE_IPS[@]}"; do
        if ! output=$(scan_storage_node "$i"); then
            warn "Storage discovery failed on node$((i + 1)) (${NODE_IPS[$i]})."
            return 1
        fi
        while IFS=$'\t' read -r status path stable_path device_type size model reason; do
            [[ -n $status ]] || continue
            case "$status" in
                eligible)
                    STORAGE_CANDIDATE_NODE_INDEXES+=("$i")
                    STORAGE_CANDIDATE_PATHS+=("$path")
                    STORAGE_CANDIDATE_IDS+=("$stable_path")
                    STORAGE_CANDIDATE_TYPES+=("$device_type")
                    STORAGE_CANDIDATE_SIZES+=("$size")
                    STORAGE_CANDIDATE_MODELS+=("$model")
                    ;;
                excluded)
                    STORAGE_EXCLUDED_NODE_INDEXES+=("$i")
                    STORAGE_EXCLUDED_PATHS+=("$path")
                    STORAGE_EXCLUDED_REASONS+=("${reason:-not available to Ceph}")
                    ;;
                *) warn "Ignoring malformed storage discovery output from node$((i + 1))." ;;
            esac
        done <<<"$output"
    done
}

storage_type_supports_layout() {
    local requested_type=$1 requested_hosts=$2 i node_index physical_count=0
    local -a distinct_nodes=()
    for i in "${!STORAGE_CANDIDATE_TYPES[@]}"; do
        [[ ${STORAGE_CANDIDATE_TYPES[$i]} == "$requested_type" ]] || continue
        physical_count=$((physical_count + 1))
        node_index=${STORAGE_CANDIDATE_NODE_INDEXES[$i]}
        [[ " ${distinct_nodes[*]:-} " == *" $node_index "* ]] || distinct_nodes+=("$node_index")
    done
    if ((requested_hosts == 1)); then
        ((${#distinct_nodes[@]} == 1 && physical_count >= 2))
    else
        ((${#distinct_nodes[@]} >= requested_hosts && physical_count >= requested_hosts))
    fi
}

recommend_storage_candidates() {
    local requested_hosts device_type i node_index
    local -a distinct_nodes=()
    STORAGE_RECOMMENDED_CANDIDATES=()
    STORAGE_RECOMMENDED_TYPE=
    ((${#STORAGE_CANDIDATE_TYPES[@]} >= 2)) || return 1

    for node_index in "${STORAGE_CANDIDATE_NODE_INDEXES[@]}"; do
        [[ " ${distinct_nodes[*]:-} " == *" $node_index "* ]] || distinct_nodes+=("$node_index")
    done
    if ((${#distinct_nodes[@]} >= 3)); then
        requested_hosts=3
    elif ((${#distinct_nodes[@]} == 2)); then
        requested_hosts=2
    else
        requested_hosts=1
    fi

    # Keep a homogeneous performance tier when it preserves the best available
    # topology. Otherwise recommend all eligible disks and advertise the class
    # conservatively according to the slowest selected media.
    for device_type in nvme ssd hdd; do
        if storage_type_supports_layout "$device_type" "$requested_hosts"; then
            STORAGE_RECOMMENDED_TYPE=$device_type
            for i in "${!STORAGE_CANDIDATE_TYPES[@]}"; do
                [[ ${STORAGE_CANDIDATE_TYPES[$i]} == "$device_type" ]] && \
                    STORAGE_RECOMMENDED_CANDIDATES+=("$i")
            done
            return 0
        fi
    done

    STORAGE_RECOMMENDED_TYPE=mixed
    for i in "${!STORAGE_CANDIDATE_TYPES[@]}"; do
        STORAGE_RECOMMENDED_CANDIDATES+=("$i")
    done
    return 0
}

show_storage_discovery() {
    local i node_index size label
    ui_screen "5 / 8" "Design the Ceph storage layer" \
        "Every host was inspected read-only. In-use disks and devices without stable IDs are excluded."
    if ((${#STORAGE_CANDIDATE_PATHS[@]} > 0)); then
        printf '%b      AVAILABLE WHOLE DISKS%b\n' "$BOLD" "$NC"
        for i in "${!STORAGE_CANDIDATE_PATHS[@]}"; do
            node_index=${STORAGE_CANDIDATE_NODE_INDEXES[$i]}
            size=$(format_disk_size "${STORAGE_CANDIDATE_SIZES[$i]}")
            label="$((i + 1)) · node$((node_index + 1)) · ${STORAGE_CANDIDATE_TYPES[$i]} · $size"
            ui_key_value "$label" "${STORAGE_CANDIDATE_IDS[$i]} · ${STORAGE_CANDIDATE_MODELS[$i]}"
        done
    else
        ui_note "No empty whole disks were detected."
    fi
    if ((${#STORAGE_EXCLUDED_PATHS[@]} > 0)); then
        printf '\n%b      EXCLUDED%b\n' "$BOLD" "$NC"
        for i in "${!STORAGE_EXCLUDED_PATHS[@]}"; do
            node_index=${STORAGE_EXCLUDED_NODE_INDEXES[$i]}
            ui_key_value "node$((node_index + 1)) ${STORAGE_EXCLUDED_PATHS[$i]}" \
                "${STORAGE_EXCLUDED_REASONS[$i]}"
        done
    fi
}

existing_ceph_cluster_present() {
    ssh_to_node 0 \
        'sudo -n kubectl -n rook-ceph get cephcluster rook-ceph --output name' \
        >/dev/null 2>&1
}

load_previous_storage_layout() {
    local file="$INVENTORY_DIR/host_vars/node1.yml" previous_type node kubernetes_node device node_index i
    [[ -r $file ]] || return 1
    previous_type=$(awk -F ': ' '$1 == "device_type" {gsub(/^\047|\047$/, "", $2); print $2; exit}' "$file")
    [[ $previous_type =~ ^(hdd|ssd|nvme)$ ]] || return 1

    reset_storage_discovery
    while IFS=$'\t' read -r node kubernetes_node device; do
        [[ $kubernetes_node == '-' ]] && kubernetes_node=
        [[ -n $node && $device =~ ^/dev/disk/by-id/[A-Za-z0-9._+:@=-]+$ ]] || return 1
        node_index=
        for i in "${!KUBERNETES_NODE_NAMES[@]}"; do
            if [[ -n $kubernetes_node && ${KUBERNETES_NODE_NAMES[$i]} == "$kubernetes_node" && \
                  ${KUBERNETES_STORAGE_NODE_NAMES[$i]:-${KUBERNETES_NODE_NAMES[$i]}} == "$node" ]]; then
                node_index=$i
                break
            fi
            # Backward compatibility for inventories written before the distinct
            # Kubernetes metadata and Rook hostname-label fields were introduced.
            if [[ -z $kubernetes_node && \
                  ( ${KUBERNETES_STORAGE_NODE_NAMES[$i]:-${KUBERNETES_NODE_NAMES[$i]}} == "$node" || \
                    ${KUBERNETES_NODE_NAMES[$i]} == "$node" ) ]]; then
                node_index=$i
                break
            fi
        done
        [[ -n $node_index ]] || return 1
        ssh_to_node "$node_index" \
            "sudo -n test -L '$device' && sudo -n test -b '$device'" >/dev/null 2>&1 || return 1
        STORAGE_CANDIDATE_NODE_INDEXES+=("$node_index")
        STORAGE_CANDIDATE_PATHS+=("$device")
        STORAGE_CANDIDATE_IDS+=("$device")
        STORAGE_CANDIDATE_TYPES+=("$previous_type")
        STORAGE_CANDIDATE_SIZES+=(0)
        STORAGE_CANDIDATE_MODELS+=("Existing Ceph OSD")
    done < <(
        awk '
            $0 == "storage_nodes:" { in_storage=1; next }
            in_storage && /^  - name: / {
                node=$0
                sub(/^  - name: /, "", node)
                gsub(/^\047|\047$/, "", node)
                kubernetes_node=""
                next
            }
            in_storage && /^    kubernetes_node_name: / {
                kubernetes_node=$0
                sub(/^    kubernetes_node_name: /, "", kubernetes_node)
                gsub(/^\047|\047$/, "", kubernetes_node)
                next
            }
            in_storage && /^      - name: / {
                device=$0
                sub(/^      - name: /, "", device)
                gsub(/^\047|\047$/, "", device)
                if (kubernetes_node == "") kubernetes_node="-"
                print node "\t" kubernetes_node "\t" device
            }
        ' "$file"
    )
    ((${#STORAGE_CANDIDATE_PATHS[@]} >= 2)) || return 1
    STORAGE_SELECTED_CANDIDATES=()
    for i in "${!STORAGE_CANDIDATE_PATHS[@]}"; do
        STORAGE_SELECTED_CANDIDATES+=("$i")
    done
    derive_storage_layout
}

reuse_existing_storage_layout() {
    existing_ceph_cluster_present || return 1
    if ! load_previous_storage_layout; then
        die "An existing Rook-Ceph cluster was detected, but its exact device layout could not be recovered from $INVENTORY_DIR/host_vars/node1.yml. Restore the protected generated inventory or manage the existing cluster manually."
    fi
    ui_screen "5 / 8" "Keep the existing Ceph storage layout" \
        "Rook-Ceph is already installed. Previously selected devices were verified as block devices."
    local candidate node_index
    for candidate in "${STORAGE_SELECTED_CANDIDATES[@]}"; do
        node_index=${STORAGE_CANDIDATE_NODE_INDEXES[$candidate]}
        ui_key_value "${KUBERNETES_NODE_NAMES[$node_index]}" \
            "${STORAGE_CANDIDATE_IDS[$candidate]} · Rook hostname $(storage_node_name_for_index "$node_index")"
    done
    ui_key_value "Expected OSDs" "$STORAGE_EXPECTED_OSD_COUNT"
    printf '\n'
    confirm "Reuse this existing Ceph layout?" y || \
        die "Changing devices on an existing Ceph cluster is not performed automatically."
}

storage_candidate_numbers() {
    local i output=
    for i in "$@"; do output+=" $((i + 1))"; done
    printf '%s' "${output# }"
}

validate_storage_candidate_selection() {
    local selection=$1 item index
    STORAGE_SELECTED_CANDIDATES=()
    for item in $selection; do
        [[ $item =~ ^[1-9][0-9]*$ ]] || return 1
        index=$((item - 1))
        ((index < ${#STORAGE_CANDIDATE_PATHS[@]})) || return 1
        [[ " ${STORAGE_SELECTED_CANDIDATES[*]:-} " == *" $index "* ]] || \
            STORAGE_SELECTED_CANDIDATES+=("$index")
    done
    ((${#STORAGE_SELECTED_CANDIDATES[@]} >= 2))
}

derive_storage_layout() {
    local candidate node_index node_name device_type selected_count
    local -a selected_node_indexes=()
    STORAGE_NODES=()
    for candidate in "${STORAGE_SELECTED_CANDIDATES[@]}"; do
        node_index=${STORAGE_CANDIDATE_NODE_INDEXES[$candidate]}
        if [[ " ${selected_node_indexes[*]:-} " != *" $node_index "* ]]; then
            selected_node_indexes+=("$node_index")
            node_name=$(storage_node_name_for_index "$node_index")
            STORAGE_NODES+=("$node_name")
        fi
    done
    selected_count=${#STORAGE_SELECTED_CANDIDATES[@]}
    ((selected_count >= 2)) || return 1
    if ((${#selected_node_indexes[@]} >= 3)); then
        STORAGE_POOL_SIZE=3; STORAGE_MIN_SIZE=2; STORAGE_FAILURE_DOMAIN=host
    elif ((${#selected_node_indexes[@]} == 2)); then
        STORAGE_POOL_SIZE=2; STORAGE_MIN_SIZE=1; STORAGE_FAILURE_DOMAIN=host
    elif ((selected_count >= 2)); then
        STORAGE_POOL_SIZE=2; STORAGE_MIN_SIZE=1; STORAGE_FAILURE_DOMAIN=osd
    else
        return 1
    fi

    STORAGE_MON_COUNT=1
    STORAGE_MGR_COUNT=1
    ((${#NODE_IPS[@]} >= 3)) && STORAGE_MON_COUNT=3
    ((${#NODE_IPS[@]} >= 2)) && STORAGE_MGR_COUNT=2
    STORAGE_EXPECTED_OSD_COUNT=$selected_count
    STORAGE_OSDS_PER_DEVICE=1

    STORAGE_DEVICE_TYPE=nvme
    for candidate in "${STORAGE_SELECTED_CANDIDATES[@]}"; do
        device_type=${STORAGE_CANDIDATE_TYPES[$candidate]}
        if [[ $device_type == hdd ]]; then
            STORAGE_DEVICE_TYPE=hdd
            break
        elif [[ $device_type == ssd ]]; then
            STORAGE_DEVICE_TYPE=ssd
        fi
    done
    case "$STORAGE_DEVICE_TYPE" in
        hdd) STORAGE_CLASS=beta1 ;;
        ssd) STORAGE_CLASS=beta2 ;;
        nvme) STORAGE_CLASS=beta3 ;;
        *) return 1 ;;
    esac
}

collect_storage_config() {
    $INSTALL_ROOK || return 0
    local action default_selection selection candidate node_index size
    if existing_ceph_cluster_present; then
        reuse_existing_storage_layout
        return
    fi
    while true; do
        if ! discover_storage_devices; then
            action=$(ask "Type r to retry discovery or skip to continue without Ceph" "r")
            if [[ ${action,,} == skip ]]; then INSTALL_ROOK=false; return; fi
            continue
        fi
        show_storage_discovery
        if ! recommend_storage_candidates; then
            warn "Ceph needs at least two physical disks: on two hosts, or two disks on one host."
            action=$(ask "Attach empty disks and type r to rescan, or skip to continue without Ceph" "r")
            if [[ ${action,,} == skip ]]; then INSTALL_ROOK=false; return; fi
            continue
        fi
        break
    done

    default_selection=$(storage_candidate_numbers "${STORAGE_RECOMMENDED_CANDIDATES[@]}")
    printf '\n%b      RECOMMENDED LAYOUT%b\n' "$BOLD" "$NC"
    ui_key_value "Device tier" "$STORAGE_RECOMMENDED_TYPE"
    ui_key_value "Physical disks" "${#STORAGE_RECOMMENDED_CANDIDATES[@]}"
    ui_note "The recommendation prioritizes three hosts, then two hosts, then two physical disks on one host."
    while true; do
        selection=$(ask "Space-separated disk numbers" "$default_selection")
        if validate_storage_candidate_selection "$selection" && derive_storage_layout; then break; fi
        warn "Select at least two unique physical disks in a valid Ceph topology."
    done

    printf '\n%b      SELECTED FOR CEPH%b\n' "$BOLD" "$NC"
    for candidate in "${STORAGE_SELECTED_CANDIDATES[@]}"; do
        node_index=${STORAGE_CANDIDATE_NODE_INDEXES[$candidate]}
        size=$(format_disk_size "${STORAGE_CANDIDATE_SIZES[$candidate]}")
        ui_key_value "node$((node_index + 1)) · ${STORAGE_CANDIDATE_TYPES[$candidate]} · $size" \
            "${STORAGE_CANDIDATE_IDS[$candidate]}"
    done
    ui_key_value "Replication" "$STORAGE_POOL_SIZE copies across $STORAGE_FAILURE_DOMAIN"
    ui_key_value "Expected OSDs" "$STORAGE_EXPECTED_OSD_COUNT (one per physical disk)"
    if [[ $STORAGE_FAILURE_DOMAIN == osd ]]; then
        warn "This layout survives one disk failure, but not loss of its single storage host."
    fi
    ui_note "Discovery cannot identify arbitrary unformatted data. Nothing is wiped now, but Rook will consume every selected disk."
    confirm "I confirm these exact disks are dedicated to Ceph" n || die "Storage confirmation declined."
}
