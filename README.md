# Akash Provider Ansible Playbooks

This repository contains custom Ansible playbooks designed to enhance the default Kubernetes cluster provisioning process for the Akash Provider setup. The primary goal is to streamline deployments by incorporating additional configurations such as secrets management, GPU driver installation, and secure networking.

## Description

This project tracks all tasks related to developing and maintaining custom Ansible playbooks for the Akash Provider setup. Enhancements include:

- **Secrets Management:** Integration of 1Password Secrets Management into the provider build playbooks.
- **GPU Support:** Installation of NVIDIA GPU drivers and runtime components.
- **Networking:** Deployment of Tailscale via custom Ansible playbooks.
- **Provider:** Deployment of Akash Provider and Node.
- **Cron:** Sets up Cron jobs in the nodes.

# Setting up Kubespray
Set up a Kubernetes cluster using Kubespray by following the guide at the Akash network documentation site.
[https://akash.network/docs/providers/build-a-cloud-provider/akash-cli/kubernetes-cluster-for-akash-providers/kubernetes-cluster-for-akash-providers/#clone-the-kubespray-project]

- When configuring your Kubespray cluster, make sure to set up Ephemeral Storage by adding these settings to `~/kubespray/inventory/akash/group_vars/k8s_cluster/k8s-cluster.yml`
```yml
kubelet_custom_flags:
"--root-dir=/data/kubelet"

containerd_storage_dir: /data/containerd
```

- Enable Helm installation by adding this to `~/kubespray/inventory/akash/group_vars/k8s_cluster/addson.yml`
```yml
# Helm deployment
helm_enabled: true
```

- Configure the scheduler profiles in `~/kubespray/inventory/akash/group_vars/k8s_cluster/k8s-cluster.yml`
```yml
kube_scheduler_profiles:
  - pluginConfig:
    - name: NodeResourcesFit
      args:
        scoringStrategy:
          type: MostAllocated
          resources:
            - name: nvidia.com/gpu
              weight: 10
            - name: memory
              weight: 1
            - name: cpu
              weight: 1
            - name: ephemeral-storage
              weight: 1
```

- To run the Ansible playbook:
```bash
ansible-playbook -i inventory.yaml playbooks.yaml -e "host=<IP>" -v --list-tasks
```
