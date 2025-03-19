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

### Configuration Variables

| Variable                 | Description                                                      | Required | Default                  |
|--------------------------|------------------------------------------------------------------|----------|--------------------------|
| `akash1_address`         | Akash1 Address of the Provider Wallet                            | Yes      | Nil                       |
| `key`                    | Private key                                                      | Yes      | Nil                       |
| `keysecret`              | Passphrase to protect the private key                            | Yes      | Nil                       |
| `domain`                 | Domain name of the provider                                      | Yes      | Nil                       |
| `city`                   | City location information                                        | Yes      | Nil                       |
| `storage_one_class`      | Storage class configuration                                      | No       | beta3                     |
| `storage_one_persistent` | First persistent storage configuration                           | No       | false                     |
| `storage_two_persistent` | Second persistent storage configuration                          | No       | false                     |
| `region`                 | Geographical region                                              | Yes      | us-central                |
| `node`                   | Node endpoint URL                                                | No       | http://akash-node-1:26657 |
| `withdrawal_period`      | Period for withdrawals                                           | No       | 12h                       |
| `chain_id`               | Blockchain network ID                                            | No       | akashnet-2                |
| `cuda_version`           | CUDA version for GPU support                                     | No       | 12.7                      |
| `country`                | Country code                                                     | No       | US                        |
| `host`                   | Host identifier                                                  | No       | akash                     |
| `tier`                   | Service tier                                                     | No       | community                 |
| `organization`           | Organization name                                                | No       | overclock                 |
| `location_type`          | Type of location                                                 | No       | datacenter                |
| `cpu`                    | CPU manufacturer                                                 | No       | intel                     |
| `cpu_arch`               | CPU architecture                                                 | No       | x86-64                    |
| `gpu`                    | GPU manufacturer                                                 | No       | nvidia                    |
| `gpu_model_a100`         | Whether A100 GPU model is available                              | No       | true                      |
| `gpu_model_a100_ram_80`  | Whether A100 with 80GB RAM is available                          | No       | true                      |
| `gpu_model_a100_ram_sxm` | Whether A100 SXM with specific RAM config is available           | No       | true                      |
| `gpu_model_a100_sxm`     | Whether A100 SXM form factor is available                        | No       | true                      |
| `storage_two_class`      | Second storage class configuration                               | No       | ram                       |
| `memory`                 | Memory type                                                      | No       | ddr5ecc                   |
| `network_speed_up`       | Upload network speed in Mbps                                     | No       | 10000                     |
| `network_speed_down`     | Download network speed in Mbps                                   | No       | 10000                     |
| `email`                  | Contact email                                                    | No       | hosting@ovrclk.com        |
| `website`                | Website URL                                                      | No       | https://akash.network     |