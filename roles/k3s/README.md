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

#### Inventory Examples
Inventory can be either in .ini or .yml format. Each host requires an internal_ip variable to be defined, which is used for the K3s cluster communication. If you are planning to run the playbook for each host, you could alternatively pass the internal_ip using extra vars.

##### INI Format
```ini
[control_plane]
34.70.8.190 ansible_user=root internal_ip=10.128.0.32
34.70.198.23 ansible_user=root internal_ip=10.128.0.35
34.57.255.229 ansible_user=root internal_ip=10.128.0.33

[workers]
34.67.88.106 ansible_user=root internal_ip=10.128.0.34
```
##### YAML Format
```yaml
  vars:
    ansible_user: root
  hosts:
    34.70.8.190:
      internal_ip: 10.128.0.32
    34.70.198.23:
      internal_ip: 10.128.0.35
    34.57.255.229:
      internal_ip: 10.128.0.33
    34.67.88.106:
      internal_ip: 10.128.0.34
  children:
    control_plane:
      hosts:
        34.70.8.190:
        34.70.198.23:
        34.57.255.229:
    workers:
      hosts:
        34.67.88.106:
```        

#### Configuration Variables
| Variable                  | Description                                    | Required | Default                  |
|---------------------------|------------------------------------------------|----------|-------------------------|
| `k3s_version_channel`     | Version of K3s to install                      | No       | v1.32.3+k3s1            |
| `disable_components`      | K3s components to disable                      | No       | traefik                 |
| `k3s_flannel_backend`     | Flannel backend to use                         | No       | none                    |
| `kubelet_root_dir`        | Directory for kubelet data                     | No       | /data/kubelet           |
| `k3s_data_dir`            | Directory for K3s data                         | No       | /data/k3s               |
| `calico_version`          | Calico CNI version                             | No       | v3.28.2                 |
| `calico_manifest_url`     | URL for Calico manifest                        | No       | Generated from version  |
| `scheduler_config_path`   | Path to scheduler configuration                | No       | Generated from data_dir |
| `tls_san`                 | TLS SAN for the K3s API server                 | No       | First control plane host|

