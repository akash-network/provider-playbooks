#!/bin/bash

# Ceph Cluster Questionnaire
# This script will ask questions and save the answers to rook-ceph-defaults.yml

get_input() {
    local prompt="$1"
    local var_name="$2"
    local input
    echo -e "\n$prompt"
    read -r input
    eval "$var_name=\"$input\""
}

get_list() {
    local prompt="$1"
    local var_name="$2"
    local item
    local items=()
    echo -e "\n$prompt"
    echo "Enter items one by one, press enter after each. Type 'done' when finished."
    while true; do
        read -r item
        if [[ "$item" == "done" ]]; then break; fi
        items+=("$item")
    done
    local joined=$(printf ", %s" "${items[@]}")
    joined=${joined:2}
    eval "$var_name=\"$joined\""
}

echo "Ceph Cluster Configuration Questionnaire"
echo "========================================"
echo "Your answers will be saved to rook-ceph-defaults.yml"

# Collect inputs
get_input "How many physical persistent storage hosts are in the cluster?" storage_host_count
get_list "What are the storage node names?" storage_node_names
get_input "How many worker nodes will use persistent storage?" worker_node_count
get_list "What are the worker node names?" worker_node_names
get_input "What are the device names to use (e.g., sd*, nvme*)?" device_names
get_input "How many OSDs per device?" osds_per_device
get_input "What type of storage device (hdd, ssd, nvme)?" storage_device_type
get_input "Do your worker nodes use ZFS for ephemeral storage?" zfs_for_ephemeral
get_input "What is the custom kubeletDirPath for CSI? (default: /var/lib/kubelet)\n[Set this only if you are using a custom node filesystem location, e.g. /data/kubelet]" kubelet_dir_path
kubelet_dir_path=${kubelet_dir_path:-/var/lib/kubelet}

# Write to rook-ceph-defaults.yml
cat > rook-ceph-defaults.yml << EOF
rook_ceph_namespace: rook-ceph
rook_ceph_version: "1.16.6"

ceph_cluster:
  storage_hosts:
    count: $storage_host_count
    node_names: [$storage_node_names]
  worker_nodes:
    count: $worker_node_count
    node_names: [$worker_node_names]
  storage:
    device_names: "$device_names"
    osds_per_device: $osds_per_device
    device_type: "$storage_device_type"
  configuration:
    zfs_for_ephemeral: "$zfs_for_ephemeral"
EOF

echo -e "\nAnswers saved to rook-ceph-defaults.yml"

# --- Begin template rendering ---

ANSWERS_FILE="rook-ceph-defaults.yml"
TEMPLATE_FILE="templates/rook-ceph-cluster.values.tpl"
OUTPUT_FILE="rook-ceph-cluster.values.yml"

if [ ! -f "$ANSWERS_FILE" ]; then
    echo "Error: '$ANSWERS_FILE' not found."
    exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file '$TEMPLATE_FILE' not found."
    exit 1
fi

echo "Reading configuration from $ANSWERS_FILE..."

DEVICE_NAMES=$(grep "device_names:" "$ANSWERS_FILE" | sed 's/.*device_names: *"\([^"]*\)".*/\1/')
DEVICE_TYPE=$(grep "device_type:" "$ANSWERS_FILE" | sed 's/.*device_type: *"\([^"]*\)".*/\1/')
OSDS_PER_DEVICE=$(grep "osds_per_device:" "$ANSWERS_FILE" | sed 's/.*osds_per_device: *\([0-9]*\).*/\1/')
STORAGE_HOSTS_COUNT=$(grep "storage_hosts:" -A 2 "$ANSWERS_FILE" | grep "count:" | sed 's/.*count: *\([0-9]*\).*/\1/')
NODE_NAMES=$(grep "storage_hosts:" -A 2 "$ANSWERS_FILE" | grep "node_names:" | sed -E 's/.*node_names:\s*\[(.*)\]/\1/' | tr ',' ' ' | tr -d '\n')

# Determine MON and MGR counts
if [ "$STORAGE_HOSTS_COUNT" -eq 1 ]; then
    MON_COUNT=1
    MGR_COUNT=1
elif [ "$STORAGE_HOSTS_COUNT" -eq 2 ]; then
    MON_COUNT=2
    MGR_COUNT=2
else
    MON_COUNT=3
    MGR_COUNT=2
fi

STORAGE_CLASS="beta1"
if [ "$DEVICE_TYPE" == "ssd" ]; then
    STORAGE_CLASS="beta2"
elif [ "$DEVICE_TYPE" == "nvme" ]; then
    STORAGE_CLASS="beta3"
fi

if [[ "$DEVICE_NAMES" == "nvme" && ! "$DEVICE_NAMES" =~ \*$ ]]; then
    DEVICE_NAMES="${DEVICE_NAMES}*"
fi
DEVICE_FILTER=$(echo "$DEVICE_NAMES" | sed 's/\*/\*/g' | sed 's/^/^/')

FAILURE_DOMAIN="host"
POOL_SIZE=3
MIN_SIZE=2
if [ "$STORAGE_HOSTS_COUNT" -eq 1 ]; then
    FAILURE_DOMAIN="osd"
    POOL_SIZE=$((OSDS_PER_DEVICE + 1))
    MIN_SIZE=2
fi

NODE_LIST=""
for node in $NODE_NAMES; do
    NODE_LIST="${NODE_LIST}    - name: \"$node\"\n      config: {}\n"
done

cp "$TEMPLATE_FILE" "$OUTPUT_FILE.tmp"
sed -i "s/{{ .POOL_SIZE }}/$POOL_SIZE/g" "$OUTPUT_FILE.tmp"
sed -i "s/{{ .MIN_SIZE }}/$MIN_SIZE/g" "$OUTPUT_FILE.tmp"
sed -i "s|{{ .DEVICE_FILTER }}|$DEVICE_FILTER|g" "$OUTPUT_FILE.tmp"
sed -i "s/{{ .OSDS_PER_DEVICE }}/$OSDS_PER_DEVICE/g" "$OUTPUT_FILE.tmp"
sed -i "s/{{ .FAILURE_DOMAIN }}/$FAILURE_DOMAIN/g" "$OUTPUT_FILE.tmp"
sed -i "s/{{ .STORAGE_CLASS }}/$STORAGE_CLASS/g" "$OUTPUT_FILE.tmp"
sed -i "s/{{ .MON_COUNT }}/$MON_COUNT/g" "$OUTPUT_FILE.tmp"
sed -i "s/{{ .MGR_COUNT }}/$MGR_COUNT/g" "$OUTPUT_FILE.tmp"

awk -v nodes="$NODE_LIST" '{gsub("{{ .NODE_LIST }}", nodes)}1' "$OUTPUT_FILE.tmp" > "$OUTPUT_FILE"
rm "$OUTPUT_FILE.tmp"

echo "Generated rook-ceph-cluster.values.yml successfully."

echo -e "\n📌 CSI kubeletDirPath set to: $kubelet_dir_path"
echo "👉 Please make sure to set the following in your per-node host_vars:"
for node in $NODE_NAMES; do
  echo "   host_vars/${node}.yml:"
  echo "     rook_ceph_kubelet_dir_path: \"$kubelet_dir_path\""
done
