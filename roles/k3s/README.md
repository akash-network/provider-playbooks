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

#### TLS SAN Configuration
The `tls_san` variable allows you to add additional IP addresses or hostnames to the Kubernetes API server TLS certificate. This is useful for accessing the cluster through VPNs (like Tailscale) or load balancers.

When using the `setup_provider.sh` script:
- If Tailscale is selected, the script automatically installs Tailscale on the control plane node first
- It retrieves the Tailscale IP address and configures it as the TLS SAN
- This allows you to access the Kubernetes API server securely through your Tailscale network

You can also manually set a custom TLS SAN by adding it to your host_vars file:
```yaml
tls_san: "100.64.0.1"  # Your custom IP or hostname
```




UUID=b4b63d1a-2833-491c-b84c-d4c1e529a12c /data ext4 defaults 0 2
UUID=fa6f82eb-9464-4322-abef-a20b7597b44e /data ext4 defaults 0 2
UUID=e5ea5f8e-95a0-4fdc-bd9c-bdf40ba20cd4 /data ext4 defaults 0 2
UUID=413d4644-2760-4035-9751-70302246d3fc /data ext4 defaults 0 2