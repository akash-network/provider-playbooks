# Akash Provider Ansible Playbooks

This repository contains custom Ansible playbooks designed to enhance the default Kubernetes cluster provisioning process for the Akash Provider setup. The primary goal is to streamline deployments by incorporating additional configurations such as secrets management, GPU driver installation, and secure networking.

## Description

This project tracks all tasks related to developing and maintaining custom Ansible playbooks for the Akash Provider setup. Enhancements include:

- **Secrets Management:** Integration of 1Password Secrets Management into the provider build playbooks.
- **GPU Support:** Installation of NVIDIA GPU drivers and runtime components.
- **Networking:** Deployment of Tailscale via custom Ansible playbooks.
- **Provider:** Deployment of Akash Provider.
- **OS:** Sets up sysctl and cron jobs in the nodes.

### To run the Ansible playbook
```bash
# Run the complete Ansible playbook
ansible-playbook -i inventory.yaml playbooks.yaml -e "host=<IP>" -v

# Run specific plays using tags
# Available tags: op, provider, cron, gpu, tailscale
ansible-playbook -i inventory.yaml playbooks.yaml -t <tag_name> -e "host=<IP>" -v
```
