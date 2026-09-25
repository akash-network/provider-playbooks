#!/usr/bin/env bash
# shellcheck disable=SC2317 # Test doubles are invoked indirectly through installer helpers.
set -Eeuo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
export PROVIDER_PLAYBOOKS_GENERATED_DIR="$TEST_ROOT/generated"

# shellcheck source=scripts/setup_provider.sh
source "$REPO_ROOT/scripts/setup_provider.sh"

NODE_IPS=(10.0.0.10 10.0.0.11 10.0.0.12)
NODE_INTERNAL_IPS=(172.20.0.10 172.20.0.11 172.20.0.12)
NODE_EXTERNAL_IPS=(34.1.1.10 34.1.1.11 34.1.1.12)
NODE_USERS=(root ubuntu root)
NODE_PORTS=(22 2222 22)
SSH_PRIVATE_KEY=/tmp/provider-playbooks-test-key
CONTROL_PLANE_COUNT=1
CLUSTER_MODE=kubespray
INSTALL_PROVIDER=false
INSTALL_TAILSCALE=false
INSTALL_ROOK=false
INSTALL_GPU=false
KUBELET_DIR=/var/lib/kubelet

[[ $(version_value akt_version) == 0.1.1 ]]
[[ $(version_value akt_linux_amd64_sha256) == 0ba61ba1de49543698a237b58cc316ea68a3b6fbaeb64203aabb65a1695819b1 ]]
[[ $(version_value helm_install_version) == v4.2.4 ]]
[[ $(version_value helm_install_script) == get-helm-4 ]]
[[ $(version_value local_path_provisioner_version) == v0.0.34 ]]
[[ $(version_value gpu_operator_version) == v26.7.0 ]]
[[ $(version_value gpu_cuda_version) == 13.0 ]]
[[ $(version_value rook_ceph_version) == 1.19.10 ]]
[[ $(version_value rook_ceph_image_tag) == v19.2.6-20260818 ]]
[[ $(version_value rook_ceph_minimum_operator_upgrade_version) == 1.18.0 ]]
[[ $(version_value rook_ceph_target_ceph_version) == 19.2.6-0 ]]
[[ $(version_value gpu_database_commit) == a127142c5b1c0f797e23f70a9947c6fe8285b24a ]]
[[ $(version_value kubernetes_python_version) == 32.0.1 ]]
welcome_output=$(display_welcome)
[[ $welcome_output == *'AKASH // PROVIDER'* ]]
[[ $welcome_output == *'Infrastructure installation console'* ]]
quiet_success=$(run "Quiet command" bash -c 'printf noisy-success')
[[ $quiet_success == *'Quiet command'* ]]
[[ $quiet_success != *'noisy-success'* ]]
if quiet_failure=$(run "Failed command" bash -c 'printf diagnostic-output >&2; exit 7' 2>&1); then
    exit 1
fi
[[ $quiet_failure == *'Failed command'* ]]
[[ $quiet_failure == *'diagnostic-output'* ]]

required_value=$(
    exec 9<<<$'\nprovider-user'
    # shellcheck disable=SC2329 # Invoked indirectly by ask_required.
    ask() { local value; IFS= read -r -u 9 value; printf '%s' "$value"; }
    ask_required "Discord username"
)
[[ $required_value == provider-user ]]
required_secret=$(
    exec 9<<<$'\ncloudflare-token'
    # shellcheck disable=SC2329 # Invoked indirectly by ask_secret_required.
    ask_secret() { local value; IFS= read -r -u 9 value; printf '%s' "$value"; }
    ask_secret_required "Cloudflare API token"
)
[[ $required_secret == cloudflare-token ]]
is_valid_base64 Zm9v
is_valid_base64 Zm9vYmFy
if is_valid_base64 'not-base64!'; then exit 1; fi
if is_valid_base64 ''; then exit 1; fi
encoded_secret=$(
    exec 9<<<$'not-base64!\nZm9v'
    # shellcheck disable=SC2329 # Invoked indirectly by ask_secret_base64.
    ask_secret() { local value; IFS= read -r -u 9 value; printf '%s' "$value"; }
    ask_secret_base64 "Base64 provider key"
)
[[ $encoded_secret == Zm9v ]]
akash_address=$(
    exec 9<<<$'akash1invalid\nakash1u5cdg7k3gl43mukca4aeultuz8x2j68mgwn28e'
    # shellcheck disable=SC2329 # Invoked indirectly by ask_validated.
    ask() { local value; IFS= read -r -u 9 value; printf '%s' "$value"; }
    ask_validated "Akash wallet address" "" '^akash1[02-9ac-hj-np-z]{38}$' \
        "Enter a valid Akash account address."
)
[[ $akash_address == akash1u5cdg7k3gl43mukca4aeultuz8x2j68mgwn28e ]]
gcp_key_file="$TEST_ROOT/gcp-key.json"
printf '%s\n' '{}' >"$gcp_key_file"
if validate_gcp_service_account "$gcp_key_file"; then exit 1; fi
printf '%s\n' \
    '{"type":"service_account","project_id":"test-project","client_email":"provider@example.com","private_key":"secret"}' \
    >"$gcp_key_file"
validate_gcp_service_account "$gcp_key_file"
validated_value=$(
    exec 9<<<$'fast\n1000'
    # shellcheck disable=SC2329 # Invoked indirectly by ask_validated.
    ask() { local value; IFS= read -r -u 9 value; printf '%s' "$value"; }
    ask_validated "Upload speed Mbps" "1000" '^[0-9]+$' "Upload speed must be numeric."
)
[[ $validated_value == 1000 ]]
python3 "$REPO_ROOT/tests/test_akt_password_helper.py"

map_location_country europe DE
[[ $LOCATION_COUNTRY == DE && $LOCATION_REGION == eu-central ]]
map_location_country south-america BR
[[ $LOCATION_COUNTRY == BR && $LOCATION_REGION == sa-brazil ]]
map_location_country africa ZA
[[ $LOCATION_COUNTRY == ZA && $LOCATION_REGION == af-south ]]
map_location_country asia SG
[[ $LOCATION_COUNTRY == SG && $LOCATION_REGION == as-southeast ]]
map_location_country oceania AU
[[ $LOCATION_COUNTRY == AU && $LOCATION_REGION == oc-aus ]]
map_north_america_subdivision US IL
[[ $LOCATION_COUNTRY == US && $LOCATION_REGION == na-us-midwest ]]
map_north_america_subdivision CA BC
[[ $LOCATION_COUNTRY == CA && $LOCATION_REGION == na-ca-west ]]
is_valid_location_region na-us-midwest
if is_valid_location_region made-up-region; then
    exit 1
fi
[[ $(city_code_from_name 'New York') == NYC ]]
[[ $(city_code_from_name Chicago) == CHI ]]
[[ $(city_code_from_name 'Zürich') == ZRH ]]
[[ $(city_code_from_name 'São Paulo') == SAO ]]
[[ $(city_code_from_name 'Łódź') == LOD ]]
if city_code_from_name '東京' >/dev/null; then exit 1; fi
[[ $(timezone_from_utc_offset -0600) == utc-6 ]]
[[ $(timezone_from_utc_offset +0530) == utc+6 ]]
is_private_ipv4 10.20.30.40
is_private_ipv4 172.31.0.1
is_private_ipv4 192.168.10.2
if is_private_ipv4 34.174.84.54; then
    exit 1
fi

(
    CLUSTER_MODE=existing
    NODE_IPS=(34.1.1.10 34.1.1.11)
    detect_node_private_ips() { return 99; }
    detect_node_public_ip() { return 99; }
    collect_node_networking
    [[ ${NODE_INTERNAL_IPS[*]} == '34.1.1.10 34.1.1.11' ]]
    [[ ${NODE_EXTERNAL_IPS[*]} == '34.1.1.10 34.1.1.11' ]]
)

(
    CLUSTER_MODE=existing
    NODE_IPS=(34.1.1.10 34.1.1.10)
    NODE_INTERNAL_IPS=(34.1.1.10 34.1.1.10)
    NODE_EXTERNAL_IPS=(34.1.1.10 34.1.1.10)
    ssh_to_node() {
        local index=$1 command=$2
        if [[ $command == *'kubectl get nodes'* ]]; then
            printf '%s\n' \
                'provider-a host-a 10.0.0.10 34.1.1.10' \
                'provider-b host-b 10.0.0.11 34.1.1.10'
        elif [[ $index == 0 ]]; then
            printf '%s\n' host-a host-a.example
        else
            printf '%s\n' host-b host-b.example
        fi
    }
    detect_kubernetes_node_names
    [[ ${KUBERNETES_NODE_NAMES[*]} == 'provider-a provider-b' ]]
    [[ ${KUBERNETES_STORAGE_NODE_NAMES[*]} == 'host-a host-b' ]]
)

(
    CLUSTER_MODE=existing
    INSTALL_ROOK=true
    NODE_IPS=(10.0.0.10 10.0.0.11)
    NODE_INTERNAL_IPS=(10.0.0.10 10.0.0.11)
    NODE_EXTERNAL_IPS=(34.1.1.10 34.1.1.11)
    ssh_to_node() {
        local index=$1 command=$2
        if [[ $command == *'kubectl get nodes'* ]]; then
            printf '%s\n' \
                'metadata-b host-a 10.0.0.10 34.1.1.10' \
                'host-a host-b 10.0.0.11 34.1.1.11'
        elif [[ $index == 0 ]]; then
            printf '%s\n' host-a host-a.example
        else
            printf '%s\n' host-b host-b.example
        fi
    }
    detect_kubernetes_node_names
    [[ ${KUBERNETES_NODE_NAMES[*]} == 'metadata-b host-a' ]]
    [[ ${KUBERNETES_STORAGE_NODE_NAMES[*]} == 'host-a host-b' ]]
)

(
    CLUSTER_MODE=existing
    INSTALL_ROOK=false
    NODE_IPS=(10.0.0.10)
    NODE_INTERNAL_IPS=(10.0.0.10)
    NODE_EXTERNAL_IPS=(34.1.1.10)
    ssh_to_node() {
        if [[ $2 == *'kubectl get nodes'* ]]; then
            printf '%s\n' \
                'node-a shared 10.0.0.10 34.1.1.10' \
                'shared node-b 10.0.0.11 34.1.1.11' \
                'node-c shared 10.0.0.12 34.1.1.12'
        else
            printf '%s\n' shared shared.example
        fi
    }
    detect_kubernetes_node_names
    [[ ${KUBERNETES_NODE_NAMES[*]} == 'node-a' ]]
    [[ ${KUBERNETES_STORAGE_NODE_NAMES[*]} == 'shared' ]]
)

if (
    CLUSTER_MODE=existing
    INSTALL_ROOK=true
    NODE_IPS=(10.0.0.10)
    NODE_INTERNAL_IPS=(10.0.0.10)
    NODE_EXTERNAL_IPS=(34.1.1.10)
    ssh_to_node() {
        if [[ $2 == *'kubectl get nodes'* ]]; then
            printf '%s\n' \
                'node-a shared 10.0.0.10 34.1.1.10' \
                'shared node-b 10.0.0.11 34.1.1.11' \
                'node-c shared 10.0.0.12 34.1.1.12'
        else
            printf '%s\n' shared shared.example
        fi
    }
    detect_kubernetes_node_names
); then
    exit 1
fi

if (
    CLUSTER_MODE=existing
    INSTALL_ROOK=true
    NODE_IPS=(10.0.0.10)
    NODE_INTERNAL_IPS=(10.0.0.10)
    NODE_EXTERNAL_IPS=(10.0.0.10)
    ssh_to_node() {
        if [[ $* == *'kubectl get nodes'* ]]; then
            printf '%s\n' 'provider-a <none> 10.0.0.10 <none>'
        else
            printf '%s\n' provider-a
        fi
    }
    detect_kubernetes_node_names
); then
    exit 1
fi

(
    CLUSTER_MODE=existing
    INSTALL_ROOK=true
    ssh_to_node() { printf '%s\n' /srv/kubelet; }
    collect_cluster_paths
    [[ $KUBELET_DIR == /srv/kubelet ]]
)

(
    CLUSTER_MODE=existing
    INSTALL_ROOK=false
    ssh_to_node() { return 99; }
    collect_cluster_paths
    [[ $KUBELET_DIR == /var/lib/kubelet ]]
)

(
    # shellcheck disable=SC2329 # Invoked indirectly by location detection.
    ssh_to_node() {
        if [[ $* == *ipwho.is* ]]; then
            printf '%s' '{"success":false,"message":"rate limited"}'
        else
            printf '%s' '{"country_code":"US","region_code":"TX","city":"Dallas","utc_offset":"-0500","continent_code":"NA"}'
        fi
    }
    detect_provider_location
    [[ $LOCATION_COUNTRY == US && $LOCATION_REGION == na-us-southwest ]]
    [[ $CITY == DAL && $TIMEZONE == utc-5 ]]
    [[ $LOCATION_DETECTION_ERROR == *'ipwho: rate limited'* ]]
)

(
    # shellcheck disable=SC2329 # Invoked indirectly by location detection.
    ssh_to_node() { printf '%s' '{"success":false,"message":"unavailable"}'; }
    if detect_provider_location; then
        exit 1
    fi
    [[ $LOCATION_DETECTION_ERROR == *'ipwho: unavailable'* ]]
    [[ $LOCATION_DETECTION_ERROR == *'ipapi: unavailable'* ]]
)

controller_home="$TEST_ROOT/controller"
mkdir -p "$controller_home"
# shellcheck disable=SC2329 # Invoked indirectly by select_or_create_ssh_key.
getent() { printf 'root:x:0:0::%s:/bin/bash\n' "$controller_home"; }
select_or_create_ssh_key
[[ $SSH_PRIVATE_KEY == "$controller_home/.ssh/provider_playbooks_ed25519" ]]
[[ -s $SSH_PRIVATE_KEY && -s $SSH_PRIVATE_KEY.pub ]]
first_public_key=$SSH_PUBLIC_KEY
printf '%s\n' 'ssh-ed25519 stale-public-key' >"$SSH_PRIVATE_KEY.pub"
select_or_create_ssh_key
[[ $SSH_PUBLIC_KEY == "$first_public_key" ]]
unset -f getent

# shellcheck disable=SC2329 # Invoked indirectly by ssh_to_node.
ssh() {
    if [[ $* == *lscpu* ]]; then
        printf '%s\n' 'Architecture:        x86_64' 'Vendor ID:           AuthenticAMD'
    else
        printf '%s\n' 'Error Correction Type: Multi-bit ECC' 'Type: DDR5'
    fi
}
detect_provider_hardware
[[ $CPU_VENDOR == amd && $CPU_ARCH == x86-64 && $MEMORY_TYPE == ddr5ecc ]]
unset -f ssh

AKASH_ADDRESS=akash1test
PROVIDER_B64_KEY=test-key
PROVIDER_B64_KEYSECRET=test-secret
DOMAIN=test.example
LOCATION_REGION=na-us-southwest
ORGANIZATION='test'
EMAIL=test@example.com
WEBSITE=https://test.example
DISCORD_USERNAME='test'
STATUS_PAGE=https://status.test.example
COUNTRY=US
CITY=DAL
TIMEZONE=utc-5
LOCATION_TYPE=datacenter
HOSTING_PROVIDER='test'
CPU_VENDOR=amd
CPU_ARCH=x86-64
MEMORY_TYPE=ddr5ecc
NETWORK_PROVIDER='test'
NETWORK_SPEED_UP=1000
NETWORK_SPEED_DOWN=1000
ACME_DNS_PROVIDER=none
ACME_DNS_ZONE=test.example
provider_vars_file="$TEST_ROOT/provider-vars.yml"
write_provider_vars >"$provider_vars_file"
grep -q "^acme_dns_provider: 'none'$" "$provider_vars_file"
grep -q '^install_akash_node: false$' "$provider_vars_file"
if grep -q '^acme_.*_b64:' "$provider_vars_file"; then
    exit 1
fi

write_inventory

grep -q '^node1 ansible_host=10.0.0.10 ip=172.20.0.10 access_ip=172.20.0.10 internal_ip=172.20.0.10' "$INVENTORY_FILE"
grep -q '^node2 ansible_host=10.0.0.11 ip=172.20.0.11 access_ip=172.20.0.11 internal_ip=172.20.0.11' "$INVENTORY_FILE"
grep -q '^node3 ansible_host=10.0.0.12 ip=172.20.0.12 access_ip=172.20.0.12 internal_ip=172.20.0.12' "$INVENTORY_FILE"
grep -q "ansible_ssh_private_key_file=$SSH_PRIVATE_KEY" "$INVENTORY_FILE"
grep -q 'ansible_python_interpreter=/opt/provider-playbooks/venv/bin/python3' "$INVENTORY_FILE"
grep -q "^internal_ip: '172.20.0.10'$" "$INVENTORY_DIR/host_vars/node1.yml"
grep -q "^kubernetes_node_name: 'node1'$" "$INVENTORY_DIR/host_vars/node1.yml"
grep -q "^external_ip: '34.1.1.10'$" "$INVENTORY_DIR/host_vars/node1.yml"
grep -q '^node1 etcd_member_name=etcd1$' "$INVENTORY_FILE"
worker_nodes=$(awk '/^\[kube_node\]$/{inside=1; next} /^\[/{inside=0} inside && /^node/{print $1}' "$INVENTORY_FILE")
[[ $worker_nodes == $'node1\nnode2\nnode3' ]]
inventory_mode=$(stat -c '%a' "$INVENTORY_FILE" 2>/dev/null || stat -f '%Lp' "$INVENTORY_FILE")
[[ $inventory_mode == 600 ]]

NODE_IPS=(10.0.0.10)
NODE_INTERNAL_IPS=(172.20.0.10)
NODE_EXTERNAL_IPS=(34.1.1.10)
NODE_USERS=(root)
NODE_PORTS=(22)
CONTROL_PLANE_COUNT=1
write_inventory
[[ $(awk '/^\[kube_control_plane\]$/{inside=1; next} /^\[/{inside=0} inside && /^node/{print $1}' "$INVENTORY_FILE") == node1 ]]
[[ $(awk '/^\[kube_node\]$/{inside=1; next} /^\[/{inside=0} inside && /^node/{print $1}' "$INVENTORY_FILE") == node1 ]]

NODE_IPS=(10.0.0.10 10.0.0.11)
NODE_INTERNAL_IPS=(172.20.0.10 172.20.0.11)
NODE_EXTERNAL_IPS=(34.1.1.10 34.1.1.11)
NODE_USERS=(root ubuntu)
NODE_PORTS=(22 2222)
CONTROL_PLANE_COUNT=1
write_inventory
[[ $(awk '/^\[kube_control_plane\]$/{inside=1; next} /^\[/{inside=0} inside && /^node/{print $1}' "$INVENTORY_FILE") == node1 ]]
[[ $(awk '/^\[kube_node\]$/{inside=1; next} /^\[/{inside=0} inside && /^node/{print $1}' "$INVENTORY_FILE") == $'node1\nnode2' ]]

NODE_IPS=(10.0.0.10 10.0.0.11 10.0.0.12)
NODE_INTERNAL_IPS=(172.20.0.10 172.20.0.11 172.20.0.12)
NODE_EXTERNAL_IPS=(34.1.1.10 34.1.1.11 34.1.1.12)
NODE_USERS=(root ubuntu root)
NODE_PORTS=(22 2222 22)
CONTROL_PLANE_COUNT=3
write_inventory
[[ $(awk '/^\[kube_control_plane\]$/{inside=1; next} /^\[/{inside=0} inside && /^node/{print $1}' "$INVENTORY_FILE") == $'node1\nnode2\nnode3' ]]
[[ $(awk '/^\[kube_node\]$/{inside=1; next} /^\[/{inside=0} inside && /^node/{print $1}' "$INVENTORY_FILE") == $'node1\nnode2\nnode3' ]]

INSTALL_ROOK=true
KUBERNETES_NODE_NAMES=(provider-a provider-b provider-c)
KUBERNETES_STORAGE_NODE_NAMES=(host-a host-b host-c)
STORAGE_CANDIDATE_NODE_INDEXES=(0 1 2)
STORAGE_CANDIDATE_PATHS=(/dev/nvme0n1 /dev/nvme0n1 /dev/nvme0n1)
STORAGE_CANDIDATE_IDS=(/dev/disk/by-id/nvme-one /dev/disk/by-id/nvme-two /dev/disk/by-id/nvme-three)
STORAGE_CANDIDATE_TYPES=(nvme nvme nvme)
STORAGE_CANDIDATE_SIZES=(107374182400 107374182400 107374182400)
STORAGE_CANDIDATE_MODELS=(Fast Fast Fast)
STORAGE_SELECTED_CANDIDATES=(0 1 2)
CONTROL_PLANE_COUNT=1
derive_storage_layout
[[ $STORAGE_POOL_SIZE == 3 && $STORAGE_FAILURE_DOMAIN == host ]]
[[ $STORAGE_EXPECTED_OSD_COUNT == 3 && $STORAGE_OSDS_PER_DEVICE == 1 ]]
[[ $STORAGE_MON_COUNT == 3 ]]
write_inventory
grep -q '^storage_nodes:$' "$INVENTORY_DIR/host_vars/node1.yml"
grep -q "^  - name: 'host-a'$" "$INVENTORY_DIR/host_vars/node1.yml"
grep -q "^    kubernetes_node_name: 'provider-a'$" "$INVENTORY_DIR/host_vars/node1.yml"
grep -q "^      - name: '/dev/disk/by-id/nvme-one'$" "$INVENTORY_DIR/host_vars/node1.yml"
grep -q '^expected_osd_count: 3$' "$INVENTORY_DIR/host_vars/node1.yml"
grep -q "^storage_class: 'beta3'$" "$INVENTORY_DIR/host_vars/node1.yml"

(
    NODE_IPS=(10.0.0.10 10.0.0.11 10.0.0.12)
    KUBERNETES_NODE_NAMES=(provider-a provider-b provider-c)
    KUBERNETES_STORAGE_NODE_NAMES=(host-a host-b host-c)
    CONTROL_PLANE_COUNT=3
    ssh_to_node() { return 0; }
    load_previous_storage_layout
    [[ ${STORAGE_CANDIDATE_IDS[*]} == '/dev/disk/by-id/nvme-one /dev/disk/by-id/nvme-two /dev/disk/by-id/nvme-three' ]]
    [[ $STORAGE_EXPECTED_OSD_COUNT == 3 && $STORAGE_POOL_SIZE == 3 ]]
    [[ ${STORAGE_NODES[*]} == 'host-a host-b host-c' ]]
)

new_storage_vars="$TEST_ROOT/new-storage-vars.yml"
cp "$INVENTORY_DIR/host_vars/node1.yml" "$new_storage_vars"
sed -e '/^    kubernetes_node_name: /d' \
    -e "s/^  - name: 'host-a'$/  - name: 'provider-a'/" \
    -e "s/^  - name: 'host-b'$/  - name: 'provider-b'/" \
    -e "s/^  - name: 'host-c'$/  - name: 'provider-c'/" \
    "$new_storage_vars" >"$INVENTORY_DIR/host_vars/node1.yml"
(
    NODE_IPS=(10.0.0.10 10.0.0.11 10.0.0.12)
    KUBERNETES_NODE_NAMES=(provider-a provider-b provider-c)
    KUBERNETES_STORAGE_NODE_NAMES=(host-a host-b host-c)
    ssh_to_node() { return 0; }
    load_previous_storage_layout
    [[ ${STORAGE_CANDIDATE_IDS[*]} == '/dev/disk/by-id/nvme-one /dev/disk/by-id/nvme-two /dev/disk/by-id/nvme-three' ]]
    [[ ${STORAGE_NODES[*]} == 'host-a host-b host-c' ]]
)
cp "$new_storage_vars" "$INVENTORY_DIR/host_vars/node1.yml"

volatile_storage_vars="$TEST_ROOT/volatile-storage-vars.yml"
sed 's#/dev/disk/by-id/nvme-one#/dev/nvme0n1#' \
    "$INVENTORY_DIR/host_vars/node1.yml" >"$volatile_storage_vars"
cp "$volatile_storage_vars" "$INVENTORY_DIR/host_vars/node1.yml"
if (
    NODE_IPS=(10.0.0.10 10.0.0.11 10.0.0.12)
    KUBERNETES_NODE_NAMES=(provider-a provider-b provider-c)
    KUBERNETES_STORAGE_NODE_NAMES=(host-a host-b host-c)
    ssh_to_node() { return 0; }
    load_previous_storage_layout
); then
    exit 1
fi
cp "$new_storage_vars" "$INVENTORY_DIR/host_vars/node1.yml"

(
    NODE_IPS=(10.0.0.10 10.0.0.11 10.0.0.12)
    scan_storage_node() {
        case "$1" in
            0) printf '%s\n' $'excluded\t/dev/sda\t/dev/disk/by-id/os\tssd\t53687091200\tBoot disk\tcontains partitions or mapped children' \
                $'eligible\t/dev/nvme0n1\t/dev/disk/by-id/nvme-a\tnvme\t107374182400\tFast disk\t' ;;
            1) printf '%s\n' $'eligible\t/dev/nvme0n1\t/dev/disk/by-id/nvme-b\tnvme\t107374182400\tFast disk\t' ;;
            2) printf '%s\n' $'eligible\t/dev/sdb\t/dev/disk/by-id/ssd-c\tssd\t107374182400\tSSD\t' ;;
        esac
    }
    discover_storage_devices
    [[ ${#STORAGE_CANDIDATE_PATHS[@]} == 3 ]]
    [[ ${#STORAGE_EXCLUDED_PATHS[@]} == 1 ]]
    recommend_storage_candidates
    [[ $STORAGE_RECOMMENDED_TYPE == mixed ]]
    [[ ${STORAGE_RECOMMENDED_CANDIDATES[*]} == '0 1 2' ]]
    if validate_storage_candidate_selection '1 1'; then exit 1; fi
    validate_storage_candidate_selection '1 2'
    KUBERNETES_NODE_NAMES=(worker-a worker-b worker-c)
    KUBERNETES_STORAGE_NODE_NAMES=(host-a host-b host-c)
    CONTROL_PLANE_COUNT=3
    derive_storage_layout
    [[ ${STORAGE_NODES[*]} == 'host-a host-b' ]]
    [[ $STORAGE_POOL_SIZE == 2 && $STORAGE_FAILURE_DOMAIN == host ]]
    [[ $STORAGE_EXPECTED_OSD_COUNT == 2 ]]
)

(
    STORAGE_CANDIDATE_NODE_INDEXES=(0)
    STORAGE_CANDIDATE_PATHS=(/dev/nvme0n1)
    STORAGE_CANDIDATE_TYPES=(nvme)
    if recommend_storage_candidates; then exit 1; fi
)

(
    NODE_IPS=(10.0.0.10)
    KUBERNETES_NODE_NAMES=(worker-a)
    KUBERNETES_STORAGE_NODE_NAMES=(host-a)
    STORAGE_CANDIDATE_NODE_INDEXES=(0 0)
    STORAGE_CANDIDATE_PATHS=(/dev/nvme0n1 /dev/nvme1n1)
    STORAGE_CANDIDATE_IDS=(/dev/disk/by-id/nvme-one /dev/disk/by-id/nvme-two)
    STORAGE_CANDIDATE_TYPES=(nvme nvme)
    STORAGE_CANDIDATE_SIZES=(107374182400 107374182400)
    STORAGE_CANDIDATE_MODELS=(Fast Fast)
    recommend_storage_candidates
    [[ $STORAGE_RECOMMENDED_TYPE == nvme ]]
    [[ ${STORAGE_RECOMMENDED_CANDIDATES[*]} == '0 1' ]]
    STORAGE_SELECTED_CANDIDATES=(0 1)
    derive_storage_layout
    [[ ${STORAGE_NODES[*]} == host-a ]]
    [[ $STORAGE_EXPECTED_OSD_COUNT == 2 && $STORAGE_OSDS_PER_DEVICE == 1 ]]
    [[ $STORAGE_POOL_SIZE == 2 && $STORAGE_MIN_SIZE == 1 ]]
    [[ $STORAGE_FAILURE_DOMAIN == osd ]]
)

INSTALL_ROOK=false
INSTALL_GPU=true
GPU_FABRIC_MANAGER=false
PROVIDER_GPU_DATABASE_FILE="$REPO_ROOT/tests/fixtures/gpus.json"
ssh_to_node() { printf '%s\n' '10de 2330'; }
collect_gpu_config
[[ $GPU_FABRIC_MANAGER == true ]]
[[ ${GPU_PROFILES[*]} == 'h100|80Gi|sxm' ]]
[[ $CUDA_VERSION == 13.0 ]]
ssh_to_node() { printf '%s\n' '10de 1eb8'; }
detect_nvidia_gpu_profiles
[[ $GPU_FABRIC_MANAGER == false ]]
[[ ${GPU_PROFILES[*]} == 't4|16Gi|pcie' ]]
unset PROVIDER_GPU_DATABASE_FILE
unset -f ssh_to_node
confirm() { return 0; }
review_output=$(review_configuration)
[[ $review_output == *'Ready to generate the installation'* ]]
[[ $review_output == *'COMPONENTS'* ]]
write_inventory
grep -q "^provider_cluster_mode: 'kubespray'$" "$INVENTORY_DIR/group_vars/all.yml"
grep -q '^gpu_operator_fabric_manager_enabled: false$' "$INVENTORY_DIR/group_vars/all.yml"
gpu_provider_vars=$(write_provider_vars)
[[ $gpu_provider_vars == *"  - model: 't4'"* ]]
[[ $gpu_provider_vars == *"    ram: '16Gi'"* ]]
[[ $gpu_provider_vars == *"    interface: 'pcie'"* ]]
if grep -q '^gpu_operator_fabric_manager_enabled:' "$INVENTORY_DIR/host_vars/node1.yml"; then
    exit 1
fi

grep -q "'volumeBindingMode: WaitForFirstConsumer'" "$REPO_ROOT/roles/local-path/tasks/main.yml"
if grep -q 'volumeBindingMode: Immediate' "$REPO_ROOT/roles/local-path/tasks/main.yml"; then
    exit 1
fi
if grep -q 'kubectl.*patch' "$REPO_ROOT/roles/local-path/tasks/main.yml"; then
    exit 1
fi
grep -q 'generateName: akash-storage-preflight-' "$REPO_ROOT/roles/provider/tasks/validate_storage.yml"
if grep -q 'name: akash-storage-preflight$' "$REPO_ROOT/roles/provider/tasks/validate_storage.yml"; then
    exit 1
fi
grep -q "loop:.*groups\['kube_node'\]" "$REPO_ROOT/roles/rook-ceph/tasks/rook_ceph_finalize.yaml"
grep -q "item.kubernetes_node_name.*default(item.name)" \
    "$REPO_ROOT/roles/rook-ceph/tasks/rook_ceph_cluster.yaml"
grep -q 'Wait for the requested CephX daemon-key rotation' \
    "$REPO_ROOT/roles/rook-ceph/tasks/rook_ceph_cluster.yaml"
grep -q "get('keyType', '') == 'aes256k'" \
    "$REPO_ROOT/roles/rook-ceph/tasks/rook_ceph_cluster.yaml"
grep -q "does not expose a stable /dev/disk/by-id identity" "$REPO_ROOT/scripts/lib/storage.sh"
# shellcheck disable=SC2016 # This intentionally checks for the removed literal fallback.
if grep -q 'stable_path=${stable_path:-$device}' "$REPO_ROOT/scripts/lib/storage.sh"; then
    exit 1
fi
legacy_cli='provider''-services'
if grep -R -q "$legacy_cli" "$REPO_ROOT/scripts" "$REPO_ROOT/roles/op/README.md"; then
    exit 1
fi
grep -q 'context keys export' "$REPO_ROOT/scripts/setup_provider.sh"
grep -q "Use existing key '\$key_name' instead?" "$REPO_ROOT/scripts/setup_provider.sh"
# shellcheck disable=SC2016 # Verify the literal Bash assignment in the installer source.
grep -q 'key_name=$(ask_required "New key name")' "$REPO_ROOT/scripts/setup_provider.sh"
if grep -R -q 'HELM_INSTALL_VERSION' "$REPO_ROOT/roles"; then
    exit 1
fi
[[ $(grep -R -l 'DESIRED_VERSION:.*helm_install_version' "$REPO_ROOT/roles" | wc -l | tr -d ' ') == 3 ]]
akash_node_task=$(sed -n '/^- name: Install Akash node$/,/^- name: /p' "$REPO_ROOT/roles/provider/tasks/install.yml")
[[ $akash_node_task == *'wait: false'* ]]
[[ $akash_node_task != *'wait_timeout:'* ]]
[[ $akash_node_task == *'when: install_akash_node | bool'* ]]
akash_provider_task=$(sed -n '/^- name: Install Akash provider using Helm$/,/^- name: /p' "$REPO_ROOT/roles/provider/tasks/install.yml")
[[ $akash_provider_task == *'wait: false'* ]]
[[ $akash_provider_task != *'wait_timeout:'* ]]
gpu_operator_task=$(sed -n '/^- name: Install NVIDIA GPU Operator$/,/^- name: /p' "$REPO_ROOT/roles/gpu/tasks/main.yml")
[[ $gpu_operator_task == *'wait: false'* ]]
[[ $gpu_operator_task != *'wait_timeout:'* ]]
if grep -q '^- name: Wait for allocatable GPUs$' "$REPO_ROOT/roles/gpu/tasks/main.yml"; then
    exit 1
fi
grep -q '^      - apply$' "$REPO_ROOT/roles/gpu/tasks/main.yml"
grep -q 'Apply pinned GPU Operator CRDs before Helm install or upgrade' "$REPO_ROOT/roles/gpu/tasks/main.yml"
grep -q 'node-feature-discovery/crds/nfd-api-crds.yaml' "$REPO_ROOT/roles/gpu/tasks/main.yml"
grep -q 'context network create mainnet --template mainnet' "$REPO_ROOT/scripts/lib/bootstrap.sh"
grep -q 'tag --points-at HEAD --list' "$REPO_ROOT/scripts/lib/bootstrap.sh"
grep -q 'Removing the stale Kubespray Python environment' "$REPO_ROOT/scripts/lib/bootstrap.sh"
grep -q '.provider-playbooks-version' "$REPO_ROOT/scripts/lib/bootstrap.sh"
grep -q "master_ip:.*internal_ip" "$REPO_ROOT/roles/k3s/tasks/k3s-worker.yml"
main_body=$(sed -n '/^main() {/,/^}/p' "$REPO_ROOT/scripts/setup_provider.sh")
ssh_line=$(grep -n 'configure_ssh_access' <<<"$main_body" | cut -d: -f1)
network_line=$(grep -n 'collect_node_networking' <<<"$main_body" | cut -d: -f1)
[[ $ssh_line -lt $network_line ]]
grep -q 'PasswordAuthentication=no' "$REPO_ROOT/scripts/setup_provider.sh"
if grep -R -q sshpass "$REPO_ROOT/scripts"; then
    exit 1
fi
if grep -q 'internal_ip: "{{ ansible_host }}"' "$REPO_ROOT/roles/k3s/tasks/prechecks.yml"; then
    exit 1
fi

setup_kubespray_environment() { printf 'unexpected Kubespray call\n' >&2; return 99; }
declare -a playbook_calls=()
run_project_playbook() { playbook_calls+=("$1"); }
CLUSTER_MODE=k3s
INSTALL_ROOK=false
install_cluster
[[ ${playbook_calls[*]} == k3s ]]

INSTALL_OS=true
INSTALL_GPU=true
INSTALL_ROOK=true
INSTALL_PROVIDER=true
run_selected_roles
[[ ${playbook_calls[*]} == "k3s os gpu rook-ceph provider" ]]

prompt_log="$TEST_ROOT/path-prompts"
ask() {
    printf '%s\n' "$1" >>"$prompt_log"
    printf '%s' "$2"
}
CLUSTER_MODE=k3s
collect_cluster_paths
grep -q '^K3s data directory$' "$prompt_log"
if grep -q '^Kubelet data directory$' "$prompt_log"; then
    exit 1
fi
[[ $KUBELET_DIR == /var/lib/kubelet ]]

printf 'installer tests passed\n'
