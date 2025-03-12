This guide provides details on how to use OP Ansible role to retrieve the b64-key and b64-keysecret from the OP vault. This Ansible role assumes that the a vault is already set up with b64-key and b64-keysecret.


### Prerequisites
- 1password-cli
- Docker
- Docker compose

### Install the requirements
We need to install the Docker collection. We use Docker Compose to spin up the OP Connect server locally. This facilitates fetching keys from the OP vault.

```
ansible-galaxy install -r requirements.yml
```

### Running the playbook
```
ansible-playbook playbooks.yaml -v
```

### Configuration Variables
| Variable                 | Description                                        | Required | Default               |
|--------------------------|----------------------------------------------------|----------|------------------------|
| `vault_name`             | Name of the vault inside OP                        | Yes      | None                  |
| `provider_name`          | Name of the provider                               | Yes      | None                  |
| `connect_host`           | URL of the host                                    | No       | http://localhost:8080 |
| `provider_b64_key_field` | b64-key that will be fetched from the vault        | No       | b64-key               |
| `provider_b64_sec_field` | b64-keysecret that will be fetched from the vault  | No       | b64-keysecret         |
| `opconnect_account_name` | Account name for the OP                            | Yes      | my.1password.com      |
