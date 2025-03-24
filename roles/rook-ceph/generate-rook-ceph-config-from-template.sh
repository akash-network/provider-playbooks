#!/bin/bash

# Hard-coded answers file
ANSWERS_FILE="answers/ceph_answers.yaml"
TEMPLATE_FILE="rook_ceph_cluster/templates/rook-ceph-cluster.values.tpl"
OUTPUT_FILE="rook-ceph-cluster.values.yml"

# Check if answers file exists
if [ ! -f "$ANSWERS_FILE" ]; then
    echo "Error: Answers file '$ANSWERS_FILE' not found in current directory."
    exit 1
fi

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file '$TEMPLATE_FILE' not found in rook_ceph_cluster/templates/ directory."
    exit 1
fi

# Extract values using grep and sed instead of yq
echo "Reading configuration from $ANSWERS_FILE..."

# Get device names
DEVICE_NAMES=$(grep "device_names:" "$ANSWERS_FILE" | sed 's/.*device_names: *"\([^"]*\)".*/\1/')
echo "Device names: $DEVICE_NAMES"

# Get device type
DEVICE_TYPE=$(grep "device_type:" "$ANSWERS_FILE" | sed 's/.*device_type: *"\([^"]*\)".*/\1/')
echo "Device type: $DEVICE_TYPE"

# Get osds per device
OSDS_PER_DEVICE=$(grep "osds_per_device:" "$ANSWERS_FILE" | sed 's/.*osds_per_device: *\([0-9]*\).*/\1/')
echo "OSDs per device: $OSDS_PER_DEVICE"

# Get storage hosts count
STORAGE_HOSTS_COUNT=$(grep "count:" "$ANSWERS_FILE" | head -1 | sed 's/.*count: *\([0-9]*\).*/\1/')
echo "Storage hosts count: $STORAGE_HOSTS_COUNT"

# Extract node names correctly
NODE_NAMES=$(grep "storage_hosts:" -A 2 "$ANSWERS_FILE" | grep "node_names:" | sed -E 's/.*node_names:\s*\[(.*)\]/\1/' | tr ',' ' ' | tr -d '\n')
echo "Node names: $NODE_NAMES"

# Set storage class based on device type
STORAGE_CLASS="beta1"  # default for hdd
if [ "$DEVICE_TYPE" == "ssd" ]; then
    STORAGE_CLASS="beta2"
elif [ "$DEVICE_TYPE" == "nvme" ]; then
    STORAGE_CLASS="beta3"
fi
echo "Storage class: $STORAGE_CLASS"

# Process device filter: Append * if not present
if [[ "$DEVICE_NAMES" == "nvme" && ! "$DEVICE_NAMES" =~ \*$ ]]; then
    DEVICE_NAMES="${DEVICE_NAMES}*"
fi
DEVICE_FILTER=$(echo "$DEVICE_NAMES" | sed 's/\*/\*/g' | sed 's/^/^/')
echo "Device filter: $DEVICE_FILTER"


# Set failure domain, size and min_size based on storage hosts count
FAILURE_DOMAIN="host"
POOL_SIZE=3
MIN_SIZE=2

if [ "$STORAGE_HOSTS_COUNT" -eq 1 ]; then
    FAILURE_DOMAIN="osd"
    # When storage hosts count is 1, size and min_size are based on osdsPerDevice
    POOL_SIZE=$((OSDS_PER_DEVICE + 1))
    MIN_SIZE=2
fi
echo "Failure domain: $FAILURE_DOMAIN"
echo "Pool size: $POOL_SIZE"
echo "Min size: $MIN_SIZE"

# Generate node list properly with correct indentation
NODE_LIST=""
for node in $NODE_NAMES; do
    NODE_LIST="${NODE_LIST}    - name: \"$node\"\n      config: {}\n"
done
echo -e "Generated node list:\n$NODE_LIST"

# Create a temporary file with the template
cp "$TEMPLATE_FILE" "$OUTPUT_FILE.tmp"

# Replace Go-style placeholders in the template
sed -i "s/{{ .POOL_SIZE }}/$POOL_SIZE/g" "$OUTPUT_FILE.tmp"
sed -i "s/{{ .MIN_SIZE }}/$MIN_SIZE/g" "$OUTPUT_FILE.tmp"
sed -i "s|{{ .DEVICE_FILTER }}|$DEVICE_FILTER|g" "$OUTPUT_FILE.tmp"
sed -i "s/{{ .OSDS_PER_DEVICE }}/$OSDS_PER_DEVICE/g" "$OUTPUT_FILE.tmp"
sed -i "s/{{ .FAILURE_DOMAIN }}/$FAILURE_DOMAIN/g" "$OUTPUT_FILE.tmp"
sed -i "s/{{ .STORAGE_CLASS }}/$STORAGE_CLASS/g" "$OUTPUT_FILE.tmp"

# Properly replace NODE_LIST while preserving indentation
awk -v nodes="$NODE_LIST" '{gsub("{{ .NODE_LIST }}", nodes)}1' "$OUTPUT_FILE.tmp" > "$OUTPUT_FILE"

# Remove the temporary file
rm "$OUTPUT_FILE.tmp"

echo "Configuration file generated at $OUTPUT_FILE"
