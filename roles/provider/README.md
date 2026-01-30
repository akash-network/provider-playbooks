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
ansible-playbook -i inventory_example.yaml playbooks.yml -e 'host=<provider_url> provider_name=<provider_url> provider_version=0.6.11-rc1 -e akash1_address="<akash1 address>"' -t op,provider -vv
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
| `organization` | Organization name | Nil |
| `email` | Contact email | Nil |
| `website` | Website URL | Nil |

### Optional Variables

These variables can be customized but have default values:

| Variable | Description | Default |
|----------|-------------|---------|
| `provider_version` | Version for the provider CRDs to deploy| 0.6.11-rc1 |
| `chain_id` | Blockchain network ID | Nil |

## Storage Configuration

### Local Path Provisioner

The setup script automatically configures the `local-path` StorageClass to use `volumeBindingMode: Immediate` instead of the default `WaitForFirstConsumer`. This prevents issues in single-node clusters where the provider StatefulSet pod can get stuck waiting for volume binding.

**Why this matters:**
- `WaitForFirstConsumer` requires a pod to be scheduled before binding the volume
- In single-node setups, this can create a deadlock where the pod can't start without the volume, and the volume won't bind without the pod
- `Immediate` binding mode binds the volume as soon as the PVC is created

**Manual configuration (if needed):**
```bash
kubectl patch storageclass local-path -p '{"volumeBindingMode":"Immediate"}'
```
