This ansible role covers the steps required to get the AKash Provider up and runnning.

### Prerequisites
- Ensure to run the OP role to fetch the base64 key and key secret
    - Alternatively you could pass the `provider_b64_key` and `provider_b64_keysecret` using Extra vars
- Kubectl binary
- Access to Kubernetes Cluster
- Helm binary    

### Install the requirements
We need to install the Kubernetes core module specified in the requirements.yml file
```
sudo apt install python3-kubernetes
ansible-galaxy install -r requirements.yml
```

### Running the playbook
```
ansible-playbook -i inventory_example.yaml playbooks.yml -e 'host=<provider_url> provider_name=<provider_url> provider_version=0.6.9 -e akash1_address="<akash1 address>"' -t op,provider -vv
```


## Configuration Variables

### Required Variables

The following variables must be provided for the provider to function properly:

| Variable | Description | Default |
|----------|-------------|---------|
| `akash1_address` | Akash1 Address of the Provider Wallet | Nil |
| `key` | Private key | Nil |
| `keysecret` | Passphrase to protect the private key | Nil |
| `domain` | Domain name of the provider | Nil |
| `region` | Geographical region | Nil |
| `node` | Node endpoint URL | Nil |
| `withdrawal_period` | Period for withdrawals | Nil |
| `host` | Host identifier | Nil |
| `tier` | Service tier | Nil |
| `organization` | Organization name | Nil |
| `email` | Contact email | Nil |
| `website` | Website URL | Nil |

### Optional Variables

These variables can be customized but have default values:

| Variable | Description | Default |
|----------|-------------|---------|
| `provider_version` | Version for the provider helm chart| 0.6.9 |
| `chain_id` | Blockchain network ID | Nil |
| `cuda_version` | CUDA version for GPU support | Nil |
| `country` | Country code | Nil |
| `city` | City location information | Nil |
| `location_type` | Type of location | Nil |
| `cpu` | CPU manufacturer | Nil |
| `cpu_arch` | CPU architecture | Nil |
| `gpu` | GPU manufacturer | Nil |
| `gpu_model_a100` | Whether A100 GPU model is available | Nil |
| `gpu_model_a100_ram_80` | Whether A100 with 80GB RAM is available | Nil |
| `gpu_model_a100_ram_sxm` | Whether A100 SXM with specific RAM config is available | Nil |
| `gpu_model_a100_sxm` | Whether A100 SXM form factor is available | Nil |
| `storage_one_class` | Storage class configuration | Nil |
| `storage_one_persistent` | First persistent storage configuration | Nil |
| `storage_two_class` | Second storage class configuration | Nil |
| `storage_two_persistent` | Second persistent storage configuration | Nil |
| `memory` | Memory type | Nil |
| `network_speed_up` | Upload network speed in Mbps | Nil |
| `network_speed_down` | Download network speed in Mbps | Nil |
