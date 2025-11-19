The rook-ceph installation playbook.

It will install the complete rook-ceph operator, the rook-ceph cluster and will do the finalizing tasks like labeling the storage class.

## HOW TO USE:
1. Install helm: `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash`
2. run `./generate-rook-ceph-cluster-config.sh`
3. `cd ~/kubespray`
4. run the playbook using `ansible-playbook -i inventory/akash/hosts.yaml -b -v --private-key=~/.ssh/id_rsa cluster.yml -e 'host=all' -t rook-ceph`

#### Configuration Variables

```
| Variable                  | Description                                    | Required | Default                 |
|---------------------------|------------------------------------------------|----------|-------------------------|
| `rook_ceph_namespace`     | Namespace for Rook Ceph deployment             | No       | rook-ceph               |
| `rook_ceph_version`       | Version of Rook Ceph to install                | No       | 1.16.6                  |
| `pool_size`               | Number of replicas for Ceph pools              | No       | 3                       |
| `min_size`                | Minimum number of replicas for pools           | No       | 2                       |
| `mon_count`               | Number of Ceph monitor daemons                 | No       | 3                       |
| `mgr_count`               | Number of Ceph manager daemons                 | No       | 2                       |
| `device_filter`           | Device filter pattern for OSDs                 | No       | sd*                     |
| `device_type`             | Device type used for OSDs                      | No       | ssd                     |
| `osds_per_device`         | Number of OSDs per device                      | No       | 1                       |
| `failure_domain`          | Failure domain for data placement              | No       | host                    |
| `storage_class`           | Default storage class name                     | No       | rook-ceph-block         |
| `zfs_for_ephemeral`       | Use ZFS for ephemeral storage                  | No       | false                   |
| `kubelet_dir_path`        | Directory for kubelet data                     | No       | /var/lib/kubelet        |
| `storage_nodes`           | List of nodes designated for storage           | No       | []                      |
```
