# Rook-Ceph role

Installs pinned Rook-Ceph charts and creates one Akash-labelled RBD storage
class. The setup wizard maps device types to the documented classes:

- HDD: `beta1`
- SSD: `beta2`
- NVMe: `beta3` (default)

The wizard inspects every configured node over the already-validated SSH
connection. It excludes removable/read-only disks, disks smaller than 5 GiB,
and disks with partitions, mounts, swap, holders, LVM membership, or recognized
filesystem/RAID/Ceph signatures. Discovery is read-only and never wipes a disk.
Arbitrary unformatted data cannot be detected, so the operator must still
confirm that every selected disk is dedicated to Ceph.

The generated inventory records exact devices per Kubernetes node and requires
stable `/dev/disk/by-id` identities; devices that expose only volatile kernel
names such as `/dev/sdb` are not selectable. Broad device filters are not used.
Kubernetes metadata names are retained for API checks, while each node's
`kubernetes.io/hostname` label is used for Rook device selection. The wizard
creates one OSD per physical disk and requires at least two physical disks; two
OSDs carved from one device are not treated as redundancy.

Topology is recommended in this order:

- three or more storage hosts: replica 3 with host failure domains;
- two storage hosts: replica 2 with host failure domains;
- one storage host with at least two disks: replica 2 with OSD failure domains
  and an explicit warning that host loss is not tolerated.

Within the best available topology, the wizard prefers a homogeneous media
tier. If that would reduce host redundancy, it recommends the safe mixed-disk
layout and advertises the storage class of the slowest selected device.

`kubelet_root_dir` must match the kubelet `--root-dir`; the setup wizard writes
one shared value for the cluster installer and Rook CSI configuration.

The role does not depend on or prepare the provider role. It verifies the
expected up/in OSD count and per-node OSD distribution, waits for the
`CephCluster` to report `Ready` without `HEALTH_ERR`, then labels the configured
StorageClass for Akash discovery. Safe `HEALTH_WARN` details are surfaced for
follow-up. If Rook rejects a disk, the failure includes recent OSD-prepare
output. The `rbd` kernel module is prepared on every Kubernetes worker.

Defaults use Rook-Ceph `1.19.10`, compatible with Kubernetes 1.30 through 1.35.
The version is centralized in `versions.yml`. When upgrading a playbook-managed
cluster, the generated values request the daemon-key rotation required by Ceph
19.2.6; non-blocking client-key warnings may remain on kernels older than 7.0.
Existing-cluster automation accepts only the supported Rook 1.18-to-1.19 upgrade
path (or 1.19 patch updates) and refuses both Rook and Ceph downgrades.
Single-host storage requires two separate devices and is not host-HA;
production storage should use at least three storage hosts.

Run manually with:

```bash
ansible-playbook -i .generated/inventory/hosts.ini playbooks.yml --tags rook-ceph
```
