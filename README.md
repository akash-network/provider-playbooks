# Akash Provider Playbooks

This repository contains Ansible playbooks for setting up and managing an Akash Provider node.
- **GPU Support:** Installation of NVIDIA GPU drivers and runtime components.
- **Networking:** Deployment of Tailscale via custom Ansible playbooks.
- **Provider:** Deployment of Akash Provider.
- **OS:** Sets up sysctl and cron jobs in the nodes.
- **rook-ceph** Sets up persistent storage based on rook-ceph. See additional details in roles/rook-ceph/README.md

## Prerequisites

### System Requirements
- Ansible 2.9+
- Python 3.6+
- SSH access to target nodes
- Root or sudo access on target nodes
- Ubuntu 24.04 LTS

## Required Information

Before running the setup script, prepare the following information:

1. **Provider Details**
   - Provider domain name (e.g., provider.example.com)
   - Provider region (e.g., us-west)
   - Organization name
   - Contact email
   - Organization website

2. **Node Information**
   - Number of nodes in your cluster
   - IP addresses for each node
   - SSH credentials for each node

3. **Storage Configuration** (if using Rook-Ceph)
   - Storage device names (e.g., /dev/sdb, /dev/nvme0n1)
   - Number of OSDs per device
   - Storage device type (HDD/SSD/NVMe)
   - Storage node selection

4. **Wallet Options**
   - Choose one of:
     - Create a new wallet (recommended for new providers)
     - Import an existing wallet key file
     - Import an existing wallet using mnemonic phrase
     - Paste existing AKT address and encrypted key (for existing providers)
       - Note: The key and key secret must be already base64 encoded and encrypted

## Installation

1. SSH into your first node (node1) of the cluster:
```bash
ssh user@node1-ip-address
```

2. Clone this repository on node1:
```bash
git clone https://github.com/akash-network/provider-playbooks.git
cd provider-playbooks
```

3. Run the setup script:
```bash
./scripts/setup_provider.sh
```

4. Follow the interactive prompts to configure your provider.

## Playbook Selection

The setup script will guide you through selecting which playbooks to run:

- **Kubernetes Installation** (required for new clusters)
  - **Kubespray**: Production-grade, full-featured Kubernetes installation
  - **K3s**: Lightweight, single binary Kubernetes distribution (ideal for edge/IoT)
- **OS**: Basic OS configuration and optimizations
- **GPU**: NVIDIA driver and container toolkit installation
- **Provider**: Akash Provider service installation
- **Tailscale**: VPN setup for secure remote access
- **Rook-Ceph**: Storage operator installation and configuration

## Manual Execution

If you need to run playbooks manually:

```bash
# Run all playbooks
ansible-playbook -i inventory/hosts.yaml playbooks.yml

# Run specific playbooks using tags
ansible-playbook -i inventory/hosts.yaml playbooks.yml -t os,provider,gpu

# Run K3s specific playbooks
ansible-playbook -i inventory/hosts.yaml playbooks.yml -t k3s
```

## Troubleshooting

Common issues and solutions:

1. **SSH Connection Issues**
   - Ensure SSH keys are properly set up
   - Verify network connectivity
   - Check firewall settings

2. **Kubernetes Installation**
   - Check system requirements
   - Verify network configuration
   - Review kubespray logs (for Kubespray)
   - Check K3s service status (for K3s)

3. **Provider Service**
   - Check wallet configuration
   - Verify network connectivity
   - Review provider logs

4. **Storage Issues**
   - Verify storage devices are clean and available
   - Check storage node resources
   - Review Ceph operator logs
   - Ensure proper network connectivity between storage nodes

## Support

For support, please:
- Check the [Akash Documentation](https://docs.akash.network)
- Join the [Akash Discord](https://discord.gg/akash)
- Open an issue in this repository
