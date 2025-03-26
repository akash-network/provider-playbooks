# Akash Provider Ansible Playbooks

This repository contains custom Ansible playbooks designed to enhance the default Kubernetes cluster provisioning process for the Akash Provider setup. The primary goal is to streamline deployments by incorporating additional configurations such as secrets management, GPU driver installation, and secure networking.

## Description

This project tracks all tasks related to developing and maintaining custom Ansible playbooks for the Akash Provider setup. Enhancements include:

- **Secrets Management:** Integration of 1Password Secrets Management into the provider build playbooks.
- **GPU Support:** Installation of NVIDIA GPU drivers and runtime components.
- **Networking:** Deployment of Tailscale via custom Ansible playbooks.
- **Provider:** Deployment of Akash Provider.
- **OS:** Sets up sysctl and cron jobs in the nodes.


### Installing Ansible
Follow the below steps to install Ansible in the MacOS.
```
python3 -m venv venv
source venv/bin/activate
pip3 install -r requirements.txt
```

### Prerequisites
Before running any Ansible playbooks, please ensure:

1. Passwordless SSH access is configured between your Ansible control node and all target machines.
2. Server configuration:
    - Replace <server1> with the actual IP address of your target server
    - Add additional server entries for multi-node clusters
This setup ensures Ansible can communicate securely with all nodes in your infrastructure without requiring password authentication during playbook execution.

**Note:**
These Ansible playbooks have been tested on macOS and can be run from any macOS environment with Ansible installed. The *inventory.yml* file contains all target hosts where Ansible will deploy the configured tasks. Make sure this inventory file is properly configured with your server information before running any playbooks. The syntax remains the same on macOS as it would be on other UNIX-based systems.

### To run the Ansible playbook
```bash
# Run the complete Ansible playbook
ansible-playbook -i inventory.yml playbooks.yml -e "host=<IP>" -v

# Run specific plays using tags
# Available tags: op, provider, cron, gpu, tailscale
ansible-playbook -i inventory.yml playbooks.yml -t <tag_name> -e "host=<IP>" -v
```

#### Deploy Tailscale
```bash
ansible-playbook playbooks.yml -i inventory.yml -t tailscale -v -e 'tailscale_authkey=tskey-auth-xxxx host=node1.t100.abc.xy.akash.pub'
```
Note: You can set the tailscale_hostname option using extra vars or define it in the host_vars file.
**eg:**
```bash
ansible-playbook playbooks.yml -i inventory.yml -t tailscale -v -e 'tailscale_authkey=tskey-auth-xxxx host=node1.t100.abc.xy.akash.pub tailscale_hostname=node1.t100.abc.xy.akash.pub'
```

#### Configure Hosts
```bash
ansible-playbook playbooks.yml -i inventory.yml -t os -v \
  -e 'host=node1.t100.abc.xy.akash.pub'
```

#### Deploy Provider
```bash
ansible-playbook playbooks.yml -i inventory.yml -t op,provider -v -e 'provider_name=t100.abc.xy.akash.pub provider_version=0.6.9 host=node1.t100.abc.xy.akash.pub akash1_address=akash1xxxx'
```

#### Configure GPU
```bash
ansible-playbook -i inventory.yaml playbooks.yaml -t gpu -v -e "host=all"
```

#### Common Options
Verbosity levels: -v, -vv, -vvv, -vvvv
Extra variables (-e): Takes highest precedence over other variable definitions
#### Target host control
    -e "host=<ip>" - Target a specific IP
    -e "host=<group>" - Target a group defined in inventory.yml

    Available tags (-t): tailscale, os, op, provider, gpu