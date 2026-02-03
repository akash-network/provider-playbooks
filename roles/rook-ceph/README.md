# Rook-Ceph Role

This role deploys Rook-Ceph for persistent storage on Akash providers following the official Akash documentation.

**Documentation:** https://akash.network/docs/providers/setup-and-installation/kubespray/persistent-storage/

## What This Role Does

1. **Installs Rook-Ceph Operator** (v1.18.7)
2. **Deploys Ceph Cluster** with your storage configuration
3. **Creates Storage Class** (beta1/beta2/beta3)
4. **Labels Storage Class** with `akash.network=true` for Akash detection
5. **Creates /root/provider directory** for provider configuration

## Prerequisites

### Hardware Requirements

**Minimum Requirements:**
- 4 SSDs across all nodes, OR
- 2 NVMe SSDs across all nodes

**Drive Requirements:**
- Dedicated exclusively to persistent storage
- Unformatted (no partitions or filesystems)
- NOT used for OS or ephemeral storage

### Network Requirements

- **Minimum:** 10 GbE NIC cards for storage nodes
- **Recommended:** 25 GbE or faster

### Ceph Requirements

For production:
- **Minimum 3 OSDs** for redundancy
- **Minimum 2 Ceph managers**
- **Minimum 3 Ceph monitors**
- **Minimum 60 GB** disk space at `/var/lib/ceph/`

**OSDs per drive:**
- HDD: 1 OSD max
- SSD: 1 OSD max
- NVMe: 2 OSDs max

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `rook_ceph_namespace` | Namespace for Rook Ceph | `rook-ceph` |
| `rook_ceph_version` | Rook Ceph version | `1.18.7` |
| `pool_size` | Number of replicas | `3` |
| `min_size` | Minimum replicas | `2` |
| `mon_count` | Ceph monitor count | `3` |
| `mgr_count` | Ceph manager count | `2` |
| `device_filter` | Device filter (e.g., `sd*`, `nvme*`) | `sd*` |
| `device_type` | Device type: `hdd`, `ssd`, or `nvme` | `ssd` |
| `osds_per_device` | OSDs per device (1 for HDD/SSD, 2 for NVMe) | `1` |
| `failure_domain` | Failure domain (`host` or `osd`) | `host` |
| `storage_class` | Storage class name (`beta1`, `beta2`, or `beta3`) | `beta2` |
| `kubelet_dir_path` | Kubelet root directory | `/var/lib/kubelet` |
| `rook_ceph_data_dir` | Ceph data directory | `/var/lib/rook` |
| `storage_nodes` | List of storage node names | `[]` |

## Storage Class Types

| Class | Description | Device Type | OSDs per Device |
|-------|-------------|-------------|-----------------|
| `beta1` | HDD storage | HDD | 1 |
| `beta2` | SSD storage | SSD | 1 |
| `beta3` | NVMe storage | NVMe | 1-2 |

## Directory Paths

### kubelet_dir_path
- Must match Kubernetes kubelet `--root-dir` configuration
- Default: `/var/lib/kubelet`
- Custom: `/data/kubelet` (if configured during K8s setup)

### rook_ceph_data_dir
- Where Ceph monitor and manager data is stored (NOT OSD data)
- Default: `/var/lib/rook`
- Custom: `/data/rook` (if using RAID array at `/data`)

## Usage

The setup script (`scripts/setup_provider.sh`) automatically configures all these variables based on your input. 

### Manual Playbook Execution

```bash
ansible-playbook -i inventory.yml playbooks.yml -t rook-ceph -v \
  --extra-vars "kubelet_dir_path=/var/lib/kubelet"
```

## Verification

After installation, verify:

```bash
# Check cluster status
kubectl -n rook-ceph get cephcluster

# Check storage class
kubectl get storageclass

# Verify label
kubectl get sc <storage-class> --show-labels
```

Expected output:
- Ceph cluster: `PHASE: Ready`, `HEALTH: HEALTH_OK`
- Storage class labeled with `akash.network=true`

## Troubleshooting

### Check Operator Logs
```bash
kubectl -n rook-ceph logs -l app=rook-ceph-operator
```

### Check Ceph Status
```bash
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd tree
```

### Common Issues

**OSDs not starting:**
- Verify drives are unformatted: `lsblk -f`
- Check deviceFilter matches your drives
- Review OSD pod logs

**HEALTH_WARN:**
- Check `ceph status` for specific warnings
- Initial warnings during setup are normal

## Integration with Provider Role

The provider role will automatically:
1. Detect the labeled storage class
2. Add storage attributes to `provider.yaml`:
   ```yaml
   - key: capabilities/storage/1/class
     value: beta2  # (or beta1/beta3)
   - key: capabilities/storage/1/persistent
     value: "true"
   ```
3. Configure inventory-operator with the storage class

## Additional Resources

- [Rook Documentation](https://rook.io/docs/rook/latest-release/)
- [Ceph Documentation](https://docs.ceph.com/)
- [Akash Persistent Storage Guide](https://akash.network/docs/providers/setup-and-installation/kubespray/persistent-storage/)
