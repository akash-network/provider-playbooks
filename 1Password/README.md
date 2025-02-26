This guide provides details on how to use 1Password Ansible role to retrieve the b64-key and b64-keysecret from the 1Password vault.

### Prerequisites
- 1password-cli
- Docker
- Docker compose

### Install the requirements
We need to install the Docker collection. We use Docker Compose to spin up the 1Password Connect server locally. This facilitates fetching keys from the 1Password vault.

```
ansible-galaxy install -r requirements.yml
```

### Running the playbook
```
ansible-playbook playbooks.yaml -v
```

### Configuration Variables
| Variable                 | Description                                        | Required | Default               |
|--------------------------|----------------------------------------------------|------- --|-----------------------|
| `vault_name`             | Name of the vault inside 1Password                 | Yes      | None                  |
| `provider_name`          | Name of the provider                               | Yes      | None                  |
| `connect_host`           | URL of the host                                    | No       | http://localhost:8080 |
| `provider_b64_key_field` | b64-key that will be fetched from the vault        | No       | b64-key               |
| `provider_b64_sec_field` | b64-keysecret that will be fetched from the vault  | No       | b64-keysecret         |
| `opconnect_account_name` | Account name for the 1Password                     | Yes      | my.1password.com      |
| `opconnect_server_name`  | Server name for the 1Password connect              | No       | op_connect_server     |
| `opconnect_token_name`   | Token name for the server in 1Password connect     | No       | op_connect_token      |


### Examples

#### Deployment
```
ansible-playbook playbooks.yaml -v
No config file found; using defaults
[WARNING]: No inventory was parsed, only implicit localhost is available
[WARNING]: provided hosts list is empty, only localhost is available. Note that the implicit localhost does not match 'all'

PLAY [Retrieve 1Password items] *******************************************************************************************************************************

TASK [1Password : Sign in to 1P account] **********************************************************************************************************************
changed: [localhost] => {"changed": true, "cmd": "op signin --account my.1password.com", "delta": "0:00:00.431875", "end": "2025-02-26 00:03:13.199228", "msg": "", "rc": 0, "start": "2025-02-26 00:03:12.767353", "stderr": "", "stderr_lines": [], "stdout": "", "stdout_lines": []}

TASK [1Password : Check if connect server exists] *************************************************************************************************************
ok: [localhost] => {"changed": false, "cmd": "op connect server list --format=json", "delta": "0:00:01.566769", "end": "2025-02-26 00:03:14.917347", "msg": "", "rc": 0, "start": "2025-02-26 00:03:13.350578", "stderr": "", "stderr_lines": [], "stdout": "[\n  {\n    \"id\": \"<REDACTED>\",\n    \"name\": \"Providers\",\n    \"state\": \"ACTIVE\",\n    \"created_at\": \"2025-02-25T12:29:27Z\",\n    \"creator_id\": \"<REDACTED>\",\n    \"tokens_version\": 2\n  },\n  {\n    \"id\": \"<REDACTED>\",\n    \"name\": \"Providerss\",\n    \"state\": \"ACTIVE\",\n    \"created_at\": \"2025-02-25T13:38:13Z\",\n    \"creator_id\": \"<REDACTED>\",\n    \"tokens_version\": 1\n  },\n  {\n    \"id\": \"<REDACTED>\",\n    \"name\": \"Providerss\",\n    \"state\": \"ACTIVE\",\n    \"created_at\": \"2025-02-25T13:40:08Z\",\n    \"creator_id\": \"<REDACTED>\",\n    \"tokens_version\": 2\n  }\n]", "stdout_lines": ["[", "  {", "    \"id\": \"<REDACTED>\",", "    \"name\": \"Providers\",", "    \"state\": \"ACTIVE\",", "    \"created_at\": \"2025-02-25T12:29:27Z\",", "    \"creator_id\": \"<REDACTED>\",", "    \"tokens_version\": 2", "  },", "  {", "    \"id\": \"<REDACTED>\",", "    \"name\": \"Providerss\",", "    \"state\": \"ACTIVE\",", "    \"created_at\": \"2025-02-25T13:38:13Z\",", "    \"creator_id\": \"<REDACTED>\",", "    \"tokens_version\": 1", "  },", "  {", "    \"id\": \"<REDACTED>\",", "    \"name\": \"Providerss\",", "    \"state\": \"ACTIVE\",", "    \"created_at\": \"2025-02-25T13:40:08Z\",", "    \"creator_id\": \"<REDACTED>\",", "    \"tokens_version\": 2", "  }", "]"]}

TASK [1Password : set_fact] ***********************************************************************************************************************************
ok: [localhost] => {"ansible_facts": {"connect_servers": [{"created_at": "2025-02-25T12:29:27Z", "creator_id": "<REDACTED>", "id": "<REDACTED>", "name": "Providers", "state": "ACTIVE", "tokens_version": 2}, {"created_at": "2025-02-25T13:38:13Z", "creator_id": "<REDACTED>", "id": "<REDACTED>", "name": "Providerss", "state": "ACTIVE", "tokens_version": 1}, {"created_at": "2025-02-25T13:40:08Z", "creator_id": "<REDACTED>", "id": "<REDACTED>", "name": "Providerss", "state": "ACTIVE", "tokens_version": 2}], "server_matches": []}, "changed": false}

TASK [1Password : fail] ***************************************************************************************************************************************
skipping: [localhost] => {"changed": false, "false_condition": "server_matches | length != 0", "skip_reason": "Conditional result was False"}

TASK [1Password : Create 1Password connect server] ************************************************************************************************************
changed: [localhost] => {"changed": true, "cmd": "op connect server create ansibleconnecttest --vaults Providerss -f", "delta": "0:00:03.488828", "end": "2025-02-26 00:03:18.589047", "msg": "", "rc": 0, "start": "2025-02-26 00:03:15.100219", "stderr": "", "stderr_lines": [], "stdout": "Set up a Connect server.\nUUID: <REDACTED>\nCredentials file: /Users/workd/provider-playbooks/1password-credentials.json", "stdout_lines": ["Set up a Connect server.", "UUID: <REDACTED>", "Credentials file: /Users/workd/provider-playbooks/1password-credentials.json"]}

TASK [1Password : Extract UUID from output] *******************************************************************************************************************
ok: [localhost] => {"ansible_facts": {"server_uuid": "<REDACTED>"}, "changed": false}

TASK [1Password : Create op token] ****************************************************************************************************************************
changed: [localhost] => {"changed": true, "cmd": "op connect token create op_connect_token --server QRHPEHHYVVFZPF3D6TPHAPVEFQ --vault Providerss", "delta": "0:00:03.574326", "end": "2025-02-26 00:03:22.349629", "msg": "", "rc": 0, "start": "2025-02-26 00:03:18.775303", "stderr": "", "stderr_lines": [], "stdout": "<REDACTED>", "stdout_lines": ["<REDACTED>"]}

TASK [1Password : Copy to the Playbook dir /Users/workd/provider-playbooks] **************************************************************************
ok: [localhost] => {"changed": false, "checksum": "4b6b3870abd4728f6df5e2d837a73e1fa3df52ef", "dest": "/Users/workd/provider-playbooks/docker-compose.yaml", "gid": 20, "group": "staff", "mode": "0644", "owner": "vsa", "path": "/Users/workd/provider-playbooks/docker-compose.yaml", "size": 443, "state": "file", "uid": 501}

TASK [1Password : Run 1Password Connect in detached mode] *****************************************************************************************************
changed: [localhost] => {"changed": true, "cmd": "docker-compose down && docker-compose -f /Users/workd/provider-playbooks/docker-compose.yaml up -d", "delta": "0:00:04.331639", "end": "2025-02-26 00:03:27.221090", "msg": "", "rc": 0, "start": "2025-02-26 00:03:22.889451", "stderr": " Container provider-playbooks-op-connect-sync-1  Stopping\n Container provider-playbooks-op-connect-api-1  Stopping\n Container provider-playbooks-op-connect-sync-1  Stopped\n Container provider-playbooks-op-connect-sync-1  Removing\n Container provider-playbooks-op-connect-sync-1  Removed\n Container provider-playbooks-op-connect-api-1  Stopped\n Container provider-playbooks-op-connect-api-1  Removing\n Container provider-playbooks-op-connect-api-1  Removed\n Network provider-playbooks_default  Removing\n Network provider-playbooks_default  Removed\n Network provider-playbooks_default  Creating\n Network provider-playbooks_default  Created\n Container provider-playbooks-op-connect-api-1  Creating\n Container provider-playbooks-op-connect-sync-1  Creating\n Container provider-playbooks-op-connect-api-1  Created\n Container provider-playbooks-op-connect-sync-1  Created\n Container provider-playbooks-op-connect-sync-1  Starting\n Container provider-playbooks-op-connect-api-1  Starting\n Container provider-playbooks-op-connect-sync-1  Started\n Container provider-playbooks-op-connect-api-1  Started", "stderr_lines": [" Container provider-playbooks-op-connect-sync-1  Stopping", " Container provider-playbooks-op-connect-api-1  Stopping", " Container provider-playbooks-op-connect-sync-1  Stopped", " Container provider-playbooks-op-connect-sync-1  Removing", " Container provider-playbooks-op-connect-sync-1  Removed", " Container provider-playbooks-op-connect-api-1  Stopped", " Container provider-playbooks-op-connect-api-1  Removing", " Container provider-playbooks-op-connect-api-1  Removed", " Network provider-playbooks_default  Removing", " Network provider-playbooks_default  Removed", " Network provider-playbooks_default  Creating", " Network provider-playbooks_default  Created", " Container provider-playbooks-op-connect-api-1  Creating", " Container provider-playbooks-op-connect-sync-1  Creating", " Container provider-playbooks-op-connect-api-1  Created", " Container provider-playbooks-op-connect-sync-1  Created", " Container provider-playbooks-op-connect-sync-1  Starting", " Container provider-playbooks-op-connect-api-1  Starting", " Container provider-playbooks-op-connect-sync-1  Started", " Container provider-playbooks-op-connect-api-1  Started"], "stdout": "", "stdout_lines": []}

TASK [1Password : Test connection to 1Password Connect server] ************************************************************************************************
ok: [localhost] => {"changed": false, "connection": "close", "content_length": "1", "content_type": "text/plain", "cookies": {}, "cookies_string": "", "date": "Tue, 25 Feb 2025 18:33:27 GMT", "elapsed": 0, "msg": "OK (1 bytes)", "redirected": false, "status": 200, "url": "http://localhost:8080/heartbeat"}

TASK [1Password : Debug health check] *************************************************************************************************************************
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

TASK [1Password : Display variables] **************************************************************************************************************************
ok: [localhost] => {
    "msg": "provider: h123.24t5.net, vault_name: Providerss"
}

TASK [1Password : Get the vault ID for Providerss] ************************************************************************************************************
changed: [localhost] => {"changed": true, "cmd": "op vault list --format=json | jq -r '.[] | select(.name==\"Providerss\") | .id'", "delta": "0:00:01.704522", "end": "2025-02-26 00:03:29.307585", "msg": "", "rc": 0, "start": "2025-02-26 00:03:27.603063", "stderr": "", "stderr_lines": [], "stdout": "<REDACTED>", "stdout_lines": ["<REDACTED>"]}

TASK [1Password : Store the vault ID in a variable] ***********************************************************************************************************
ok: [localhost] => {"ansible_facts": {"vault_uuid": "<REDACTED>"}, "changed": false}

TASK [1Password : Find a field labeled "username" in an item] *************************************************************************************************
ok: [localhost] => (item=b64-key) => {"ansible_loop_var": "item", "changed": false, "field": {"id": "password", "section": null, "value": "<REDACTED>"}, "item": "b64-key"}
ok: [localhost] => (item=b64-keysecret) => {"ansible_loop_var": "item", "changed": false, "field": {"id": "yrvac22x2l4dmhanzeljr24uvm", "section": null, "value": "<REDACTED>"}, "item": "b64-keysecret"}

TASK [1Password : Set variables from field values] ************************************************************************************************************
ok: [localhost] => {"ansible_facts": {"b64_key": "<REDACTED>", "b64_keysecret": "<REDACTED>"}, "changed": false}

TASK [1Password : Check and display success message] **********************************************************************************************************
ok: [localhost] => {
    "msg": "Item retrieved successfully"
}

TASK [1Password : Display failure message] ********************************************************************************************************************
skipping: [localhost] => {"changed": false, "false_condition": "b64_key | default('') == '' or b64_keysecret | default('') == ''", "skip_reason": "Conditional result was False"}

PLAY RECAP ****************************************************************************************************************************************************
localhost                  : ok=18   changed=5    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
```

This Ansible role assumes that the a vault is already set up with b64-key and b64-keysecret that will be used for the provider

Role Name
=========

A brief description of the role goes here.

Requirements
------------

Any pre-requisites that may not be covered by Ansible itself or the role should be mentioned here. For instance, if the role uses the EC2 module, it may be a good idea to mention in this section that the boto package is required.

Role Variables
--------------

A description of the settable variables for this role should go here, including any variables that are in defaults/main.yml, vars/main.yml, and any variables that can/should be set via parameters to the role. Any variables that are read from other roles and/or the global scope (ie. hostvars, group vars, etc.) should be mentioned here as well.

Dependencies
------------

A list of other roles hosted on Galaxy should go here, plus any details in regards to parameters that may need to be set for other roles, or variables that are used from other roles.

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: username.rolename, x: 42 }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
