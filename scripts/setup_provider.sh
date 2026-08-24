#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
readonly SCRIPT_DIR REPO_ROOT
readonly PROJECT_VENV="$REPO_ROOT/.venv"
readonly CACHE_DIR="$REPO_ROOT/.cache"
readonly KUBESPRAY_DIR="$CACHE_DIR/kubespray"
readonly AKT_BIN=/usr/local/bin/akt
readonly AKT_CONTEXT=provider
readonly GENERATED_DIR="${PROVIDER_PLAYBOOKS_GENERATED_DIR:-$REPO_ROOT/.generated}"
readonly INVENTORY_DIR="$GENERATED_DIR/inventory"
readonly INVENTORY_FILE="$INVENTORY_DIR/hosts.ini"

# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/bootstrap.sh
source "$SCRIPT_DIR/lib/bootstrap.sh"
# shellcheck source=scripts/lib/storage.sh
source "$SCRIPT_DIR/lib/storage.sh"
trap on_error ERR
trap cleanup_temp_paths EXIT

CONFIG_ONLY=false
if [[ ${1:-} == --config-only ]]; then
    CONFIG_ONLY=true
elif [[ $# -gt 0 ]]; then
    die "Usage: $0 [--config-only]"
fi

declare -a NODE_IPS NODE_INTERNAL_IPS NODE_EXTERNAL_IPS NODE_USERS NODE_PORTS
declare -a KUBERNETES_NODE_NAMES KUBERNETES_STORAGE_NODE_NAMES
declare -a STORAGE_NODES STORAGE_CANDIDATE_NODE_INDEXES STORAGE_CANDIDATE_PATHS STORAGE_CANDIDATE_IDS
declare -a STORAGE_CANDIDATE_TYPES STORAGE_CANDIDATE_SIZES STORAGE_CANDIDATE_MODELS
declare -a STORAGE_EXCLUDED_NODE_INDEXES STORAGE_EXCLUDED_PATHS STORAGE_EXCLUDED_REASONS
declare -a STORAGE_RECOMMENDED_CANDIDATES STORAGE_SELECTED_CANDIDATES
declare -a GPU_PROFILES GPU_NODE_SUMMARIES
SSH_PRIVATE_KEY=
SSH_PUBLIC_KEY=
CLUSTER_MODE=existing
CONTROL_PLANE_COUNT=1
INSTALL_OS=true
INSTALL_GPU=false
INSTALL_PROVIDER=true
INSTALL_TAILSCALE=false
INSTALL_ROOK=false
GPU_FABRIC_MANAGER=false

display_welcome() {
    ui_clear
    printf '%b╭──────────────────────────────────────────────────────────────────────╮%b\n' "$CYAN" "$NC"
    ui_banner_line '' '' 0
    ui_banner_line 'AKASH // PROVIDER' "$BOLD"
    ui_banner_line 'Infrastructure installation console' "$DIM"
    ui_banner_line '' '' 0
    printf '%b╰──────────────────────────────────────────────────────────────────────╯%b\n' "$CYAN" "$NC"
    if $CONFIG_ONLY; then
        printf '\n      %bCONFIGURATION ONLY%b  No packages or clusters will be changed.\n' "$YELLOW" "$NC"
    else
        printf '\n      Build a secure, production-ready Akash provider cluster.\n'
    fi
    ui_note "Secrets and generated inventory → $GENERATED_DIR"
}

select_components() {
    local choice
    while true; do
        INSTALL_OS=true
        INSTALL_GPU=false
        INSTALL_PROVIDER=true
        INSTALL_TAILSCALE=false
        INSTALL_ROOK=false

        ui_screen "1 / 8" "Choose the Kubernetes foundation" \
            "Only the selected distribution and its dependencies are installed."
        ui_option "1" "Kubernetes / Kubespray" "Production-grade multi-node clusters"
        ui_option "2" "K3s" "Lean Kubernetes without Kubespray"
        ui_option "3" "Existing cluster" "Keep the Kubernetes installation untouched"
        while true; do
            choice=$(ask "Cluster foundation" "3")
            case "$choice" in
                1) CLUSTER_MODE=kubespray; break ;;
                2) CLUSTER_MODE=k3s; break ;;
                3) CLUSTER_MODE=existing; break ;;
                *) warn "Choose 1, 2, or 3." ;;
            esac
        done

        ui_screen "2 / 8" "Select the provider capabilities" \
            "Defaults are shown in uppercase in each prompt."
        confirm "Apply provider OS tuning and maintenance jobs?" y || INSTALL_OS=false
        confirm "Configure NVIDIA GPUs with GPU Operator?" n && INSTALL_GPU=true
        confirm "Install the Akash provider stack?" y || INSTALL_PROVIDER=false
        confirm "Connect nodes with Tailscale?" n && INSTALL_TAILSCALE=true
        confirm "Install Rook-Ceph persistent storage?" n && INSTALL_ROOK=true

        ui_screen "PROFILE" "Your installation profile" "Review the high-level plan before entering host details."
        case "$CLUSTER_MODE" in
            kubespray) ui_key_value "Cluster" "Kubernetes via Kubespray" ;;
            k3s) ui_key_value "Cluster" "K3s" ;;
            existing) ui_key_value "Cluster" "Existing Kubernetes" ;;
        esac
        ui_selected "$INSTALL_OS" "OS" "Tuning and maintenance"
        ui_selected "$INSTALL_GPU" "GPU" "NVIDIA GPU Operator"
        ui_selected "$INSTALL_ROOK" "Storage" "Rook-Ceph"
        ui_selected "$INSTALL_PROVIDER" "Provider" "Akash services and gateway"
        ui_selected "$INSTALL_TAILSCALE" "Tailscale" "Private node connectivity"
        printf '\n'
        confirm "Continue with this profile?" y && break
        warn "Selection reset. Choose the installation profile again."
    done

    if $INSTALL_ROOK && [[ $CLUSTER_MODE == k3s ]]; then
        warn "Rook-Ceph on K3s is supported, but verify dedicated devices and the kubelet path carefully."
    fi
}

collect_nodes() {
    local count i ip user port
    ui_screen "3 / 8" "Describe the cluster hosts" \
        "Nodes are named node1, node2, … in the generated inventory."
    count=$(ask "Number of cluster nodes" "1")
    [[ $count =~ ^[1-9][0-9]*$ ]] || die "Node count must be a positive integer."

    if ((count >= 3)); then
        CONTROL_PLANE_COUNT=$(ask "Number of control-plane nodes (1 or 3)" "3")
    fi
    [[ $CONTROL_PLANE_COUNT == 1 || $CONTROL_PLANE_COUNT == 3 ]] || die "Control-plane count must be 1 or 3."
    ((CONTROL_PLANE_COUNT <= count)) || die "Control-plane count exceeds node count."

    for ((i = 1; i <= count; i++)); do
        printf '\n%b      NODE %s%b\n' "$BOLD" "$i" "$NC"
        while true; do
            ip=$(ask "node${i} reachable SSH IPv4 address")
            validate_ipv4 "$ip" && break
            warn "Invalid IPv4 address."
        done
        user=$(ask "node${i} SSH user" "root")
        port=$(ask "node${i} SSH port" "22")
        [[ $port =~ ^[0-9]+$ ]] || die "SSH port must be numeric."
        NODE_IPS+=("$ip")
        NODE_USERS+=("$user")
        NODE_PORTS+=("$port")
    done
}

select_or_create_ssh_key() {
    local ssh_home='' ssh_dir candidate public_key
    command -v ssh >/dev/null 2>&1 || die "OpenSSH client is required. Install openssh-client and retry."
    command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen is required. Install openssh-client and retry."
    if command -v getent >/dev/null 2>&1; then
        ssh_home=$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6)
    fi
    ssh_home=${ssh_home:-${HOME:-}}
    [[ -n $ssh_home ]] || die "Cannot determine the local user's home directory for SSH keys."
    ssh_dir="$ssh_home/.ssh"
    mkdir -p "$ssh_dir"
    chmod 0700 "$ssh_dir"

    for candidate in \
        "$ssh_dir/provider_playbooks_ed25519" \
        "$ssh_dir/id_ed25519" \
        "$ssh_dir/id_ecdsa" \
        "$ssh_dir/id_rsa"; do
        if [[ -r $candidate ]] && public_key=$(ssh-keygen -y -P '' -f "$candidate" 2>/dev/null); then
            SSH_PRIVATE_KEY=$candidate
            # Always derive the public key from the private key. A stale sibling
            # .pub file must never instruct operators to authorize another key.
            SSH_PUBLIC_KEY=$public_key
            return
        fi
    done

    SSH_PRIVATE_KEY="$ssh_dir/provider_playbooks_ed25519"
    run "Generating a dedicated installer SSH key" \
        ssh-keygen -q -t ed25519 -N '' -C "provider-playbooks@$(hostname)" -f "$SSH_PRIVATE_KEY"
    chmod 0600 "$SSH_PRIVATE_KEY"
    chmod 0644 "$SSH_PRIVATE_KEY.pub"
    SSH_PUBLIC_KEY=$(<"$SSH_PRIVATE_KEY.pub")
}

ssh_to_node() {
    local index=$1
    shift
    ssh -o BatchMode=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no \
        -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes \
        -i "$SSH_PRIVATE_KEY" -p "${NODE_PORTS[$index]}" \
        "${NODE_USERS[$index]}@${NODE_IPS[$index]}" "$@"
}

all_nodes_accept_ssh_key() {
    local i
    for i in "${!NODE_IPS[@]}"; do
        ssh_to_node "$i" true >/dev/null 2>&1 || return 1
    done
}

show_ssh_key_instructions() {
    local i
    ui_screen "SSH ACCESS" "Authorize the installer key" \
        "Password login is not supported. Add this public key to every configured SSH user."
    ui_key_value "Private key selected" "$SSH_PRIVATE_KEY"
    printf '\n%b      COPY THIS PUBLIC KEY%b\n\n' "$BOLD" "$NC"
    printf '%b%s%b\n' "$CYAN" "$SSH_PUBLIC_KEY" "$NC"
    printf '\n%b      TARGET USERS%b\n' "$BOLD" "$NC"
    for i in "${!NODE_IPS[@]}"; do
        ui_key_value "node$((i + 1))" "${NODE_USERS[$i]}@${NODE_IPS[$i]}:${NODE_PORTS[$i]}"
    done
    ui_note "On each node, as that SSH user:"
    printf '\n      mkdir -p ~/.ssh && chmod 700 ~/.ssh\n'
    printf '      Open ~/.ssh/authorized_keys, paste the key on its own line, then run:\n'
    printf '      chmod 600 ~/.ssh/authorized_keys\n'
}

validate_remote_sudo() {
    local i
    for i in "${!NODE_IPS[@]}"; do
        # shellcheck disable=SC2016 # id must expand on the remote node.
        if ! ssh_to_node "$i" 'if [ "$(id -u)" -eq 0 ]; then true; else sudo -n true; fi' >/dev/null 2>&1; then
            die "Non-interactive sudo is unavailable for ${NODE_USERS[$i]}@${NODE_IPS[$i]}. Configure passwordless sudo for that user, then retry."
        fi
    done
}

configure_ssh_access() {
    local response
    select_or_create_ssh_key
    while ! all_nodes_accept_ssh_key; do
        show_ssh_key_instructions
        response=$(ask "Press Enter after installing the key on every node, or type q to quit")
        [[ ${response,,} == q ]] && die "SSH key setup cancelled."
    done
    validate_remote_sudo
    info "SSH key access verified on every node."
}

is_private_ipv4() {
    local ip=$1 first second
    validate_ipv4 "$ip" || return 1
    IFS=. read -r first second _ <<<"$ip"
    [[ $first == 10 ]] || [[ $first == 192 && $second == 168 ]] || \
        [[ $first == 172 && $second -ge 16 && $second -le 31 ]]
}

detect_node_private_ips() {
    local index=$1 output candidate
    output=$(ssh_to_node "$index" "hostname -I" 2>/dev/null) || return 1
    for candidate in $output; do
        is_private_ipv4 "$candidate" && printf '%s\n' "$candidate"
    done
}

detect_node_public_ip() {
    local index=$1 output
    output=$(ssh_to_node "$index" \
        "if command -v curl >/dev/null 2>&1; then curl -4 --fail --silent --max-time 8 https://api.ipify.org; elif command -v wget >/dev/null 2>&1; then wget -qO- -T 8 https://api.ipify.org; else exit 1; fi" \
        2>/dev/null) || return 1
    validate_ipv4 "$output" || return 1
    is_private_ipv4 "$output" && return 1
    printf '%s' "$output"
}

collect_node_networking() {
    if [[ $CLUSTER_MODE == existing ]]; then
        NODE_INTERNAL_IPS=("${NODE_IPS[@]}")
        NODE_EXTERNAL_IPS=("${NODE_IPS[@]}")
        return
    fi
    local i detected public_ip private_ready=true public_ready=true addresses_differ=false
    local -a detected_private_ips=() detected_public_ips=()
    local -A seen_public_ips=()
    for i in "${!NODE_IPS[@]}"; do
        detected=$(detect_node_private_ips "$i" | head -n 1 || true)
        if [[ -z $detected ]]; then
            private_ready=false
            detected=${NODE_IPS[$i]}
        fi
        detected_private_ips+=("$detected")
        public_ip=$(detect_node_public_ip "$i" || true)
        if [[ -z $public_ip || -n ${seen_public_ips[$public_ip]:-} ]]; then
            public_ready=false
            public_ip=${NODE_IPS[$i]}
        else
            seen_public_ips[$public_ip]=true
        fi
        detected_public_ips+=("$public_ip")
        [[ $detected != "$public_ip" ]] && addresses_differ=true
    done
    NODE_EXTERNAL_IPS=("${detected_public_ips[@]}")

    if $private_ready && $public_ready && $addresses_differ; then
        ui_screen "NETWORK" "Choose inter-node networking" \
            "SSH keeps its entered address. Choose which detected network Kubernetes should advertise."
        for i in "${!NODE_IPS[@]}"; do
            ui_key_value "node$((i + 1)) private" "${detected_private_ips[$i]}"
            ui_key_value "node$((i + 1)) public" "${detected_public_ips[$i]}"
        done
        printf '\n'
        if confirm "Use private addresses for Kubernetes inter-node traffic?" y; then
            NODE_INTERNAL_IPS=("${detected_private_ips[@]}")
            return
        fi
        NODE_INTERNAL_IPS=("${detected_public_ips[@]}")
        warn "Public inter-node addresses must be bound or routed directly to each host."
        return
    fi

    if $private_ready; then
        NODE_INTERNAL_IPS=("${detected_private_ips[@]}")
    elif $public_ready; then
        NODE_INTERNAL_IPS=("${detected_public_ips[@]}")
    else
        NODE_INTERNAL_IPS=("${NODE_IPS[@]}")
        NODE_EXTERNAL_IPS=("${NODE_IPS[@]}")
        ui_note "Automatic network detection was incomplete; using the entered SSH addresses."
    fi
}

detect_kubernetes_node_names() {
    local i j cluster_nodes remote_names candidate_index candidate name hostname_label internal_ip external_ip
    local storage_label_count
    local -a cluster_names=() cluster_storage_names=() cluster_internal_ips=() cluster_external_ips=()
    local -a hostname_candidate_indexes=() name_candidate_indexes=() ip_candidate_indexes=()
    KUBERNETES_NODE_NAMES=()
    KUBERNETES_STORAGE_NODE_NAMES=()
    if [[ $CLUSTER_MODE != existing ]]; then
        for i in "${!NODE_IPS[@]}"; do
            KUBERNETES_NODE_NAMES+=("node$((i + 1))")
            KUBERNETES_STORAGE_NODE_NAMES+=("node$((i + 1))")
        done
        return
    fi

    if ! cluster_nodes=$(ssh_to_node 0 \
        "sudo -n kubectl get nodes --no-headers -o 'custom-columns=NAME:.metadata.name,HOSTNAME:.metadata.labels.kubernetes\\.io/hostname,INTERNAL_IP:.status.addresses[?(@.type==\"InternalIP\")].address,EXTERNAL_IP:.status.addresses[?(@.type==\"ExternalIP\")].address'" \
        2>/dev/null); then
        die "Unable to list Kubernetes nodes from node1. Verify that kubectl can access the existing cluster with sudo."
    fi
    [[ -n $cluster_nodes ]] || die "The existing Kubernetes cluster did not report any nodes."

    while read -r name hostname_label internal_ip external_ip _; do
        [[ -n $name ]] || continue
        if [[ -z $hostname_label || $hostname_label == '<none>' ]]; then
            $INSTALL_ROOK && \
                die "Kubernetes node $name has no kubernetes.io/hostname label; Rook-Ceph requires one."
            hostname_label=$name
        fi
        cluster_names+=("$name")
        cluster_storage_names+=("$hostname_label")
        cluster_internal_ips+=("$internal_ip")
        cluster_external_ips+=("$external_ip")
    done <<<"$cluster_nodes"
    ((${#cluster_names[@]} > 0)) || die "Unable to parse the Kubernetes node list from the existing cluster."

    for i in "${!NODE_IPS[@]}"; do
        # shellcheck disable=SC2016 # Hostname expansion happens on the remote node.
        remote_names=$(ssh_to_node "$i" 'printf "%s\n" "$(hostname -s)" "$(hostname -f 2>/dev/null || true)"' 2>/dev/null || true)
        candidate_index=
        # Hostnames are authoritative. IPs may be shared by NAT or differentiated
        # only by the entered SSH port, so consider them only in a second pass.
        hostname_candidate_indexes=()
        name_candidate_indexes=()
        for j in "${!cluster_names[@]}"; do
            grep -Fxq "${cluster_storage_names[$j]}" <<<"$remote_names" && \
                hostname_candidate_indexes+=("$j")
            grep -Fxq "${cluster_names[$j]}" <<<"$remote_names" && \
                name_candidate_indexes+=("$j")
        done
        if ((${#hostname_candidate_indexes[@]} == 1)); then
            candidate_index=${hostname_candidate_indexes[0]}
        elif ((${#hostname_candidate_indexes[@]} == 0 && ${#name_candidate_indexes[@]} == 1)); then
            candidate_index=${name_candidate_indexes[0]}
        fi

        if [[ -z $candidate_index ]]; then
            ip_candidate_indexes=()
            for j in "${!cluster_names[@]}"; do
                if [[ ${cluster_internal_ips[$j]} == "${NODE_IPS[$i]}" || \
                      ${cluster_external_ips[$j]} == "${NODE_IPS[$i]}" || \
                      ${cluster_internal_ips[$j]} == "${NODE_INTERNAL_IPS[$i]}" || \
                      ${cluster_external_ips[$j]} == "${NODE_EXTERNAL_IPS[$i]}" ]]; then
                    ip_candidate_indexes+=("$j")
                fi
            done
            if ((${#ip_candidate_indexes[@]} == 1)); then
                j=${ip_candidate_indexes[0]}
                if [[ " ${KUBERNETES_NODE_NAMES[*]:-} " != *" ${cluster_names[$j]} "* ]]; then
                    candidate_index=$j
                fi
            fi
        fi

        if [[ -n $candidate_index && \
              " ${KUBERNETES_NODE_NAMES[*]:-} " == *" ${cluster_names[$candidate_index]} "* ]]; then
            candidate_index=
        fi

        while [[ -z $candidate_index ]]; do
            ui_screen "KUBERNETES" "Match the existing cluster nodes" \
                "The Ansible aliases stay node1, node2, …; Rook also needs each hostname label."
            for j in "${!cluster_names[@]}"; do
                printf '      %-24s hostname %-24s internal %-15s external %s\n' \
                    "${cluster_names[$j]}" "${cluster_storage_names[$j]}" \
                    "${cluster_internal_ips[$j]}" "${cluster_external_ips[$j]}"
            done
            printf '\n'
            candidate=$(ask_required "Kubernetes node name for node$((i + 1))")
            candidate_index=
            for j in "${!cluster_names[@]}"; do
                if [[ ${cluster_names[$j]} == "$candidate" ]]; then
                    candidate_index=$j
                    break
                fi
            done
            if [[ -z $candidate_index ]]; then
                warn "Choose a node name exactly as shown above."
            elif [[ " ${KUBERNETES_NODE_NAMES[*]:-} " == *" ${cluster_names[$candidate_index]} "* ]]; then
                warn "That Kubernetes node is already assigned to another configured host."
                candidate_index=
            fi
        done
        if $INSTALL_ROOK; then
            storage_label_count=0
            for hostname_label in "${cluster_storage_names[@]}"; do
                [[ $hostname_label == "${cluster_storage_names[$candidate_index]}" ]] && \
                    storage_label_count=$((storage_label_count + 1))
            done
            if ((storage_label_count != 1)); then
                die "Kubernetes hostname label ${cluster_storage_names[$candidate_index]} is not unique across the cluster; Rook device selection requires a unique label for every configured storage host."
            fi
        fi
        if $INSTALL_ROOK && \
            [[ " ${KUBERNETES_STORAGE_NODE_NAMES[*]:-} " == *" ${cluster_storage_names[$candidate_index]} "* ]]; then
            die "Kubernetes nodes ${cluster_names[$candidate_index]} and another configured host share hostname label ${cluster_storage_names[$candidate_index]}; Rook storage nodes require unique hostname labels."
        fi
        KUBERNETES_NODE_NAMES+=("${cluster_names[$candidate_index]}")
        KUBERNETES_STORAGE_NODE_NAMES+=("${cluster_storage_names[$candidate_index]}")
    done
}

is_valid_location_region() {
    case "$1" in
        na-ca-west|na-ca-central|na-ca-prairie|na-ca-atlantic|na-ca-north|\
        na-us-west|na-us-southwest|na-us-midwest|na-us-southeast|na-us-northeast|\
        central-america|caribbean|sa-north|sa-west|sa-south|sa-brazil|\
        eu-central|eu-east|eu-north|eu-southeast|eu-south|eu-southwest|eu-west|\
        af-east|af-middle|af-north|af-south|af-west|\
        as-central|as-east|as-southeast|as-south|as-west|\
        oc-aus|oc-nz|oc-mel|oc-mic|oc-pol) return 0 ;;
        *) return 1 ;;
    esac
}

map_location_country() {
    local area=$1 country=${2^^}
    LOCATION_REGION=
    case "$area:$country" in
        central:BZ|central:CR|central:SV|central:GT|central:HN|central:NI|central:PA)
            LOCATION_REGION=central-america ;;
        central:AI|central:AG|central:AW|central:BS|central:BB|central:BQ|central:VG|central:KY|\
        central:CU|central:CW|central:DM|central:DO|central:GD|central:GP|central:HT|central:JM|\
        central:MQ|central:MS|central:PR|central:BL|central:KN|central:LC|central:MF|central:VC|\
        central:SX|central:TT|central:TC|central:VI)
            LOCATION_REGION=caribbean ;;
        south-america:CO|south-america:VE|south-america:GY|south-america:SR|south-america:GF)
            LOCATION_REGION=sa-north ;;
        south-america:PE|south-america:EC|south-america:BO) LOCATION_REGION=sa-west ;;
        south-america:AR|south-america:UY|south-america:CL|south-america:PY) LOCATION_REGION=sa-south ;;
        south-america:BR) LOCATION_REGION=sa-brazil ;;
        europe:SI|europe:HU|europe:SK|europe:PL|europe:CZ|europe:AT|europe:CH|europe:DE)
            LOCATION_REGION=eu-central ;;
        europe:MD|europe:UA|europe:BY|europe:LT|europe:LV|europe:EE|europe:RU) LOCATION_REGION=eu-east ;;
        europe:DK|europe:SE|europe:NO|europe:FI|europe:IS) LOCATION_REGION=eu-north ;;
        europe:AL|europe:MK|europe:BG|europe:RO|europe:RS|europe:XK|europe:ME|europe:BA|europe:HR)
            LOCATION_REGION=eu-southeast ;;
        europe:IT|europe:GR) LOCATION_REGION=eu-south ;;
        europe:PT|europe:ES|europe:AD) LOCATION_REGION=eu-southwest ;;
        europe:FR|europe:LU|europe:BE|europe:NL|europe:GB|europe:IE) LOCATION_REGION=eu-west ;;
        africa:MZ|africa:ZW|africa:ZM|africa:MW|africa:TZ|africa:BI|africa:RW|africa:KE|\
        africa:UG|africa:SO|africa:ET|africa:DJ|africa:ER|africa:SS) LOCATION_REGION=af-east ;;
        africa:TD|africa:CF|africa:CM|africa:GQ|africa:GA|africa:CG|africa:CD|africa:AO)
            LOCATION_REGION=af-middle ;;
        africa:EH|africa:MA|africa:DZ|africa:TN|africa:LY|africa:EG|africa:SD) LOCATION_REGION=af-north ;;
        africa:NA|africa:BW|africa:ZA|africa:LS|africa:SZ) LOCATION_REGION=af-south ;;
        africa:MR|africa:ML|africa:NE|africa:NG|africa:BJ|africa:TG|africa:GH|africa:BF|\
        africa:CI|africa:LR|africa:GN|africa:SL|africa:GW|africa:GM|africa:SN) LOCATION_REGION=af-west ;;
        asia:KZ|asia:KG|asia:TJ|asia:TM|asia:UZ) LOCATION_REGION=as-central ;;
        asia:CN|asia:JP|asia:KP|asia:KR|asia:MN|asia:HK|asia:MO|asia:TW) LOCATION_REGION=as-east ;;
        asia:MM|asia:LA|asia:TH|asia:VN|asia:KH|asia:MY|asia:SG|asia:ID|asia:TL|asia:PH)
            LOCATION_REGION=as-southeast ;;
        asia:IR|asia:AF|asia:PK|asia:IN|asia:BD|asia:BT|asia:NP|asia:LK|asia:MV)
            LOCATION_REGION=as-south ;;
        asia:TR|asia:GE|asia:AM|asia:AZ|asia:SY|asia:LB|asia:JO|asia:IL|asia:IQ|asia:KW|\
        asia:SA|asia:YE|asia:OM|asia:AE|asia:QA|asia:BH|asia:CY|asia:PS) LOCATION_REGION=as-west ;;
        oceania:AU) LOCATION_REGION=oc-aus ;;
        oceania:NZ) LOCATION_REGION=oc-nz ;;
        oceania:PG|oceania:NR|oceania:SB|oceania:VU|oceania:NC|oceania:FJ) LOCATION_REGION=oc-mel ;;
        oceania:PW|oceania:MP|oceania:GU|oceania:FM|oceania:MH|oceania:KI) LOCATION_REGION=oc-mic ;;
        oceania:TV|oceania:WF|oceania:TK|oceania:AS|oceania:TO|oceania:NU|oceania:CK|\
        oceania:PF|oceania:PN) LOCATION_REGION=oc-pol ;;
        *) return 1 ;;
    esac
    LOCATION_COUNTRY=$country
}

map_north_america_subdivision() {
    local country=${1^^} subdivision=${2^^}
    case "$country:$subdivision" in
        US:CA|US:OR|US:WA|US:ID|US:MT|US:WY|US:UT|US:CO|US:NV|US:AK|US:HI) LOCATION_REGION=na-us-west ;;
        US:AZ|US:NM|US:TX|US:OK) LOCATION_REGION=na-us-southwest ;;
        US:ND|US:SD|US:NE|US:KS|US:MN|US:IA|US:MO|US:WI|US:IL|US:MI|US:IN|US:OH) LOCATION_REGION=na-us-midwest ;;
        US:AR|US:LA|US:MS|US:AL|US:TN|US:KY|US:WV|US:VA|US:NC|US:SC|US:GA|US:FL) LOCATION_REGION=na-us-southeast ;;
        US:PA|US:NY|US:VT|US:NH|US:ME|US:MA|US:RI|US:CT|US:NJ|US:DE|US:MD) LOCATION_REGION=na-us-northeast ;;
        CA:BC) LOCATION_REGION=na-ca-west ;;
        CA:QC|CA:ON) LOCATION_REGION=na-ca-central ;;
        CA:AB|CA:SK|CA:MB) LOCATION_REGION=na-ca-prairie ;;
        CA:NL|CA:PE|CA:NS|CA:NB) LOCATION_REGION=na-ca-atlantic ;;
        CA:NU|CA:NT|CA:YT) LOCATION_REGION=na-ca-north ;;
        *) return 1 ;;
    esac
    LOCATION_COUNTRY=$country
}

normalize_latin_city_name() {
    printf '%s' "$1" | sed \
        -e 's/[ÀÁÂÃÄÅàáâãäå]/a/g' \
        -e 's/[Çç]/c/g' \
        -e 's/[ÈÉÊËèéêë]/e/g' \
        -e 's/[ÌÍÎÏìíîï]/i/g' \
        -e 's/[Ññ]/n/g' \
        -e 's/[ÒÓÔÕÖØòóôõöø]/o/g' \
        -e 's/[ÙÚÛÜùúûü]/u/g' \
        -e 's/[ÝŸýÿ]/y/g' \
        -e 's/[Šš]/s/g' \
        -e 's/[Žž]/z/g' \
        -e 's/[Łł]/l/g' \
        -e 's/[ŹŻźż]/z/g' \
        -e 's/ß/ss/g'
}

city_code_from_name() {
    local city compact
    city=$(normalize_latin_city_name "$1")
    city=${city,,}
    case "$city" in
        chicago) printf 'CHI' ;;
        'new york'|'new york city') printf 'NYC' ;;
        'los angeles') printf 'LAX' ;;
        'san francisco') printf 'SFO' ;;
        london) printf 'LON' ;;
        singapore) printf 'SIN' ;;
        frankfurt|'frankfurt am main') printf 'FRA' ;;
        zurich) printf 'ZRH' ;;
        'sao paulo') printf 'SAO' ;;
        *)
            compact=$(printf '%s' "$city" | LC_ALL=C tr -cd 'A-Za-z')
            ((${#compact} >= 3)) || return 1
            compact=${compact:0:3}
            [[ $compact =~ ^[A-Za-z]{3}$ ]] || return 1
            printf '%s' "$compact" | tr '[:lower:]' '[:upper:]'
            ;;
    esac
}

timezone_from_utc_offset() {
    local offset=$1 sign hours minutes rounded
    [[ $offset =~ ^([+-])([0-9]{2})([0-9]{2})$ ]] || return 1
    sign=${BASH_REMATCH[1]}
    hours=$((10#${BASH_REMATCH[2]}))
    minutes=$((10#${BASH_REMATCH[3]}))
    rounded=$hours
    ((minutes >= 30)) && rounded=$((rounded + 1))
    ((rounded <= 14)) || return 1
    if [[ $sign == - && $rounded -ne 0 ]]; then
        printf 'utc-%s' "$rounded"
    else
        printf 'utc+%s' "$rounded"
    fi
}

append_location_detection_error() {
    local message=$1
    if [[ -n ${LOCATION_DETECTION_ERROR:-} ]]; then
        LOCATION_DETECTION_ERROR+="; $message"
    else
        LOCATION_DETECTION_ERROR=$message
    fi
}

fetch_location_fields() {
    local provider=$1 url filter json reason
    case "$provider" in
        ipwho)
            url=https://ipwho.is/
            filter='select(.success == true and (.country_code | type) == "string" and (.city | type) == "string" and (.timezone.utc | type) == "string") | [.country_code, .region_code, .city, (.timezone.utc | gsub(":"; "")), .continent_code] | @tsv'
            ;;
        ipapi)
            url=https://ipapi.co/json/
            filter='select((.error // false) == false and (.country_code | type) == "string" and (.city | type) == "string" and (.utc_offset | type) == "string") | [.country_code, .region_code, .city, .utc_offset, .continent_code] | @tsv'
            ;;
        *) return 1 ;;
    esac

    if ! json=$(ssh_to_node 0 \
        "if command -v curl >/dev/null 2>&1; then curl --silent --show-error --max-time 8 $url; elif command -v wget >/dev/null 2>&1; then wget -qO- -T 8 $url; else exit 1; fi" \
        2>/dev/null); then
        append_location_detection_error "$provider request failed"
        return 1
    fi
    if LOCATION_FIELDS=$(jq -er "$filter" <<<"$json" 2>/dev/null); then
        return
    fi
    reason=$(jq -r '.reason // .message // .error // empty | tostring' <<<"$json" 2>/dev/null || true)
    append_location_detection_error "$provider: ${reason:-invalid response}"
    return 1
}

resolve_country_input() {
    local input=$1 country_file=/usr/share/zoneinfo/iso3166.tab code
    if [[ $input =~ ^[A-Za-z]{2}$ ]]; then
        printf '%s' "${input^^}"
        return
    fi
    [[ -r $country_file ]] || return 1
    code=$(awk -F '\t' -v requested="${input,,}" \
        'tolower($2) == requested { print $1; exit }' "$country_file")
    [[ $code =~ ^[A-Z]{2}$ ]] || return 1
    printf '%s' "$code"
}

detect_provider_location() {
    local fields country subdivision city offset continent area
    LOCATION_DETECTION_ERROR=
    if ! command -v jq >/dev/null 2>&1; then
        LOCATION_DETECTION_ERROR='jq is unavailable on the installer host'
        return 1
    fi
    if fetch_location_fields ipwho || fetch_location_fields ipapi; then
        fields=$LOCATION_FIELDS
    else
        return 1
    fi
    IFS=$'\t' read -r country subdivision city offset continent <<<"$fields"
    if [[ ! $country =~ ^[A-Z]{2}$ || -z $city ]]; then
        append_location_detection_error 'geolocation response did not include a country and city'
        return 1
    fi

    if [[ $country == US || $country == CA ]]; then
        if ! map_north_america_subdivision "$country" "$subdivision"; then
            append_location_detection_error "subdivision $country-$subdivision is not mapped"
            return 1
        fi
    else
        case "$continent" in
            NA) area=central ;;
            SA) area=south-america ;;
            EU) area=europe ;;
            AF) area=africa ;;
            AS) area=asia ;;
            OC) area=oceania ;;
            *) return 1 ;;
        esac
        if ! map_location_country "$area" "$country"; then
            append_location_detection_error "country $country is not mapped to the Akash region schema"
            return 1
        fi
    fi
    if ! CITY=$(city_code_from_name "$city"); then
        append_location_detection_error "could not derive a city code from $city"
        return 1
    fi
    GEO_CITY_NAME=$city
    if [[ ${offset: -2} == 00 ]]; then
        GEO_TIMEZONE_APPROXIMATE=false
    else
        GEO_TIMEZONE_APPROXIMATE=true
    fi
    if ! TIMEZONE=$(timezone_from_utc_offset "$offset"); then
        append_location_detection_error "UTC offset $offset is not supported by the Akash schema"
        return 1
    fi
}

collect_manual_city_timezone() {
    local city_name
    while true; do
        city_name=$(ask "Provider city")
        if CITY=$(city_code_from_name "$city_name"); then
            break
        fi
        warn "Enter a city name containing at least three letters."
    done
    GEO_CITY_NAME=$city_name
    while true; do
        TIMEZONE=$(ask "UTC offset (utc-12 through utc+14)")
        [[ $TIMEZONE =~ ^utc([-+])([0-9]|1[0-4])$ ]] && break
        warn "Enter an accepted whole-hour offset such as utc-6 or utc+1."
    done
}

collect_manual_location_region() {
    local selected_country=${1:-} region country
    while true; do
        region=$(ask "Accepted location-region code")
        if is_valid_location_region "$region"; then
            LOCATION_REGION=$region
            break
        fi
        warn "That value is not present in the current Akash provider schema."
    done
    country=$selected_country
    if [[ ! $country =~ ^[A-Z]{2}$ ]]; then
        while true; do
            country=$(ask "ISO country code")
            country=${country^^}
            [[ $country =~ ^[A-Z]{2}$ ]] && break
            warn "Enter a two-letter ISO country code."
        done
    fi
    LOCATION_COUNTRY=$country
    collect_manual_city_timezone
}

collect_north_america_location() {
    local country_choice region_choice
    ui_screen "LOCATION" "Choose the North American country" \
        "The Akash schema divides the United States and Canada into provider regions."
    ui_option "1" "United States" "Choose one of five provider regions"
    ui_option "2" "Canada" "Choose one of five provider regions"
    while true; do
        country_choice=$(ask "Country" "1")
        [[ $country_choice == 1 || $country_choice == 2 ]] && break
        warn "Choose 1 or 2."
    done

    if [[ $country_choice == 1 ]]; then
        LOCATION_COUNTRY=US
        ui_screen "LOCATION" "Choose the United States region" \
            "State groupings match the accepted Akash provider schema."
        ui_option "1" "West" "CA, OR, WA, ID, MT, WY, UT, CO, NV, AK, HI"
        ui_option "2" "Southwest" "AZ, NM, TX, OK"
        ui_option "3" "Midwest" "ND through OH"
        ui_option "4" "Southeast" "AR through FL"
        ui_option "5" "Northeast" "PA through MD"
        while true; do
            region_choice=$(ask "United States region" "1")
            case "$region_choice" in
                1) LOCATION_REGION=na-us-west; break ;;
                2) LOCATION_REGION=na-us-southwest; break ;;
                3) LOCATION_REGION=na-us-midwest; break ;;
                4) LOCATION_REGION=na-us-southeast; break ;;
                5) LOCATION_REGION=na-us-northeast; break ;;
                *) warn "Choose a region from 1 to 5." ;;
            esac
        done
    else
        LOCATION_COUNTRY=CA
        ui_screen "LOCATION" "Choose the Canadian region" \
            "Province groupings match the accepted Akash provider schema."
        ui_option "1" "West coast" "British Columbia"
        ui_option "2" "Central" "Quebec and Ontario"
        ui_option "3" "Prairie" "Alberta, Saskatchewan, Manitoba"
        ui_option "4" "Atlantic" "NL, PE, NS, NB"
        ui_option "5" "North" "NU, NT, YT"
        while true; do
            region_choice=$(ask "Canadian region" "2")
            case "$region_choice" in
                1) LOCATION_REGION=na-ca-west; break ;;
                2) LOCATION_REGION=na-ca-central; break ;;
                3) LOCATION_REGION=na-ca-prairie; break ;;
                4) LOCATION_REGION=na-ca-atlantic; break ;;
                5) LOCATION_REGION=na-ca-north; break ;;
                *) warn "Choose a region from 1 to 5." ;;
            esac
        done
    fi
}

collect_location_region() {
    local area_choice area area_name country
    if detect_provider_location; then
        ui_screen "LOCATION" "Provider location detected" \
            "The lookup ran from node1, so it reflects the provider's public IP."
        ui_key_value "City" "$GEO_CITY_NAME ($CITY)"
        ui_key_value "Country" "$LOCATION_COUNTRY"
        ui_key_value "Provider region" "$LOCATION_REGION"
        ui_key_value "Timezone" "$TIMEZONE"
        if $GEO_TIMEZONE_APPROXIMATE; then
            ui_note "The Akash schema accepts whole-hour UTC offsets; this offset was rounded."
        fi
        printf '\n'
        if confirm "Use this detected location?" y; then
            return
        fi
        LOCATION_DETECTION_ERROR='the detected location was declined'
    fi

    ui_screen "LOCATION" "Locate the provider" \
        "Automatic lookup was unavailable or declined. The wizard will build valid attributes."
    ui_note "Automatic lookup: ${LOCATION_DETECTION_ERROR:-unknown failure}."
    ui_option "1" "North America" "United States or Canada"
    ui_option "2" "Central / Caribbean" "Central America and Caribbean nations"
    ui_option "3" "South America" "North, west, south, or Brazil"
    ui_option "4" "Europe" "UN geoscheme-derived European regions"
    ui_option "5" "Africa" "East, middle, north, south, or west"
    ui_option "6" "Asia" "Central, east, southeast, south, or west"
    ui_option "7" "Oceania" "Australia, New Zealand, Melanesia, Micronesia, Polynesia"
    ui_option "8" "Advanced" "Enter an accepted region code manually"
    while true; do
        area_choice=$(ask "Geographic area" "1")
        case "$area_choice" in
            1) collect_north_america_location; collect_manual_city_timezone; return ;;
            2) area=central; area_name='Central America or Caribbean'; break ;;
            3) area=south-america; area_name='South America'; break ;;
            4) area=europe; area_name='Europe'; break ;;
            5) area=africa; area_name='Africa'; break ;;
            6) area=asia; area_name='Asia'; break ;;
            7) area=oceania; area_name='Oceania'; break ;;
            8) collect_manual_location_region; return ;;
            *) warn "Choose an area from 1 to 8." ;;
        esac
    done

    ui_screen "LOCATION" "Choose the country" \
        "The ISO country code is mapped to an accepted $area_name provider region."
    while true; do
        country=$(ask "Country name or two-letter ISO code")
        if ! country=$(resolve_country_input "$country"); then
            warn "Enter a recognized country name or its two-letter ISO code."
            continue
        fi
        if map_location_country "$area" "$country"; then
            collect_manual_city_timezone
            return
        fi
        warn "$country is not mapped to $area_name in the current Akash schema."
        if confirm "Enter an accepted location-region manually?" n; then
            collect_manual_location_region "$country"
            return
        fi
    done
}

detect_provider_hardware() {
    local cpu_info vendor architecture dmi memory_generation
    cpu_info=$(ssh_to_node 0 "LC_ALL=C lscpu" 2>/dev/null) || return 1
    vendor=$(awk -F: '/^Vendor ID:/{gsub(/^[[:space:]]+/, "", $2); print $2; exit}' <<<"$cpu_info")
    architecture=$(awk -F: '/^Architecture:/{gsub(/^[[:space:]]+/, "", $2); print $2; exit}' <<<"$cpu_info")
    case "$vendor" in
        GenuineIntel|*Intel*) CPU_VENDOR=intel ;;
        AuthenticAMD|*AMD*) CPU_VENDOR=amd ;;
        *) return 1 ;;
    esac
    case "$architecture" in
        x86_64) CPU_ARCH=x86-64 ;;
        *) return 1 ;;
    esac

    MEMORY_TYPE=
    if dmi=$(ssh_to_node 0 "sudo -n dmidecode --type memory" 2>/dev/null); then
        memory_generation=$(awk -F: '/^[[:space:]]*Type: DDR[345]/{gsub(/[[:space:]]/, "", $2); print tolower($2); exit}' <<<"$dmi")
        if [[ $memory_generation =~ ^ddr[345]$ ]]; then
            MEMORY_TYPE=$memory_generation
            if grep -Eiq 'Error Correction Type:.*(ECC|Single-bit|Multi-bit)' <<<"$dmi"; then
                MEMORY_TYPE+=ecc
            fi
        fi
    fi
}

collect_hardware_profile() {
    local detected=false
    detect_provider_hardware && detected=true
    if $detected; then
        ui_screen "HARDWARE" "Provider hardware detected" \
            "CPU details and available memory metadata were read from node1."
        ui_key_value "CPU vendor" "$CPU_VENDOR"
        ui_key_value "CPU architecture" "$CPU_ARCH"
        ui_key_value "Memory type" "${MEMORY_TYPE:-Not exposed by system firmware}"
        printf '\n'
        if confirm "Use this detected hardware profile?" y; then
            if [[ -z $MEMORY_TYPE ]]; then
                MEMORY_TYPE=$(ask_validated \
                    "Memory type (ddr2/ddr3/ddr3ecc/ddr4/ddr4ecc/ddr5/ddr5ecc)" "ddr4ecc" \
                    '^(ddr2|ddr3|ddr3ecc|ddr4|ddr4ecc|ddr5|ddr5ecc)$' \
                    "Choose a memory type accepted by the provider schema.")
            fi
            return
        fi
    fi
    CPU_VENDOR=$(ask_validated "CPU vendor (intel/amd)" "amd" '^(intel|amd)$' \
        "CPU vendor must be intel or amd.")
    CPU_ARCH=$(ask_validated "CPU architecture" "x86-64" '^x86-64$' \
        "Only x86-64 is currently supported.")
    MEMORY_TYPE=$(ask_validated \
        "Memory type (ddr2/ddr3/ddr3ecc/ddr4/ddr4ecc/ddr5/ddr5ecc)" "ddr4ecc" \
        '^(ddr2|ddr3|ddr3ecc|ddr4|ddr4ecc|ddr5|ddr5ecc)$' \
        "Choose a memory type accepted by the provider schema.")
}

collect_provider_config() {
    $INSTALL_PROVIDER || return 0
    ui_screen "6 / 8" "Define the provider identity" \
        "These values become public provider attributes on the Akash network."
    DOMAIN=$(ask_validated "Provider domain (without provider. prefix)" '' \
        '^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' "Enter a valid provider domain such as example.com.")
    collect_location_region
    ui_screen "6 / 8" "Complete the provider identity" \
        "The location helper selected a schema-compatible provider region."
    ui_key_value "Domain" "$DOMAIN"
    ui_key_value "Country" "$LOCATION_COUNTRY"
    ui_key_value "Location region" "$LOCATION_REGION"
    printf '\n'
    ORGANIZATION=$(ask_required "Organization")
    EMAIL=$(ask_validated "Contact email" '' \
        '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' "Enter a valid contact email address.")
    WEBSITE=$(ask_required "Website URL" "https://$DOMAIN")
    DISCORD_USERNAME=$(ask_required "Discord username")
    STATUS_PAGE=$(ask_required "Status page URL" "$WEBSITE")
    COUNTRY=$LOCATION_COUNTRY
    LOCATION_TYPE=$(ask_validated "Location type (datacenter/colo/home/office/mix)" "datacenter" \
        '^(datacenter|colo|home|office|mix)$' "Choose datacenter, colo, home, office, or mix.")
    HOSTING_PROVIDER=$(ask_required "Hosting provider or facility")
    collect_hardware_profile
    NETWORK_PROVIDER=$(ask_required "Network provider")
    NETWORK_SPEED_UP=$(ask_validated "Upload speed Mbps" "1000" '^[0-9]+$' \
        "Upload speed must be an integer in Mbps.")
    NETWORK_SPEED_DOWN=$(ask_validated "Download speed Mbps" "1000" '^[0-9]+$' \
        "Download speed must be an integer in Mbps.")

    require_nonempty "Domain" "$DOMAIN"
    require_nonempty "Organization" "$ORGANIZATION"
    require_nonempty "Email" "$EMAIL"
    require_nonempty "Website" "$WEBSITE"
    require_nonempty "Discord username" "$DISCORD_USERNAME"
    require_nonempty "Status page" "$STATUS_PAGE"
    require_nonempty "Hosting provider" "$HOSTING_PROVIDER"
    require_nonempty "Network provider" "$NETWORK_PROVIDER"
    [[ $EMAIL =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] || die "Invalid email address."
    [[ $DOMAIN =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || die "Invalid provider domain."
    [[ $COUNTRY =~ ^[A-Za-z]{2}$ ]] || die "Country must be an ISO alpha-2 code."
    [[ $CITY =~ ^[A-Za-z]{3}$ ]] || die "City must be a three-letter code."
    [[ $LOCATION_TYPE =~ ^(datacenter|colo|home|office|mix)$ ]] || die "Invalid location type."
    [[ $CPU_VENDOR =~ ^(intel|amd)$ ]] || die "CPU vendor must be intel or amd."
    [[ $CPU_ARCH == x86-64 ]] || die "Only x86-64 is currently supported."
    [[ $MEMORY_TYPE =~ ^(ddr2|ddr3|ddr3ecc|ddr4|ddr4ecc|ddr5|ddr5ecc)$ ]] || die "Memory type is not accepted by the provider schema."
    [[ $NETWORK_SPEED_UP =~ ^[0-9]+$ && $NETWORK_SPEED_DOWN =~ ^[0-9]+$ ]] || die "Network speeds must be integers."

    collect_wallet_config
    collect_acme_config
}

collect_gpu_config() {
    $INSTALL_GPU || return 0
    detect_nvidia_gpu_profiles || die "${GPU_DETECTION_ERROR:-Unable to detect supported NVIDIA GPU hardware.}"
    ui_screen "4 / 8" "NVIDIA GPU hardware detected" \
        "PCI IDs were matched against the pinned Akash provider-configs database."
    local summary
    for summary in "${GPU_NODE_SUMMARIES[@]}"; do
        ui_key_value "${summary%%|*}" "${summary#*|}"
    done
    ui_key_value "CUDA attribute" "$CUDA_VERSION"
    ui_key_value "Fabric Manager" "$([[ $GPU_FABRIC_MANAGER == true ]] && printf Enabled || printf Disabled)"
    ui_note "GPU Operator and provider attributes will use this detected profile."
}

load_gpu_database() {
    if [[ -n ${PROVIDER_GPU_DATABASE_FILE:-} ]]; then
        GPU_DATABASE_FILE=$PROVIDER_GPU_DATABASE_FILE
    else
        GPU_DATABASE_FILE=$(mktemp)
        TEMP_PATHS+=("$GPU_DATABASE_FILE")
        local commit
        commit=$(version_value gpu_database_commit)
        curl --fail --silent --show-error --location \
            "https://raw.githubusercontent.com/akash-network/provider-configs/${commit}/devices/pcie/gpus.json" \
            --output "$GPU_DATABASE_FILE" || return 1
        local actual_sha256 expected_sha256
        actual_sha256=$(sha256sum "$GPU_DATABASE_FILE" | awk '{print $1}')
        expected_sha256=$(version_value gpu_database_sha256)
        [[ $actual_sha256 == "$expected_sha256" ]] || return 1
    fi
    jq -e 'type == "object"' "$GPU_DATABASE_FILE" >/dev/null
}

append_gpu_profile() {
    local candidate=$1 existing
    for existing in "${GPU_PROFILES[@]}"; do
        [[ $existing == "$candidate" ]] && return
    done
    GPU_PROFILES+=("$candidate")
}

detect_nvidia_gpu_profiles() {
    local i pci_devices vendor_id device_id record model memory interface profile
    GPU_PROFILES=()
    GPU_NODE_SUMMARIES=()
    GPU_DETECTION_ERROR=
    GPU_FABRIC_MANAGER=false
    load_gpu_database || {
        GPU_DETECTION_ERROR="Unable to load or verify the pinned Akash GPU device database."
        return 1
    }

    for i in "${!NODE_IPS[@]}"; do
        # shellcheck disable=SC2016 # Variables expand on the remote node.
        pci_devices=$(ssh_to_node "$i" '
            for path in /sys/bus/pci/devices/*; do
                vendor=$(cat "$path/vendor" 2>/dev/null) || continue
                class=$(cat "$path/class" 2>/dev/null) || continue
                case "$class" in 0x0300*|0x0302*) ;; *) continue ;; esac
                device=$(cat "$path/device" 2>/dev/null) || continue
                printf "%s %s\n" "${vendor#0x}" "${device#0x}"
            done
        ' 2>/dev/null) || {
            GPU_DETECTION_ERROR="Unable to inspect PCI hardware on node$((i + 1))."
            return 1
        }
        while read -r vendor_id device_id; do
            [[ -n $vendor_id && ${vendor_id,,} == 10de ]] || continue
            record=$(jq -r --arg vendor "${vendor_id,,}" --arg device "${device_id,,}" \
                '.[$vendor].devices[$device] // empty | [.name, .memory_size, .interface] | @tsv' \
                "$GPU_DATABASE_FILE")
            if [[ -z $record ]]; then
                GPU_DETECTION_ERROR="NVIDIA PCI device ${vendor_id,,}:${device_id,,} on node$((i + 1)) is not in the pinned Akash GPU database."
                return 1
            fi
            IFS=$'\t' read -r model memory interface <<<"$record"
            case "${interface,,}" in
                sxm*) interface=sxm; GPU_FABRIC_MANAGER=true ;;
                pcie*) interface=pcie ;;
                *)
                    GPU_DETECTION_ERROR="Unsupported GPU interface '$interface' for ${model} on node$((i + 1))."
                    return 1
                    ;;
            esac
            profile="$model|$memory|$interface"
            append_gpu_profile "$profile"
            GPU_NODE_SUMMARIES+=("node$((i + 1))|${model} · ${memory} · ${interface} (${vendor_id,,}:${device_id,,})")
        done <<<"$pci_devices"
    done

    ((${#GPU_PROFILES[@]} > 0)) || {
        GPU_DETECTION_ERROR="GPU installation was selected, but no NVIDIA display controller was found on the configured nodes."
        return 1
    }
    CUDA_VERSION=$(version_value gpu_cuda_version)
}

collect_wallet_config() {
    if ! $CONFIG_ONLY; then
        install_akt
        ensure_akt_context
    fi
    ui_screen "7 / 8" "Connect the provider wallet" \
        "Private key material is encoded into the protected generated inventory."
    if $CONFIG_ONLY; then
        ui_note "Configuration-only mode requires pre-encoded key material."
        local choice=4
    else
        ui_option "1" "Use existing key" "Export a key already available to akt"
        ui_option "2" "Create new key" "Generate and export a new provider wallet"
        ui_option "3" "Recover key" "Recover from a mnemonic, then export"
        ui_option "4" "Encoded material" "Enter an address and pre-encoded secrets"
        local choice
        choice=$(ask "Select wallet method" "1")
    fi
    local key_name temp_key keyring_password export_password result_file wallet_error_file mnemonic_file mnemonic
    if [[ $choice == 4 ]]; then
        AKASH_ADDRESS=$(ask_validated "Akash wallet address" "" \
            '^akash1[02-9ac-hj-np-z]{38}$' \
            "Enter a valid lowercase Akash account address beginning with akash1.")
        PROVIDER_B64_KEY=$(ask_secret_base64 "Base64 provider key")
        PROVIDER_B64_KEYSECRET=$(ask_secret_base64 "Base64 key password")
        return
    fi

    key_name=$(ask "Key name" "provider")
    keyring_password=$(ask_secret_confirmed "AKT keyring password")
    export_password=$(openssl rand -hex 32)
    ui_note "The provider export password is generated automatically and stored only in the protected inventory."
    result_file=$(mktemp)
    TEMP_PATHS+=("$result_file")
    chmod 0600 "$result_file"
    wallet_error_file=$(mktemp)
    TEMP_PATHS+=("$wallet_error_file")
    chmod 0600 "$wallet_error_file"
    case "$choice" in
        1)
            if ! run_akt_with_passwords "$keyring_password" "$export_password" \
                "$AKT_BIN" --context "$AKT_CONTEXT" context keys show "$key_name" --address >"$result_file"; then
                die "Unable to unlock or find AKT key '$key_name'."
            fi
            AKASH_ADDRESS=$(tr -d '[:space:]' <"$result_file")
            ;;
        2)
            while true; do
                : >"$result_file"
                : >"$wallet_error_file"
                if run_akt_with_passwords "$keyring_password" "$export_password" \
                    "$AKT_BIN" --context "$AKT_CONTEXT" --output json context keys add "$key_name" \
                    >"$result_file" 2>"$wallet_error_file"; then
                    AKASH_ADDRESS=$(jq -er '.address' "$result_file")
                    mnemonic=$(jq -er '.mnemonic' "$result_file")
                    printf '\n%b      SAVE THIS RECOVERY MNEMONIC%b\n\n      %s\n' "$YELLOW$BOLD" "$NC" "$mnemonic"
                    break
                fi

                if grep -q 'already exists' "$wallet_error_file"; then
                    warn "AKT key '$key_name' already exists."
                    if confirm "Use existing key '$key_name' instead?" y; then
                        : >"$result_file"
                        : >"$wallet_error_file"
                        if run_akt_with_passwords "$keyring_password" "$export_password" \
                            "$AKT_BIN" --context "$AKT_CONTEXT" context keys show "$key_name" --address \
                            >"$result_file" 2>"$wallet_error_file"; then
                            AKASH_ADDRESS=$(tr -d '[:space:]' <"$result_file")
                            break
                        fi
                        cat "$wallet_error_file" >&2
                        warn "Unable to unlock AKT key '$key_name'. Re-enter the keyring password."
                        keyring_password=$(ask_secret_confirmed "AKT keyring password")
                        continue
                    fi
                    key_name=$(ask_required "New key name")
                    continue
                fi

                cat "$wallet_error_file" >&2
                warn "Unable to create AKT key '$key_name'. Correct the key name or password and retry."
                key_name=$(ask_required "Key name" "$key_name")
                keyring_password=$(ask_secret_confirmed "AKT keyring password")
            done
            ;;
        3)
            mnemonic=$(ask_secret "Recovery mnemonic")
            [[ $mnemonic =~ [^[:space:]] ]] || die "Recovery mnemonic cannot be empty."
            mnemonic_file=$(mktemp)
            TEMP_PATHS+=("$mnemonic_file")
            chmod 0600 "$mnemonic_file"
            printf '%s\n' "$mnemonic" >"$mnemonic_file"
            if ! run_akt_with_passwords "$keyring_password" "$export_password" \
                "$AKT_BIN" --context "$AKT_CONTEXT" --output json context keys add "$key_name" \
                --source "$mnemonic_file" >"$result_file"; then
                die "Unable to recover AKT key '$key_name'."
            fi
            AKASH_ADDRESS=$(jq -er '.address' "$result_file")
            ;;
        *) die "Invalid wallet method: $choice" ;;
    esac
    temp_key=$(mktemp)
    TEMP_PATHS+=("$temp_key")
    chmod 0600 "$temp_key"
    if ! run_akt_with_passwords "$keyring_password" "$export_password" \
        "$AKT_BIN" --context "$AKT_CONTEXT" context keys export "$key_name" >"$temp_key"; then
        die "Unable to export AKT key '$key_name'."
    fi
    PROVIDER_B64_KEY=$(openssl base64 -A <"$temp_key")
    rm -f "$temp_key"
    PROVIDER_B64_KEYSECRET=$(printf '%s' "$export_password" | openssl base64 -A)
    [[ $AKASH_ADDRESS =~ ^akash1[02-9ac-hj-np-z]{38}$ ]] || \
        die "AKT returned an invalid Akash account address."
    if ! is_valid_base64 "$PROVIDER_B64_KEY" || ! is_valid_base64 "$PROVIDER_B64_KEYSECRET"; then
        die "AKT returned invalid encoded provider key material."
    fi
    keyring_password=
    export_password=
}

validate_gcp_service_account() {
    local key_path=$1
    if command -v jq >/dev/null 2>&1; then
        jq -e '
            select(
                .type == "service_account" and
                (.project_id | type == "string" and length > 0) and
                (.client_email | type == "string" and length > 0) and
                (.private_key | type == "string" and length > 0)
            )
        ' "$key_path" >/dev/null 2>&1
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c '
import json, sys
with open(sys.argv[1], encoding="utf-8") as stream:
    value = json.load(stream)
required = ("project_id", "client_email", "private_key")
valid = isinstance(value, dict) and value.get("type") == "service_account"
valid = valid and all(isinstance(value.get(key), str) and value[key] for key in required)
raise SystemExit(0 if valid else 1)
' "$key_path" >/dev/null 2>&1
    else
        return 1
    fi
}

collect_acme_config() {
    ui_screen "8 / 8" "Choose certificate automation" \
        "DNS-01 is recommended for production wildcard certificates."
    ui_option "1" "Cloudflare DNS-01" "API-token based certificate issuance"
    ui_option "2" "Google Cloud DNS" "Service-account based certificate issuance"
    ui_option "3" "Self-signed" "Placeholder certificate for initial testing"
    local choice token key_path
    choice=$(ask "Select TLS method" "3")
    ACME_DNS_ZONE=$DOMAIN
    case "$choice" in
        1)
            ACME_DNS_PROVIDER=cloudflare
            ACME_DNS_ZONE=$(ask_validated "DNS zone" "$DOMAIN" \
                '^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' "Enter a valid DNS zone such as example.com.")
            token=$(ask_secret_required "Cloudflare API token")
            ACME_CLOUDFLARE_TOKEN_B64=$(printf '%s' "$token" | openssl base64 -A)
            ;;
        2)
            ACME_DNS_PROVIDER=gcp
            ACME_DNS_ZONE=$(ask_validated "DNS zone" "$DOMAIN" \
                '^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' "Enter a valid DNS zone such as example.com.")
            ACME_GCP_PROJECT=$(ask_required "GCP project ID")
            while true; do
                key_path=$(ask_required "GCP service-account JSON path")
                if [[ ! -r $key_path ]]; then
                    warn "Cannot read $key_path."
                elif ! validate_gcp_service_account "$key_path"; then
                    warn "$key_path is not a Google service-account key."
                else
                    break
                fi
            done
            ACME_GCP_JSON_B64=$(openssl base64 -A <"$key_path")
            ;;
        3) ACME_DNS_PROVIDER=none ;;
        *) die "Invalid TLS method: $choice" ;;
    esac
}

collect_tailscale_config() {
    $INSTALL_TAILSCALE || return 0
    ui_screen "5 / 8" "Connect the private management network" \
        "The authentication key is stored only in the protected inventory."
    TAILSCALE_AUTHKEY=$(ask_secret "Tailscale auth key")
    require_nonempty "Tailscale auth key" "$TAILSCALE_AUTHKEY"
}

write_inventory() {
    local i node_num remote_python_interpreter
    remote_python_interpreter=$(version_value remote_python_interpreter)
    rm -rf "$INVENTORY_DIR"
    mkdir -p "$INVENTORY_DIR/host_vars" "$INVENTORY_DIR/group_vars"
    chmod 0700 "$GENERATED_DIR" "$INVENTORY_DIR" "$INVENTORY_DIR/host_vars" "$INVENTORY_DIR/group_vars"

    {
        printf '[all]\n'
        for i in "${!NODE_IPS[@]}"; do
            node_num=$((i + 1))
            printf 'node%s ansible_host=%s ip=%s access_ip=%s internal_ip=%s ansible_user=%s ansible_port=%s ansible_ssh_private_key_file=%s ansible_python_interpreter=%s\n' \
                "$node_num" "${NODE_IPS[$i]}" "${NODE_INTERNAL_IPS[$i]}" "${NODE_INTERNAL_IPS[$i]}" \
                "${NODE_INTERNAL_IPS[$i]}" "${NODE_USERS[$i]}" "${NODE_PORTS[$i]}" "$SSH_PRIVATE_KEY" \
                "$remote_python_interpreter"
        done
        printf '\n[kube_control_plane]\n'
        for ((i = 1; i <= CONTROL_PLANE_COUNT; i++)); do printf 'node%s etcd_member_name=etcd%s\n' "$i" "$i"; done
        printf '\n[etcd:children]\nkube_control_plane\n\n[kube_node]\n'
        for i in "${!NODE_IPS[@]}"; do printf 'node%s\n' "$((i + 1))"; done
        printf '\n[k8s_cluster:children]\nkube_control_plane\nkube_node\n\n[calico_rr]\n'
    } >"$INVENTORY_FILE"
    chmod 0600 "$INVENTORY_FILE"

    write_group_vars
    write_host_vars
    info "Generated inventory: $INVENTORY_FILE"
}

write_group_vars() {
    local file="$INVENTORY_DIR/group_vars/all.yml"
    {
        printf '%s\n' '---'
        printf 'provider_cluster_mode: %s\n' "$(yaml_quote "$CLUSTER_MODE")"
        printf 'kubelet_root_dir: %s\n' "$(yaml_quote "${KUBELET_DIR:-/var/lib/kubelet}")"
        printf 'k3s_data_dir: %s\n' "$(yaml_quote "${K3S_DATA_DIR:-/var/lib/rancher/k3s}")"
        if $INSTALL_GPU; then
            printf 'gpu_operator_fabric_manager_enabled: %s\n' "$GPU_FABRIC_MANAGER"
        fi
        if $INSTALL_TAILSCALE; then
            printf 'tailscale_authkey: %s\n' "$(yaml_quote "$TAILSCALE_AUTHKEY")"
        fi
        if [[ -n ${TLS_SAN:-} ]]; then
            printf 'tls_san: %s\n' "$(yaml_quote "$TLS_SAN")"
        fi
    } >"$file"
    chmod 0600 "$file"
}

write_host_vars() {
    local i node_num file
    for i in "${!NODE_IPS[@]}"; do
        node_num=$((i + 1))
        file="$INVENTORY_DIR/host_vars/node${node_num}.yml"
        {
            printf '%s\n' '---'
            printf 'internal_ip: %s\n' "$(yaml_quote "${NODE_INTERNAL_IPS[$i]}")"
            printf 'kubernetes_node_name: %s\n' "$(yaml_quote "${KUBERNETES_NODE_NAMES[$i]:-node${node_num}}")"
            printf 'kubernetes_storage_node_name: %s\n' \
                "$(yaml_quote "${KUBERNETES_STORAGE_NODE_NAMES[$i]:-${KUBERNETES_NODE_NAMES[$i]:-node${node_num}}}")"
            if [[ -n ${NODE_EXTERNAL_IPS[$i]:-} && ${NODE_EXTERNAL_IPS[$i]} != "${NODE_INTERNAL_IPS[$i]}" ]]; then
                printf 'external_ip: %s\n' "$(yaml_quote "${NODE_EXTERNAL_IPS[$i]}")"
            fi
            printf 'tailscale_hostname: %s\n' "$(yaml_quote "node${node_num}-${DOMAIN:-akash-provider}")"
            if [[ $node_num == 1 ]] && $INSTALL_PROVIDER; then
                write_provider_vars
            fi
            if [[ $node_num == 1 ]] && $INSTALL_ROOK; then
                write_storage_vars
            fi
        } >"$file"
        chmod 0600 "$file"
    done
}

write_provider_vars() {
    printf 'akash1_address: %s\n' "$(yaml_quote "$AKASH_ADDRESS")"
    printf 'provider_b64_key: %s\n' "$(yaml_quote "$PROVIDER_B64_KEY")"
    printf 'provider_b64_keysecret: %s\n' "$(yaml_quote "$PROVIDER_B64_KEYSECRET")"
    printf 'domain: %s\n' "$(yaml_quote "$DOMAIN")"
    printf 'location_region: %s\n' "$(yaml_quote "$LOCATION_REGION")"
    printf 'organization: %s\n' "$(yaml_quote "$ORGANIZATION")"
    printf 'email: %s\n' "$(yaml_quote "$EMAIL")"
    printf 'website: %s\n' "$(yaml_quote "$WEBSITE")"
    printf 'discord_username: %s\n' "$(yaml_quote "$DISCORD_USERNAME")"
    printf 'status_page: %s\n' "$(yaml_quote "$STATUS_PAGE")"
    printf 'country: %s\n' "$(yaml_quote "${COUNTRY^^}")"
    printf 'city: %s\n' "$(yaml_quote "${CITY^^}")"
    printf 'timezone: %s\n' "$(yaml_quote "$TIMEZONE")"
    printf 'location_type: %s\n' "$(yaml_quote "$LOCATION_TYPE")"
    printf 'hosting_provider: %s\n' "$(yaml_quote "$HOSTING_PROVIDER")"
    printf 'cpu_vendor: %s\n' "$(yaml_quote "$CPU_VENDOR")"
    printf 'cpu_arch: %s\n' "$(yaml_quote "$CPU_ARCH")"
    printf 'memory_type: %s\n' "$(yaml_quote "$MEMORY_TYPE")"
    printf 'network_provider: %s\n' "$(yaml_quote "$NETWORK_PROVIDER")"
    printf 'network_speed_up: %s\n' "$NETWORK_SPEED_UP"
    printf 'network_speed_down: %s\n' "$NETWORK_SPEED_DOWN"
    printf 'has_persistent_storage: %s\n' "$INSTALL_ROOK"
    printf 'storage_class_name: %s\n' "$(yaml_quote "${STORAGE_CLASS:-beta3}")"
    printf 'has_gpu: %s\n' "$INSTALL_GPU"
    if $INSTALL_GPU; then
        printf '%s\n' 'gpu_profiles:'
        local gpu_profile gpu_model gpu_memory gpu_interface
        for gpu_profile in "${GPU_PROFILES[@]}"; do
            IFS='|' read -r gpu_model gpu_memory gpu_interface <<<"$gpu_profile"
            printf '  - model: %s\n' "$(yaml_quote "$gpu_model")"
            printf '    ram: %s\n' "$(yaml_quote "$gpu_memory")"
            printf '    interface: %s\n' "$(yaml_quote "$gpu_interface")"
        done
        printf 'cuda_version: %s\n' "$(yaml_quote "$CUDA_VERSION")"
    fi
    printf 'acme_dns_provider: %s\n' "$(yaml_quote "$ACME_DNS_PROVIDER")"
    printf 'acme_dns_zone: %s\n' "$(yaml_quote "$ACME_DNS_ZONE")"
    if [[ -n ${ACME_CLOUDFLARE_TOKEN_B64:-} ]]; then
        printf 'acme_cloudflare_api_token_b64: %s\n' "$(yaml_quote "$ACME_CLOUDFLARE_TOKEN_B64")"
    fi
    if [[ -n ${ACME_GCP_PROJECT:-} ]]; then
        printf 'acme_gcp_project_id: %s\n' "$(yaml_quote "$ACME_GCP_PROJECT")"
    fi
    if [[ -n ${ACME_GCP_JSON_B64:-} ]]; then
        printf 'acme_gcp_dns_sa_json_b64: %s\n' "$(yaml_quote "$ACME_GCP_JSON_B64")"
    fi
}

write_storage_vars() {
    local node candidate node_index candidate_node_name kubernetes_node_name expected_for_node
    printf 'mon_count: %s\n' "$STORAGE_MON_COUNT"
    printf 'mgr_count: %s\n' "$STORAGE_MGR_COUNT"
    printf 'pool_size: %s\n' "$STORAGE_POOL_SIZE"
    printf 'min_size: %s\n' "$STORAGE_MIN_SIZE"
    printf 'failure_domain: %s\n' "$STORAGE_FAILURE_DOMAIN"
    printf 'device_type: %s\n' "$(yaml_quote "$STORAGE_DEVICE_TYPE")"
    printf 'osds_per_device: %s\n' "$STORAGE_OSDS_PER_DEVICE"
    printf 'expected_osd_count: %s\n' "$STORAGE_EXPECTED_OSD_COUNT"
    printf 'storage_class: %s\n' "$(yaml_quote "$STORAGE_CLASS")"
    printf '%s\n' 'storage_nodes:'
    for node in "${STORAGE_NODES[@]}"; do
        expected_for_node=0
        kubernetes_node_name=
        for candidate in "${STORAGE_SELECTED_CANDIDATES[@]}"; do
            node_index=${STORAGE_CANDIDATE_NODE_INDEXES[$candidate]}
            candidate_node_name=$(storage_node_name_for_index "$node_index")
            if [[ $candidate_node_name == "$node" ]]; then
                expected_for_node=$((expected_for_node + 1))
                kubernetes_node_name=${KUBERNETES_NODE_NAMES[$node_index]:-node$((node_index + 1))}
            fi
        done
        printf '  - name: %s\n' "$(yaml_quote "$node")"
        printf '    kubernetes_node_name: %s\n' "$(yaml_quote "$kubernetes_node_name")"
        printf '    expected_osds: %s\n' "$expected_for_node"
        printf '%s\n' '    devices:'
        for candidate in "${STORAGE_SELECTED_CANDIDATES[@]}"; do
            node_index=${STORAGE_CANDIDATE_NODE_INDEXES[$candidate]}
            candidate_node_name=$(storage_node_name_for_index "$node_index")
            [[ $candidate_node_name == "$node" ]] || continue
            printf '      - name: %s\n' "$(yaml_quote "${STORAGE_CANDIDATE_IDS[$candidate]}")"
        done
    done
}

review_configuration() {
    local i mode_label
    case "$CLUSTER_MODE" in
        kubespray) mode_label='Kubernetes via Kubespray' ;;
        k3s) mode_label='K3s' ;;
        existing) mode_label='Existing Kubernetes' ;;
    esac

    ui_screen "REVIEW" "Ready to generate the installation" \
        "Secrets are redacted. Review the plan before cluster deployment begins."
    ui_key_value "Cluster foundation" "$mode_label"
    ui_key_value "Control planes" "$CONTROL_PLANE_COUNT"
    if [[ $CLUSTER_MODE == k3s ]]; then
        ui_key_value "Kubelet data" "${KUBELET_DIR:-/var/lib/kubelet} (automatic)"
    else
        ui_key_value "Kubelet data" "${KUBELET_DIR:-/var/lib/kubelet}"
    fi
    if [[ $CLUSTER_MODE == kubespray ]]; then
        ui_key_value "Containerd data" "${CONTAINERD_DIR:-/var/lib/containerd}"
    elif [[ $CLUSTER_MODE == k3s ]]; then
        ui_key_value "K3s data" "${K3S_DATA_DIR:-/var/lib/rancher/k3s}"
    fi
    printf '\n%b      HOSTS%b\n' "$BOLD" "$NC"
    for i in "${!NODE_IPS[@]}"; do
        ui_key_value "node$((i + 1))" "${NODE_USERS[$i]}@${NODE_IPS[$i]}:${NODE_PORTS[$i]}"
    done
    printf '\n%b      COMPONENTS%b\n' "$BOLD" "$NC"
    ui_selected "$INSTALL_OS" "OS" "Tuning and maintenance"
    ui_selected "$INSTALL_GPU" "GPU" "NVIDIA GPU Operator"
    ui_selected "$INSTALL_ROOK" "Storage" "Rook-Ceph ${STORAGE_CLASS:-}"
    ui_selected "$INSTALL_PROVIDER" "Provider" "${DOMAIN:-Akash provider stack}"
    ui_selected "$INSTALL_TAILSCALE" "Tailscale" "Private management network"
    if $INSTALL_ROOK; then
        printf '\n%b      STORAGE%b\n' "$BOLD" "$NC"
        ui_key_value "Physical disks / OSDs" "$STORAGE_EXPECTED_OSD_COUNT / $STORAGE_EXPECTED_OSD_COUNT"
        ui_key_value "Storage hosts" "${#STORAGE_NODES[@]}"
        ui_key_value "Replication" "$STORAGE_POOL_SIZE copies across $STORAGE_FAILURE_DOMAIN"
        ui_key_value "Akash class" "$STORAGE_CLASS ($STORAGE_DEVICE_TYPE)"
    fi
    if $INSTALL_PROVIDER; then
        printf '\n%b      PROVIDER%b\n' "$BOLD" "$NC"
        ui_key_value "Wallet" "${AKASH_ADDRESS:0:12}…${AKASH_ADDRESS: -6}"
        ui_key_value "Region" "$LOCATION_REGION"
        ui_key_value "TLS" "$ACME_DNS_PROVIDER"
    fi
    printf '\n'
    confirm "Generate this configuration and continue?" y || die "Installation cancelled during review."
}

configure_kubespray_inventory() {
    local target="$KUBESPRAY_DIR/inventory/akash"
    rm -rf "$target"
    cp -a "$KUBESPRAY_DIR/inventory/sample" "$target"
    cp "$INVENTORY_FILE" "$target/inventory.ini"
    cat >"$target/group_vars/all/akash.yml" <<EOF
upstream_dns_servers:
  - 8.8.8.8
  - 1.1.1.1
EOF
    cat >"$target/group_vars/k8s_cluster/akash.yml" <<EOF
container_manager: containerd
kubelet_custom_flags:
  - "--root-dir=${KUBELET_DIR:-/var/lib/kubelet}"
containerd_storage_dir: "${CONTAINERD_DIR:-/var/lib/containerd}"
EOF
    if [[ -n ${TLS_SAN:-} ]]; then
        printf 'supplementary_addresses_in_ssl_keys:\n  - %s\n' "$TLS_SAN" >>"$target/group_vars/k8s_cluster/akash.yml"
    fi
}

install_tailscale_before_cluster() {
    $INSTALL_TAILSCALE || return 0
    run_project_playbook tailscale
    TLS_SAN=$(ssh_to_node 0 "sudo tailscale ip -4 | head -n 1")
    require_nonempty "Tailscale IPv4 address" "$TLS_SAN"
    write_group_vars
    info "Using $TLS_SAN as the Kubernetes API TLS SAN."
}

install_cluster() {
    case "$CLUSTER_MODE" in
        kubespray)
            setup_kubespray_environment
            configure_kubespray_inventory
            ANSIBLE_CONFIG="$KUBESPRAY_DIR/ansible.cfg" "$KUBESPRAY_DIR/venv/bin/ansible-playbook" \
                --inventory "$KUBESPRAY_DIR/inventory/akash/inventory.ini" "$KUBESPRAY_DIR/cluster.yml" --become
            ;;
        k3s) run_project_playbook k3s ;;
        existing) info "Using the existing Kubernetes cluster." ;;
    esac

    if [[ $CLUSTER_MODE == kubespray ]] && ! $INSTALL_ROOK; then
        run_project_playbook local-path
    fi
}

verify_cluster() {
    ssh_to_node 0 "sudo kubectl get nodes"
}

run_selected_roles() {
    $INSTALL_OS && run_project_playbook os
    $INSTALL_GPU && run_project_playbook gpu
    $INSTALL_ROOK && run_project_playbook rook-ceph
    $INSTALL_PROVIDER && run_project_playbook provider
}

collect_cluster_paths() {
    if [[ $CLUSTER_MODE == kubespray ]]; then
        KUBELET_DIR=$(ask "Kubelet data directory" "/var/lib/kubelet")
        CONTAINERD_DIR=$(ask "Containerd data directory" "/var/lib/containerd")
    elif [[ $CLUSTER_MODE == k3s ]]; then
        KUBELET_DIR=/var/lib/kubelet
        K3S_DATA_DIR=$(ask "K3s data directory" "/var/lib/rancher/k3s")
    else
        KUBELET_DIR=/var/lib/kubelet
        if $INSTALL_ROOK; then
            local detected_kubelet_dir
            # shellcheck disable=SC2016 # The process fields expand on the remote node.
            detected_kubelet_dir=$(ssh_to_node 0 'ps -eo args= | awk '\''
                /[k]ubelet/ {
                    for (i = 1; i <= NF; i++) {
                        if ($i ~ /^--root-dir=/) { sub(/^--root-dir=/, "", $i); print $i; exit }
                        if ($i == "--root-dir" && (i + 1) <= NF) { print $(i + 1); exit }
                    }
                }
            '\''' 2>/dev/null || true)
            [[ -n $detected_kubelet_dir ]] && KUBELET_DIR=$detected_kubelet_dir
        fi
    fi
}

main() {
    display_welcome
    ui_pause "Begin configuration"
    if ! $CONFIG_ONLY; then require_root_linux; fi
    select_components
    collect_nodes
    if ! $CONFIG_ONLY; then
        install_system_prerequisites
    fi
    configure_ssh_access
    collect_node_networking
    detect_kubernetes_node_names
    collect_cluster_paths
    collect_gpu_config
    collect_tailscale_config
    collect_storage_config
    if ! $CONFIG_ONLY; then setup_project_environment; fi
    collect_provider_config
    review_configuration
    write_inventory

    if $CONFIG_ONLY; then
        ui_screen "COMPLETE" "Configuration generated" \
            "No packages or clusters were changed."
        ui_key_value "Inventory" "$INVENTORY_FILE"
        ui_note "Review the generated files carefully; they contain encoded secrets."
        return
    fi

    ui_screen "INSTALL" "Building the provider" \
        "Each phase must become healthy before the next one begins."
    run_project_playbook preflight --extra-vars ansible_python_interpreter=/usr/bin/python3
    install_tailscale_before_cluster
    install_cluster
    verify_cluster
    run_selected_roles
    ui_screen "COMPLETE" "Provider installation finished" \
        "The selected cluster and provider components completed successfully."
    ui_key_value "Inventory" "$INVENTORY_FILE"
    $INSTALL_PROVIDER && ui_key_value "Provider" "https://provider.${DOMAIN}"
    ui_note "Keep the generated inventory private; it contains encoded credentials."
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
