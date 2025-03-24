#!/bin/bash

# Ceph Cluster Questionnaire
# This script will ask questions about your Ceph cluster configuration
# and save the answers in YAML format to ceph_answers.yaml

# Function to handle user input
get_input() {
    local prompt="$1"
    local var_name="$2"
    local input
    
    echo -e "\n$prompt"
    read -r input
    eval "$var_name=\"$input\""
}

# Function to get a list of items
get_list() {
    local prompt="$1"
    local var_name="$2"
    local item
    local items=()
    
    echo -e "\n$prompt"
    echo "Enter items one by one, press enter after each entry. Type 'done' when finished."
    
    while true; do
        read -r item
        if [[ "$item" == "done" ]]; then
            break
        fi
        items+=("$item")
    done
    
    # Convert array to comma-separated string
    local joined=$(printf ", %s" "${items[@]}")
    joined=${joined:2}  # Remove leading ", "
    
    eval "$var_name=\"$joined\""
}

echo "Ceph Cluster Configuration Questionnaire"
echo "========================================"
echo "Please answer the following questions to configure your Ceph cluster."
echo "Your answers will be saved to ceph_answers.yaml"

# Get the number of storage hosts
get_input "How many physical persistent storage hosts are in the cluster?" storage_host_count

# Get storage node names
get_list "What are the storage node names?" storage_node_names

# Get the number of worker nodes
get_input "How many worker nodes that will use persistent storage are in the cluster?" worker_node_count

# Get worker node names
get_list "What are the worker node names?" worker_node_names

# Get device names
get_input "What are the device names that will be used for persistent storage. Add an asterisk after the block device name. (e.g., sd*, nvme*)?" device_names

# Get OSD count per device
get_input "How many OSDs do you want created per device?" osds_per_device

# Get storage device type
get_input "What type of storage devices will be used for persistent storage (hdd, ssd, nvme)?" storage_device_type

# Get ZFS usage for ephemeral storage
get_input "Do your worker nodes use ZFS for ephemeral storage (this is typically no)?" zfs_for_ephemeral

# Write answers to YAML file
cat > answers/ceph_answers.yaml << EOF
cluster_configuration:
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

echo -e "\nThank you for completing the questionnaire."
echo "Your answers have been saved to ceph_answers.yaml"
echo "You can review and edit this file if needed."
