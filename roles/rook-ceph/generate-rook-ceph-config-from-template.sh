#!/bin/bash

# Hard-coded answers file
ANSWERS_FILE="ceph_answers.yaml"
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

# Extract node names
NODE_NAMES_LINE=$(grep "node_names:" "$ANSWERS_FILE" | head -1)
NODE_NAMES=$(echo "$NODE_NAMES_LINE" | sed 's/.*node_names: *\[\([^]]*\)\].*/\1/' | sed 's/,/ /g')
echo "Node names: $NODE_NAMES"

# Set storage class based on device type
STORAGE_CLASS="beta1"  # default for hdd
if [ "$DEVICE_TYPE" == "ssd" ]; then
    STORAGE_CLASS="beta2"
elif [ "$DEVICE_TYPE" == "nvme" ]; then
    STORAGE_CLASS="beta3"
fi
echo "Storage class: $STORAGE_CLASS"

# Process device filter
# Convert glob patterns like sd* to regex ^sd.
DEVICE_FILTER=$(echo "$DEVICE_NAMES" | sed 's/\*/\./g' | sed 's/^/^/')
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

# Generate node list for the configuration
NODE_LIST=""
for node in $NODE_NAMES; do
    NODE_LIST+="  - name: \"$node\"\n    config:\n"
done
echo "Generated node list for $NODE_NAMES"

# Create a temporary file with the template
cp "$TEMPLATE_FILE" "$OUTPUT_FILE.tmp"

# Replace Go-style placeholders in the template
sed -i "s/{{ .POOL_SIZE }}/$POOL_SIZE/g" "$OUTPUT_FILE.tmp"
sed -i "s/{{ .MIN_SIZE }}/$MIN_SIZE/g" "$OUTPUT_FILE.tmp"
sed -i "s|{{ .DEVICE_FILTER }}|$DEVICE_FILTER|g" "$OUTPUT_FILE.tmp"
sed -i "s/{{ .OSDS_PER_DEVICE }}/$OSDS_PER_DEVICE/g" "$OUTPUT_FILE.tmp"
sed -i "s/{{ .FAILURE_DOMAIN }}/$FAILURE_DOMAIN/g" "$OUTPUT_FILE.tmp"
sed -i "s/{{ .STORAGE_CLASS }}/$STORAGE_CLASS/g" "$OUTPUT_FILE.tmp"

# Handle node list replacement (this is a multi-line replacement)
# We need to find the line containing {{ .NODE_LIST }} and replace it
NODE_LIST_LINE=$(grep -n "{{ .NODE_LIST }}" "$OUTPUT_FILE.tmp" | cut -d ":" -f 1)
if [ -n "$NODE_LIST_LINE" ]; then
    # Delete the line with {{ .NODE_LIST }}
    sed -i "${NODE_LIST_LINE}d" "$OUTPUT_FILE.tmp"
    
    # Insert the node list at the position
    sed -i "${NODE_LIST_LINE}i$(echo -e "$NODE_LIST")" "$OUTPUT_FILE.tmp"
fi

# Move the temp file to the final output
mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

echo "Configuration file generated at $OUTPUT_FILE"
