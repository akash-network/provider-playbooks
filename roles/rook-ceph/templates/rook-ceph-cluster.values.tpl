operatorNamespace: rook-ceph

configOverride: |
  [global]
  osd_pool_default_pg_autoscale_mode = on
  osd_pool_default_size = {{ .POOL_SIZE }}
  osd_pool_default_min_size = {{ .MIN_SIZE }}

cephClusterSpec:
  resources:
  mon:
    count: {{ .MON_COUNT }}
  mgr:
    count: {{ .MGR_COUNT }}

  storage:
    useAllNodes: false
    useAllDevices: false
    deviceFilter: "{{ .DEVICE_FILTER }}"
    config:
      osdsPerDevice: "{{ .OSDS_PER_DEVICE }}"
    nodes:
{{ .NODE_LIST }}
cephBlockPools:
  - name: akash-deployments
    spec:
      failureDomain: {{ .FAILURE_DOMAIN }}
      replicated:
        size: {{ .POOL_SIZE }}
      parameters:
        min_size: "{{ .MIN_SIZE }}"
        bulk: "true"
    storageClass:
      enabled: true
      name: {{ .STORAGE_CLASS }}
      isDefault: true
      reclaimPolicy: Delete
      allowVolumeExpansion: true
      parameters:
        # RBD image format. Defaults to "2".
        imageFormat: "2"
        # RBD image features. Available for imageFormat: "2". CSI RBD currently supports only `layering` feature.
        imageFeatures: layering
        # The secrets contain Ceph admin credentials.
        csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
        csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
        csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
        csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
        csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
        csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
        # Specify the filesystem type of the volume. If not specified, csi-provisioner
        # will set default as `ext4`. Note that `xfs` is not recommended due to potential deadlock
        # in hyperconverged settings where the volume is mounted on the same node as the osds.
        csi.storage.k8s.io/fstype: ext4
# Do not create default Ceph file systems, object stores
cephFileSystems:
cephObjectStores:
# Spawn rook-ceph-tools, useful for troubleshooting
toolbox:
  enabled: true
  resources:
