# Akash Provider Ansible Playbooks

This repository contains custom Ansible playbooks designed to enhance the default Kubernetes cluster provisioning process for the Akash Provider setup. The primary goal is to streamline deployments by incorporating additional configurations such as secrets management, GPU driver installation, and secure networking.

## Description

This project tracks all tasks related to developing and maintaining custom Ansible playbooks for the Akash Provider setup. Enhancements include:

- **Secrets Management:** Integration of 1Password Secrets Management into the provider build playbooks.
- **GPU Support:** Installation of NVIDIA GPU drivers and runtime components.
- **Networking:** Deployment of Tailscale via custom Ansible playbooks.
- **Provider:** Deployment of Akash Provider.
- **OS:** Sets up sysctl and cron jobs in the nodes.
- **rook-ceph:** Sets up persistent storage based on rook-ceph.

---

## 🚀 Running Provider Playbooks

The provider playbooks can be executed independently of how your Kubernetes cluster was installed (Kubespray, K3s, etc.).

As long as your cluster is reachable via SSH and you have a valid kubeconfig, you can run:

```bash
ansible-playbook -i hosts.yaml playbooks.yml -t os,provider,gpu -e 'host=node1' -v
```

To get started, create a minimal Ansible inventory like this:

```bash
vim hosts.yaml
```

```yaml
all:
  vars:
    ansible_user: root
  hosts:
    node1:
      ansible_host: 10.4.8.74
    node2:
      ansible_host: 10.4.8.75
    node3:
      ansible_host: 10.4.8.76
```

To install the necessary tooling:

```bash
apt install ansible-core python3-kubernetes
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

This setup has been tested on a Kubespray-based Kubernetes installation and should behave identically in a K3s-based environment.

---

## Prerequisites

Before running any Ansible playbooks, please ensure:

1. Passwordless SSH access is configured between your Ansible control node and all target machines.
2. Your inventory file contains the correct hosts and IPs with `ansible_user` set to a privileged account (e.g., `root`).
3. Your kubeconfig is present and accessible from the control node running the playbooks (default: `~/.kube/config`).

---

## Clone the Provider Playbooks Repository

```bash
git clone https://github.com/akash-network/provider-playbooks.git
```

> Note: This step may become optional in the future once remote/local execution patterns are validated.

---

## Example: Provider Setup on an Existing Cluster

Assuming you already have a cluster and a `hosts.yaml` file as shown above:

```bash
ansible-playbook -i hosts.yaml playbooks.yml -t os,provider,gpu -e 'host=node1'
```

This will:

- Configure OS parameters (`os`)
- Deploy the Akash Provider (`provider`)
- Optionally install GPU drivers and runtime (`gpu`)

If your node does not have a GPU, simply omit the `gpu` tag.

---

## 🔐 Creating Host Vars for Provider Deployment

Create a `host_vars` file for each node in your provider setup. The filename must match the hostname used in your `hosts.yaml` inventory.

```bash
mkdir -p /root/provider-playbooks/host_vars
```

For example, create the file for the primary control-plane node:

```bash
vim /root/provider-playbooks/host_vars/node1.yml
```

Example contents:

```yaml
# Node Configuration - Host Vars File

## Provider Identification
akash1_address: ""  # Your Akash wallet address

## Security Credentials
provider_b64_key: ""        # Base64-encoded provider key
provider_b64_keysecret: ""  # Base64-encoded provider key secret

## Network Configuration
domain: ""          # Public DNS name of the provider, e.g. "t100.abc.xy.akash.pub"
region: ""          # Region label, e.g. "us-west"

## Organization Details
organization: ""  # Your organization name
email: ""         # Contact email address
website: ""       # Organization website

# provider attributes
attributes:
  - key: host
    value: akash
  - key: tier
    value: community

# price targets
price_cpu: 1.60
price_memory: 0.30
price_hd_ephemeral: 0.02
price_hd_pers_hdd: 0.01
price_hd_pers_ssd: 0.03
price_hd_pers_nvme: 0.1
price_endpoint: 0.05
price_ip: 5
price_gpu_mappings: "a100=569,*=569"

## Notes:
# - Replace empty values with your actual configuration
# - Keep sensitive values secure and never share them publicly
# - Ensure domain format follows Akash naming conventions
EOF
```

> **NOTE:** `provider_b64_key` and `provider_b64_keysecret` can also be passed at runtime using `-e`. This is the recommended method for security reasons, as it avoids writing sensitive credentials to disk in plain text.

Example:

```bash
ansible-playbook -i hosts.yaml playbooks.yml -e "host=node1 provider_b64_key=VALUE provider_b64_keysecret=VALUE"
```

---

### 📌 Important Notes

- Keep placeholders if secrets haven’t been generated yet
- Populate values after creating your provider keys and certificates
- For multi-node deployments, repeat this for each control plane node
- The `provider` playbook should only be run on Kubernetes control-plane nodes (typically `node1`)

---

## Role-Specific Variables

Each role in the playbook has specific configuration variables that can be set to customize your deployment. These variables can be defined in your inventory files, `host_vars` files, or passed directly using the `-e` parameter.

### Tailscale Role (OPTIONAL)

- `tailscale_authkey`: Your Tailscale authentication key
- `tailscale_hostname`: The hostname for the Tailscale node

Refer [here](https://github.com/akash-network/provider-playbooks/blob/main/roles/tailscale/README.md#configuration-variables) for additional options.

Example:

```bash
ansible-playbook playbooks.yml -i hosts.yaml -t tailscale -v -e 'tailscale_authkey=tskey-auth-xxxx host=node1.t100.abc.xy.akash.pub'
```

> Tailscale is optional. `tailscale_hostname` can be passed via `-e` or defined in `host_vars`.

### OS Role

No additional variables are required beyond the host definition.

### OP Role (OPTIONAL)

- `provider_name`: Name of your Akash provider

Refer [here](https://github.com/akash-network/provider-playbooks/blob/main/roles/op/README.md#configuration-variables) for more.

> Optional role; not required for deployment.

### Provider Role

- `provider_name`: Akash provider name
- `provider_version`: Version of the provider software to deploy
- `akash1_address`: Wallet address for this provider

Refer [here](https://github.com/akash-network/provider-playbooks/blob/main/roles/provider/README.md#configuration-variables) for additional options.

### GPU Role

No extra variables required. Refer [here](https://github.com/akash-network/provider-playbooks/blob/main/roles/gpu/README.md) for more.

### Rook-Ceph Role

It is highly recommended to read [Persistent Storage Requirements](https://akash.network/docs/providers/build-a-cloud-provider/akash-cli/helm-based-provider-persistent-storage-enablement/) to understand the Environment, Ceph, Networking Prerequisites as well as the Storage Class Types.

1. Generate the rook-ceph cluster config:
```
cd roles/rook-ceph/
./generate-rook-ceph-cluster-config.sh
```

2. Run the rook-ceph role playbook
```
cd ../..
ansible-playbook -i hosts.yaml /root/provider-playbooks/playbooks.yml -t rook-ceph -e 'host=node1'
```

3. Verify Ceph is installed
```
helm -n rook-ceph list
kubectl -n rook-ceph get cephcluster
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd tree
```

---

## Common Options and Tips

- **Verbosity levels:** `-v`, `-vv`, `-vvv`, `-vvvv`
- **Extra variables (`-e`)** take the highest precedence
- **Target host control:**
  - `-e "host=<ip>"` – target a specific host
  - `-e "host=<group>"` – target a group defined in the inventory

**Available tags:** `tailscale`, `os`, `op`, `provider`, `gpu`
