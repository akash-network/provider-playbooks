This ansible role covers the steps required for the installation of the GPU drivers.

### Prerequisites
- Host with GPUs
- Access to Kubernetes Cluster
- Kubectl binary
- Helm binary
- Jq binary

### Install the requirements
We need to install the Kubernetes core module specified in the requirements.yml file
```
sudo apt install python3-kubernetes
ansible-galaxy install -r requirements.yml
```

### Running the playbook
```
ansible-playbook playbooks.yml -e 'host=<IP>' -i inventory.yml -v
```

### Configuration Variables
| Variable                 | Description                                                      | Required | Default                |
|--------------------------|------------------------------------------------------------------|----------|------------------------|
| `install_dir`            | usually /root/<dir>, can be any directory - used to store files  | No       | /root/ansible.tmp      |
| `nvidia_version`         | Nvidia Driver Version                                            | No       | 565.57.01              |
| `gpu_nodes`              | list of nodes - used to apply the gpu labels                      | No       | [node1]                |
