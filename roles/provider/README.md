This ansible role covers the steps required to get the Akash Provider up and running.

## Edge traffic (Gateway API, not Ingress)

The role installs **Kubernetes Gateway API** with **NGINX Gateway Fabric (NGF)** as the data plane, **cert-manager**, the **`akash-gateway`** Helm release (`Gateway`, `TCPRoute`, HTTPS listeners), and placeholder TLS Secrets **`wildcard-ingress-tls`** and **`akash-default-tls`** (chart defaults). It does **not** install **ingress-nginx**.

**Interactive setup:** `scripts/setup_provider.sh` asks for **Cloudflare** (API token) or **GCP Cloud DNS** (project ID + service-account JSON path) so cert-manager can issue the wildcard cert automatically. Choose “skip” to keep self-signed placeholders and configure Let’s Encrypt later.

Before going to production, configure DNS (including **`*.ingress.<your-domain>`** for lease HTTPS). For manual steps, see [Provider installation (prep) – DNS through TLS](https://docs.akash.network/providers/setup-and-installation/kubespray/provider-installation-prep/) (steps 7–9).

## Automatic Capability Detection

This role **automatically detects and configures** your provider's capabilities:

### GPU Detection
- Detects NVIDIA GPUs using `nvidia-smi`
- Extracts model name, memory, and interface type (PCIe/SXM)
- Automatically adds GPU attributes in the new Akash format:
  - `capabilities/gpu/vendor/nvidia/model/<model>`
  - `capabilities/gpu/vendor/nvidia/model/<model>/ram/<ram>`
  - `capabilities/gpu/vendor/nvidia/model/<model>/interface/<interface>`
  - `capabilities/gpu/vendor/nvidia/model/<model>/interface/<interface>/ram/<ram>`
- Also includes `cuda-version` attribute
- **Automatically adds SHM (Shared Memory) support** for GPU workloads:
  - `capabilities/storage/2/class: ram`
  - `capabilities/storage/2/persistent: false`
- Configures inventory-operator with RAM storage class

### Persistent Storage Detection
- Detects Rook-Ceph storage classes labeled with `akash.network=true`
- Automatically adds storage attributes:
  - `capabilities/storage/1/class` (beta1/beta2/beta3)
  - `capabilities/storage/1/persistent: true`

### Example Auto-Generated Attributes

For a provider with RTX 4090 GPUs and beta3 (NVMe) storage:
```yaml
attributes:
  - key: capabilities/gpu/vendor/nvidia/model/rtx4090
    value: "true"
  - key: capabilities/gpu/vendor/nvidia/model/rtx4090/ram/24Gi
    value: "true"
  - key: capabilities/gpu/vendor/nvidia/model/rtx4090/interface/pcie
    value: "true"
  - key: capabilities/gpu/vendor/nvidia/model/rtx4090/interface/pcie/ram/24Gi
    value: "true"
  - key: capabilities/storage/1/class
    value: beta3
  - key: capabilities/storage/1/persistent
    value: "true"
  - key: capabilities/storage/2/class
    value: ram
  - key: capabilities/storage/2/persistent
    value: "false"
  - key: cuda-version
    value: "12.6"
```

**Inventory Operator Configuration:**
```bash
# Automatically configured with:
# - default (local-path)
# - beta3 (persistent storage from Rook-Ceph)
# - ram (SHM for GPU workloads)
```

### Prerequisites
- Ensure to run the OP role to fetch the base64 key and key secret
    - Alternatively you could pass the `provider_b64_key` and `provider_b64_keysecret` using Extra vars
- Kubectl binary
- Access to Kubernetes Cluster
- Helm binary
- (Optional) GPU nodes with NVIDIA drivers installed
- (Optional) Rook-Ceph persistent storage configured    

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
| `ngf_git_ref` | Git ref for Gateway API CRDs bundled with NGINX Gateway Fabric | `v2.5.1` |
| `cert_manager_chart_version` | cert-manager Helm chart version | `v1.19.1` |
| `acme_dns_provider` | `none`, `cloudflare`, or `gcp` (set by setup script or host_vars) | `none` |
| `acme_dns_zone` | DNS zone name for ACME DNS-01 TXT records (e.g. apex domain) | Same as `domain` if unset |
| `acme_cloudflare_api_token_b64` | Cloudflare API token, base64-encoded (script writes this) | — |
| `acme_gcp_project_id` | GCP project ID for Cloud DNS | — |
| `acme_gcp_dns_sa_json_b64` | Service account JSON key file, entire file base64-encoded (script writes this) | — |

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
