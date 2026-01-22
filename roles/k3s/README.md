#### K3s Ansible Role
This guide provides details on how to use the K3s Ansible role to install and configure a K3s Kubernetes cluster with control plane and worker nodes.

#### Running the playbooks
##### For control plane nodes:
```bash
ansible-playbook -i inventory.yml playbook.yml -t k3s -e 'host=control_plane'
```
##### For worker nodes:
```bash
ansible-playbook -i inventory.yml playbook.yml -t k3s -e 'host=workers'
```


#### Configuration Variables
| Variable                  | Description                                    | Required | Default                 |
|---------------------------|------------------------------------------------|----------|-------------------------|
| `k3s_version_channel`     | Version of K3s to install                      | No       | v1.32.3+k3s1            |
| `k3s_cluster_cidr`        | Calico CIDR                                    | No       | 10.42.0.0/16            |
| `disable_components`      | K3s components to disable                      | No       | traefik                 |
| `k3s_flannel_backend`     | Flannel backend to use                         | No       | none                    |
| `kubelet_root_dir`        | Directory for kubelet data                     | No       | /data/kubelet           |
| `k3s_data_dir`            | Directory for K3s data                         | No       | /data/k3s               |
| `calico_version`          | Calico CNI version                             | No       | v3.29.3                 |
| `calico_manifest_url`     | URL for Calico manifest                        | No       | Generated from version  |
| `scheduler_config_path`   | Path to scheduler configuration                | No       | Generated from data_dir |
| `tls_san`                 | TLS SAN for the K3s API server                 | No       | First control plane host|

