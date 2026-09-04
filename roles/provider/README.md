# Provider role

Installs the pinned Akash provider stack and its Gateway API dependencies:

- Akash node
- NGINX Gateway Fabric and experimental Gateway API CRDs
- cert-manager and wildcard/default TLS secrets
- Akash Gateway
- hostname and inventory operators
- provider CRDs and provider chart

Chart and application versions are centralized in `versions.yml`. NGINX
Gateway Fabric CRDs and its Helm chart always use the same version.

Persistent storage is opt-in. When `has_persistent_storage` is true, the role
requires the exact Akash-labelled `storage_class_name` and proves that it can
provision and mount a temporary PVC before advertising it. The role does not
assume Rook-Ceph was installed; any compatible, working StorageClass may satisfy
this contract.

The rendered `/root/provider/provider.yaml` uses current provider attribute
names, including `location-region`, `capabilities/cpu`, `capabilities/memory`,
`cuda`, explicit feature flags, and audit contact/location fields. Shared-memory
storage (`ram`) is enabled for every provider. Persistent storage and GPU
attributes are emitted only when their installation and validation succeed.
The setup wizard derives the accepted `location-region`, country, city, and UTC
attributes from node 1 when possible, detects its CPU architecture, vendor, DDR
generation, and ECC capability, and maps NVIDIA PCI IDs to canonical Akash GPU
model, memory, and interface attributes instead of relying on guessed defaults.

The generated provider file is mode `0600`, and Ansible suppresses the template
task output because it contains wallet credentials. For production TLS, select
Cloudflare or Google Cloud DNS-01 in the setup wizard; self-signed wildcard TLS
is a temporary bootstrap option.

Run manually with:

```bash
ansible-playbook -i .generated/inventory/hosts.ini playbooks.yml --tags provider
```
