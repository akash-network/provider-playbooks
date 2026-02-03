This ansible role covers the steps required for the installation of the GPU drivers following the official Akash documentation.

**Documentation:** https://akash.network/docs/providers/setup-and-installation/kubespray/gpu-support/

### What This Role Does

1. **Installs NVIDIA Drivers** - Supports both consumer and data center GPUs
2. **Installs NVIDIA Container Toolkit** - Required for containerized GPU workloads
3. **Configures CDI (Container Device Interface)** - Modern device enumeration method
4. **Creates NVIDIA RuntimeClass** - Kubernetes runtime for GPU pods
5. **Labels GPU Nodes** - Marks nodes for GPU workload scheduling
6. **Installs NVIDIA Device Plugin** - Exposes GPUs to Kubernetes

### Prerequisites
- Host with NVIDIA GPUs
- Access to Kubernetes Cluster
- Kubectl binary
- Helm binary (v3.17.3)
- Jq binary
- Ubuntu 24.04 LTS

### Install the requirements
```bash
sudo apt install python3-kubernetes
ansible-galaxy install -r requirements.yml
```

### Running the playbook
```bash
ansible-playbook playbooks.yml -t gpu -i inventory.yml -v
```

### Configuration Variables
| Variable                 | Description                                                      | Required | Default                |
|--------------------------|------------------------------------------------------------------|----------|------------------------|
| `install_dir`            | Directory used to store temporary files                          | No       | /root/ansible.tmp      |
| `nvidia_version`         | NVIDIA Driver Version                                            | No       | 580.95.05              |
| `nvidia_driver_type`     | GPU type: "consumer" (RTX) or "datacenter" (H100)                | No       | consumer               |
| `ubuntu_version`         | Ubuntu version for repository URLs                               | No       | 2404                   |
| `nvdp_version`           | NVIDIA Device Plugin Helm chart version                          | No       | 0.18.0                 |
| `cruntime_toml_path`     | Path to NVIDIA Container Runtime config                          | No       | /etc/nvidia-container-runtime/config.toml |

### GPU Type Selection

Set `nvidia_driver_type` in your inventory or host_vars:

**Consumer GPUs** (RTX 4090, RTX 5090, etc.):
```yaml
nvidia_driver_type: "consumer"
```

**Data Center GPUs** (H100, H200, etc.):
```yaml
nvidia_driver_type: "datacenter"
```

### CDI Configuration

This role configures CDI (Container Device Interface) for better security and device management:
- Generates CDI specification at `/etc/cdi/nvidia.yaml`
- Configures runtime at `/etc/nvidia-container-runtime/config.toml`
- Device plugin uses `cdi-cri` strategy

### Verification

After installation, verify GPU functionality:

```bash
# Check NVIDIA driver
nvidia-smi

# Check device plugin pods
kubectl -n nvidia-device-plugin get pods

# Check device plugin logs
kubectl -n nvidia-device-plugin logs -l app.kubernetes.io/instance=nvdp

# Test GPU workload
kubectl run gpu-test --rm -it --restart=Never \
  --image=nvidia/cuda:11.6.0-base-ubuntu20.04 \
  -- nvidia-smi
```
