#!/bin/bash

# Hard-coded answers file
ANSWERS_FILE="ceph_answers.yaml"
OUTPUT_FILE="$HOME/provider/rook-ceph-cluster.values.yml"

# Check if answers file exists
if [ ! -f "$ANSWERS_FILE" ]; then
    echo "Error: Answers file '$ANSWERS_FILE' not found in current directory."
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

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
POOL_SIZE=1
MIN_SIZE=1

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

# Create the output file
echo "Creating configuration file: $OUTPUT_FILE"
cat > "$OUTPUT_FILE" << EOF
operatorNamespace: rook-ceph

configOverride: |
  [global]
  osd_pool_default_pg_autoscale_mode = on
  osd_pool_default_size = $POOL_SIZE
  osd_pool_default_min_size = $MIN_SIZE

cephClusterSpec:
  resources:
  mon:
    count: 1
  mgr:
    count: 1
  storage:
    useAllNodes: false
    useAllDevices: false
    deviceFilter: "$DEVICE_FILTER"
    config:
      osdsPerDevice: "$OSDS_PER_DEVICE"
    nodes:
$(echo -e "$NODE_LIST")
cephBlockPools:
  - name: akash-deployments
    spec:
      failureDomain: $FAILURE_DOMAIN
      replicated:
        size: $POOL_SIZE
      parameters:
        min_size: "$MIN_SIZE"
        bulk: "true"
    storageClass:
      enabled: true
      name: $STORAGE_CLASS
      isDefault: true
      reclaimPolicy: Delete
      allowVolumeExpansion: true
      parameters:
        # RBD image format. Defaults to "2".
        imageFormat: "2"
        # RBD image features. Available for imageFormat: "2". CSI RBD currently supports only \`layering\` feature.
        imageFeatures: layering
        # The secrets contain Ceph admin credentials.
        csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
        csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
        csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
        csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
        csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
        csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
        # Specify the filesystem type of the volume. If not specified, csi-provisioner
        # will set default as \`ext4\`. Note that \`xfs\` is not recommended due to potential deadlock
        # in hyperconverged settings where the volume is mounted on the same node as the osds.
        csi.storage.k8s.io/fstype: ext4
# Do not create default Ceph file systems, object stores
cephFileSystems:
cephObjectStores:
# Spawn rook-ceph-tools, useful for troubleshooting
toolbox:
  enabled: true
  resources:
EOF

echo "Configuration file generated at $OUTPUT_FILE"
