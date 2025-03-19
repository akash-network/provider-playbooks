This guide provides details on how to use OP Ansible role to retrieve the b64-key and b64-keysecret from the OP vault. This Ansible role assumes that the a vault is already set up with b64-key and b64-keysecret.


### Prerequisites
- 1password-cli

Important: When running the ansible-playbook for operations, please use MacOS as your environment. Testing has only been conducted with the 1Password vault configuration on MacOS systems.

### Saving Key and Key Secrets to OP
- Generate the provider mnemonic seed and fund the provider account derived off of that seed.
- Generate the provider key and encrypt it with a new password. This will prompt for the mnemonic.
    ```
    provider-services keys add default --recover
    provider-services keys export default
    ```
- Create a key.pem file and Copy the output of the prior command (provider-services keys export default) into the key.pem file

- Encode the provider key & provider key password into base64.

    ```
    cat key.pem | openssl base64 -A
    echo -n '<passphrase>' | base64
    ```

- Create these records (b64-key, b64-keysecret) in 1password under <vault_name>/<provider-name>/ in 1Password. The vault_name is defaulted to `Providers`. This can be changed in vars/main.yml

### Running the playbook
```
ansible-playbook -i inventory_example.yml playbooks.yml -v -e 'host=provider'
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
