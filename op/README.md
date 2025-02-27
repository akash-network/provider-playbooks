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
| `opconnect_server_name`  | Server name for the OP connect                     | No       | op_connect_server     |
| `opconnect_token_name`   | Token name for the server in OP connect            | No       | op_connect_token      |


### Examples

#### Deployment
```
ansible-playbook playbooks.yaml -v
No config file found; using defaults
[WARNING]: No inventory was parsed, only implicit localhost is available
[WARNING]: provided hosts list is empty, only localhost is available. Note that the implicit localhost does not match 'all'

PLAY [Retrieve op items] *******************************************************************************************************************************

TASK [op : Check for required binaries] ****************************************************************************************
ok: [localhost] => (item=op) => {"ansible_loop_var": "item", "changed": false, "cmd": "command -v op", "delta": "0:00:00.004035", "end": "2025-02-27 13:02:44.982940", "item": "op", "msg": "", "rc": 0, "start": "2025-02-27 13:02:44.978905", "stderr": "", "stderr_lines": [], "stdout": "/opt/homebrew/bin/op", "stdout_lines": ["/opt/homebrew/bin/op"]}
ok: [localhost] => (item=docker) => {"ansible_loop_var": "item", "changed": false, "cmd": "command -v docker", "delta": "0:00:00.003954", "end": "2025-02-27 13:02:45.130710", "item": "docker", "msg": "", "rc": 0, "start": "2025-02-27 13:02:45.126756", "stderr": "", "stderr_lines": [], "stdout": "/usr/local/bin/docker", "stdout_lines": ["/usr/local/bin/docker"]}
ok: [localhost] => (item=docker compose) => {"ansible_loop_var": "item", "changed": false, "cmd": "command -v docker compose", "delta": "0:00:00.003656", "end": "2025-02-27 13:02:45.277346", "item": "docker compose", "msg": "", "rc": 0, "start": "2025-02-27 13:02:45.273690", "stderr": "", "stderr_lines": [], "stdout": "/usr/local/bin/docker", "stdout_lines": ["/usr/local/bin/docker"]}

TASK [op : Set facts about missing binaries] ***********************************************************************************
ok: [localhost] => {"ansible_facts": {"missing_binaries": []}, "changed": false}

TASK [op : Display missing binaries] *******************************************************************************************
skipping: [localhost] => {"false_condition": "missing_binaries | length > 0"}

TASK [op : Conditional failure based on missing binaries] **********************************************************************
skipping: [localhost] => {"changed": false, "false_condition": "missing_binaries | length > 0", "skip_reason": "Conditional result was False"}

TASK [op : Sign in to op account] **********************************************************************************************************************
changed: [localhost] => {"changed": true, "cmd": "op signin --account my.1password.com", "delta": "0:00:00.431875", "end": "2025-02-26 00:03:13.199228", "msg": "", "rc": 0, "start": "2025-02-26 00:03:12.767353", "stderr": "", "stderr_lines": [], "stdout": "", "stdout_lines": []}

TASK [op : Check if connect server exists] *************************************************************************************************************
ok: [localhost] => {"changed": false, "cmd": "op connect server list --format=json", "delta": "0:00:01.566769", "end": "2025-02-26 00:03:14.917347", "msg": "", "rc": 0, "start": "2025-02-26 00:03:13.350578", "stderr": "", "stderr_lines": [], "stdout": "[\n  {\n    \"id\": \"<REDACTED>\",\n    \"name\": \"Providers\",\n    \"state\": \"ACTIVE\",\n    \"created_at\": \"2025-02-25T12:29:27Z\",\n    \"creator_id\": \"<REDACTED>\",\n    \"tokens_version\": 2\n  },\n  {\n    \"id\": \"<REDACTED>\",\n    \"name\": \"Providerss\",\n    \"state\": \"ACTIVE\",\n    \"created_at\": \"2025-02-25T13:38:13Z\",\n    \"creator_id\": \"<REDACTED>\",\n    \"tokens_version\": 1\n  },\n  {\n    \"id\": \"<REDACTED>\",\n    \"name\": \"Providerss\",\n    \"state\": \"ACTIVE\",\n    \"created_at\": \"2025-02-25T13:40:08Z\",\n    \"creator_id\": \"<REDACTED>\",\n    \"tokens_version\": 2\n  }\n]", "stdout_lines": ["[", "  {", "    \"id\": \"<REDACTED>\",", "    \"name\": \"Providers\",", "    \"state\": \"ACTIVE\",", "    \"created_at\": \"2025-02-25T12:29:27Z\",", "    \"creator_id\": \"<REDACTED>\",", "    \"tokens_version\": 2", "  },", "  {", "    \"id\": \"<REDACTED>\",", "    \"name\": \"Providerss\",", "    \"state\": \"ACTIVE\",", "    \"created_at\": \"2025-02-25T13:38:13Z\",", "    \"creator_id\": \"<REDACTED>\",", "    \"tokens_version\": 1", "  },", "  {", "    \"id\": \"<REDACTED>\",", "    \"name\": \"Providerss\",", "    \"state\": \"ACTIVE\",", "    \"created_at\": \"2025-02-25T13:40:08Z\",", "    \"creator_id\": \"<REDACTED>\",", "    \"tokens_version\": 2", "  }", "]"]}

TASK [op : set_fact] ***********************************************************************************************************************************
ok: [localhost] => {"ansible_facts": {"connect_servers": [{"created_at": "2025-02-25T12:29:27Z", "creator_id": "<REDACTED>", "id": "<REDACTED>", "name": "Providers", "state": "ACTIVE", "tokens_version": 2}, {"created_at": "2025-02-25T13:38:13Z", "creator_id": "<REDACTED>", "id": "<REDACTED>", "name": "Providerss", "state": "ACTIVE", "tokens_version": 1}, {"created_at": "2025-02-25T13:40:08Z", "creator_id": "<REDACTED>", "id": "<REDACTED>", "name": "Providerss", "state": "ACTIVE", "tokens_version": 2}], "server_matches": []}, "changed": false}

TASK [op : fail] ***************************************************************************************************************************************
skipping: [localhost] => {"changed": false, "false_condition": "server_matches | length != 0", "skip_reason": "Conditional result was False"}

TASK [op : Create op connect server] ************************************************************************************************************
changed: [localhost] => {"changed": true, "cmd": "op connect server create ansibleconnecttest --vaults Providerss -f", "delta": "0:00:03.488828", "end": "2025-02-26 00:03:18.589047", "msg": "", "rc": 0, "start": "2025-02-26 00:03:15.100219", "stderr": "", "stderr_lines": [], "stdout": "Set up a Connect server.\nUUID: <REDACTED>\nCredentials file: /Users/workd/provider-playbooks/1password-credentials.json", "stdout_lines": ["Set up a Connect server.", "UUID: <REDACTED>", "Credentials file: /Users/workd/provider-playbooks/1password-credentials.json"]}

TASK [op : Extract UUID from output] *******************************************************************************************************************
ok: [localhost] => {"ansible_facts": {"server_uuid": "<REDACTED>"}, "changed": false}

TASK [op : Create op token] ****************************************************************************************************************************
changed: [localhost] => {"changed": true, "cmd": "op connect token create op_connect_token --server QRHPEHHYVVFZPF3D6TPHAPVEFQ --vault Providerss", "delta": "0:00:03.574326", "end": "2025-02-26 00:03:22.349629", "msg": "", "rc": 0, "start": "2025-02-26 00:03:18.775303", "stderr": "", "stderr_lines": [], "stdout": "<REDACTED>", "stdout_lines": ["<REDACTED>"]}

TASK [op : Copy to the Playbook dir /Users/workd/provider-playbooks] **************************************************************************
ok: [localhost] => {"changed": false, "checksum": "4b6b3870abd4728f6df5e2d837a73e1fa3df52ef", "dest": "/Users/workd/provider-playbooks/docker-compose.yaml", "gid": 20, "group": "staff", "mode": "0644", "owner": "vsa", "path": "/Users/workd/provider-playbooks/docker-compose.yaml", "size": 443, "state": "file", "uid": 501}

TASK [op : Run op Connect in detached mode] *****************************************************************************************************
changed: [localhost] => {"changed": true, "cmd": "docker-compose down && docker-compose -f /Users/workd/provider-playbooks/docker-compose.yaml up -d", "delta": "0:00:04.331639", "end": "2025-02-26 00:03:27.221090", "msg": "", "rc": 0, "start": "2025-02-26 00:03:22.889451", "stderr": " Container provider-playbooks-op-connect-sync-1  Stopping\n Container provider-playbooks-op-connect-api-1  Stopping\n Container provider-playbooks-op-connect-sync-1  Stopped\n Container provider-playbooks-op-connect-sync-1  Removing\n Container provider-playbooks-op-connect-sync-1  Removed\n Container provider-playbooks-op-connect-api-1  Stopped\n Container provider-playbooks-op-connect-api-1  Removing\n Container provider-playbooks-op-connect-api-1  Removed\n Network provider-playbooks_default  Removing\n Network provider-playbooks_default  Removed\n Network provider-playbooks_default  Creating\n Network provider-playbooks_default  Created\n Container provider-playbooks-op-connect-api-1  Creating\n Container provider-playbooks-op-connect-sync-1  Creating\n Container provider-playbooks-op-connect-api-1  Created\n Container provider-playbooks-op-connect-sync-1  Created\n Container provider-playbooks-op-connect-sync-1  Starting\n Container provider-playbooks-op-connect-api-1  Starting\n Container provider-playbooks-op-connect-sync-1  Started\n Container provider-playbooks-op-connect-api-1  Started", "stderr_lines": [" Container provider-playbooks-op-connect-sync-1  Stopping", " Container provider-playbooks-op-connect-api-1  Stopping", " Container provider-playbooks-op-connect-sync-1  Stopped", " Container provider-playbooks-op-connect-sync-1  Removing", " Container provider-playbooks-op-connect-sync-1  Removed", " Container provider-playbooks-op-connect-api-1  Stopped", " Container provider-playbooks-op-connect-api-1  Removing", " Container provider-playbooks-op-connect-api-1  Removed", " Network provider-playbooks_default  Removing", " Network provider-playbooks_default  Removed", " Network provider-playbooks_default  Creating", " Network provider-playbooks_default  Created", " Container provider-playbooks-op-connect-api-1  Creating", " Container provider-playbooks-op-connect-sync-1  Creating", " Container provider-playbooks-op-connect-api-1  Created", " Container provider-playbooks-op-connect-sync-1  Created", " Container provider-playbooks-op-connect-sync-1  Starting", " Container provider-playbooks-op-connect-api-1  Starting", " Container provider-playbooks-op-connect-sync-1  Started", " Container provider-playbooks-op-connect-api-1  Started"], "stdout": "", "stdout_lines": []}

TASK [op : Test connection to op Connect server] ************************************************************************************************
ok: [localhost] => {"changed": false, "connection": "close", "content_length": "1", "content_type": "text/plain", "cookies": {}, "cookies_string": "", "date": "Tue, 25 Feb 2025 18:33:27 GMT", "elapsed": 0, "msg": "OK (1 bytes)", "redirected": false, "status": 200, "url": "http://localhost:8080/heartbeat"}

TASK [op : Debug health check] *************************************************************************************************************************
ok: [localhost] => {
    "health_check": {
        "changed": false,
        "connection": "close",
        "content_length": "1",
        "content_type": "text/plain",
        "cookies": {},
        "cookies_string": "",
        "date": "Tue, 25 Feb 2025 18:33:27 GMT",
        "elapsed": 0,
        "failed": false,
        "msg": "OK (1 bytes)",
        "redirected": false,
        "status": 200,
        "url": "http://localhost:8080/heartbeat"
    }
}

TASK [op : Display variables] **************************************************************************************************************************
ok: [localhost] => {
    "msg": "provider: h123.24t5.net, vault_name: Providerss"
}

TASK [op : Get the vault ID for Providerss] ************************************************************************************************************
changed: [localhost] => {"changed": true, "cmd": "op vault list --format=json | jq -r '.[] | select(.name==\"Providerss\") | .id'", "delta": "0:00:01.704522", "end": "2025-02-26 00:03:29.307585", "msg": "", "rc": 0, "start": "2025-02-26 00:03:27.603063", "stderr": "", "stderr_lines": [], "stdout": "<REDACTED>", "stdout_lines": ["<REDACTED>"]}

TASK [op : Store the vault ID in a variable] ***********************************************************************************************************
ok: [localhost] => {"ansible_facts": {"vault_uuid": "<REDACTED>"}, "changed": false}

TASK [op : Find a field labeled "username" in an item] *************************************************************************************************
ok: [localhost] => (item=b64-key) => {"ansible_loop_var": "item", "changed": false, "field": {"id": "password", "section": null, "value": "<REDACTED>"}, "item": "b64-key"}
ok: [localhost] => (item=b64-keysecret) => {"ansible_loop_var": "item", "changed": false, "field": {"id": "yrvac22x2l4dmhanzeljr24uvm", "section": null, "value": "<REDACTED>"}, "item": "b64-keysecret"}

TASK [op : Set variables from field values] ************************************************************************************************************
ok: [localhost] => {"ansible_facts": {"b64_key": "<REDACTED>", "b64_keysecret": "<REDACTED>"}, "changed": false}

TASK [op : Check and display success message] **********************************************************************************************************
ok: [localhost] => {
    "msg": "Item retrieved successfully"
}

TASK [op : Display failure message] ********************************************************************************************************************
skipping: [localhost] => {"changed": false, "false_condition": "b64_key | default('') == '' or b64_keysecret | default('') == ''", "skip_reason": "Conditional result was False"}

PLAY RECAP ****************************************************************************************************************************************************
localhost                  : ok=18   changed=5    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
```

