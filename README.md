# Akash Provider Playbooks

# WIP

### Have not tested op or tailscale book yet, going to add shimpas rook-ceph book soon too


This repository contains Ansible playbooks for setting up and managing an Akash Provider node.

## Prerequisites

- Ansible 2.9+
- Python 3.6+
- SSH access to target nodes
- Root or sudo access on target nodes

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

3. **Wallet Options**
   - Choose one of:
     - Create a new wallet (recommended for new providers)
     - Import an existing wallet key file
     - Import an existing wallet using mnemonic phrase

## Installation

1. Clone this repository:
```bash
git clone https://github.com/akash-network/provider-playbooks.git
cd provider-playbooks
```

2. Run the setup script:
```bash
./scripts/setup_provider.sh
```

3. Follow the interactive prompts to configure your provider.

## Playbook Selection

The setup script will guide you through selecting which playbooks to run:

- **Kubespray**: Kubernetes installation (required for new clusters)
- **OS**: Basic OS configuration and optimizations
- **GPU**: NVIDIA driver and container toolkit installation
- **Provider**: Akash Provider service installation
- **Tailscale**: VPN setup for secure remote access
- **1Password**: Secrets management integration

## Manual Execution

If you need to run playbooks manually:

```bash
# Run all playbooks
ansible-playbook -i inventory/hosts.yaml playbooks.yml

# Run specific playbooks using tags
ansible-playbook -i inventory/hosts.yaml playbooks.yml -t os,provider,gpu
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
   - Review kubespray logs

3. **Provider Service**
   - Check wallet configuration
   - Verify network connectivity
   - Review provider logs

## Support

For support, please:
- Check the [Akash Documentation](https://docs.akash.network)
- Join the [Akash Discord](https://discord.gg/akash)
- Open an issue in this repository