# K3s role

Installs the pinned K3s release with Calico and no Kubespray dependency.

| Variable | Default |
| --- | --- |
| `k3s_install_version` | `v1.35.3+k3s1` |
| `k3s_cluster_cidr` | `10.42.0.0/16` |
| `disable_components` | `traefik,network-policy` |
| `k3s_flannel_backend` | `none` |
| `kubelet_root_dir` | `/var/lib/kubelet` |
| `k3s_data_dir` | `/var/lib/rancher/k3s` |
| `calico_version` | `v3.31.5` |

The setup script writes a distinct `internal_ip` for every node. Nodes in
`kube_control_plane` run the server tasks once; nodes in `kube_node` that are not
control-plane members run the agent tasks once. When Tailscale is enabled, its
IPv4 address is supplied through `tls_san` before K3s installation.

Run manually with:

```bash
ansible-playbook -i .generated/inventory/hosts.ini playbooks.yml --tags k3s
```
