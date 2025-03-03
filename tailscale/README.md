This guide provides details on how to use the Tailscale Ansible role to install, configure  and uninstall tailscale on a host.

note: This role is based on the work at https://github.com/artis3n/ansible-role-tailscale
Original work Copyright (c) Ari Kalfus under Apache License 2.0    

### Running the playbooks
```
ansible-playbook playbooks.yaml -e 'host=target' -i inv -v -t install -e 'tailscale_authkey=<auth key>'
```

### Configuration Variables
| Variable                       | Description                                              | Required | Default               |
|--------------------------------|----------------------------------------------------------|----------|-----------------------|
| `tailscale_hostname`           | Name of the host that would be registered in the tailnet | Yes      | None                  |
| `tailscale_authkey`            | Tailscale node authorization key                         | Yes      | None                  |
| `tailscale_args`               | Pass command-line arguments to tailscale up command      | No       | http://localhost:8080 |
| `tailscale_oauth_ephemeral`    | Used only when tailscale_authkey is an OAuth key         | No       | false                 |
| `tailscale_oauth_preauthorized`| Used for manualy device approval                         | No       | false                 |
| `tailscale_tags`               | User supplied tags for the nodes                         | Yes      | []                    |
| `tailscale_up_skip`            | Skip running tailscale up                                | No       | false                 |
| `tailscale_auth_key_in_state`  | Skip storing auth key in the state file                  | No       | false                 |
| `tailscale_up_timeout`         | Set timeout for 'tailscale up' command in seconds        | No       | 120s                  |
| `tailscale_distro`             | OS distribution for the node                             | No       | ubuntu                |
| `tailscale_release`            | Tailscale release to be used for download and isntall    | No       | stable                |
| `tailscale_package`            | Tailscale package name                                   | No       | tailscale             |
| `tailscale_service`            | Tailscale service name                                   | No       | tailscaled            |
| `tailscale_statefile_name`     | Tailscale statefile name                                 | No       | refer vars/main.yaml  |
| `tailscale_apt_keyring_path`   | Apt key ring path                                        | No       | refer vars/main.yaml  |
| `tailscale_apt_repo`           | Apt repository for the Tailscale Install                 | No       | refer vars/main.yaml  |
| `tailscale_apt_signkey`        | GPU key for the Tailscale                                | No       | refer vars/main.yaml  |
| `tailscale_apt_dependencies`   | Dependencies needed for Tailscale Install                | No       | refer vars/main.yaml  |

### Examples

#### Deployment
```
ansible-playbook playbooks.yaml -e 'host=target' -i inv -v -t install -e 'tailscale_authkey=<REDACTED>'
No config file found; using defaults

PLAY [Tailscale Playbook] ********************************************************************************

TASK [Gathering Facts] ***********************************************************************************
[WARNING]: Platform linux on host server1 is using the discovered Python interpreter at
/usr/bin/python3.10, but future installation of another Python interpreter could change the meaning of
that path. See https://docs.ansible.com/ansible-core/2.17/reference_appendices/interpreter_discovery.html
for more information.
ok: [server1]

TASK [tailscale : Skipping Authentication] ***************************************************************
skipping: [server1] => {"false_condition": "tailscale_up_skip"}

TASK [tailscale : Tailscale Auth Key Required] ***********************************************************
skipping: [server1] => {"changed": false, "false_condition": "not tailscale_authkey", "skip_reason": "Conditional result was False"}

TASK [tailscale : Apt Dependencies] **********************************************************************
ok: [server1] => {"cache_update_time": 1740999225, "cache_updated": false, "changed": false}

TASK [tailscale : Add Tailscale Signing Key] *************************************************************
ok: [server1] => {"changed": false, "checksum_dest": "6a4e528ba34735f5140bfd3e4f9ce9cba2f9ce11", "checksum_src": "6a4e528ba34735f5140bfd3e4f9ce9cba2f9ce11", "dest": "/usr/share/keyrings/tailscale-archive-keyring.gpg", "elapsed": 0, "gid": 0, "group": "root", "md5sum": "cd2d634883d0863b763377982db6ec24", "mode": "0644", "msg": "OK (unknown bytes)", "owner": "root", "size": 2288, "src": "/root/.ansible/tmp/ansible-tmp-1740999493.462506-51596-122923829526496/tmpmkw78w0h", "state": "file", "status_code": 200, "uid": 0, "url": "https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg"}

TASK [tailscale : Add Tailscale Repository] **************************************************************
ok: [server1] => {"changed": false, "repo": "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu jammy main", "sources_added": [], "sources_removed": [], "state": "present"}

TASK [tailscale : Install Tailscale] *********************************************************************
ok: [server1] => {"cache_update_time": 1740999225, "cache_updated": false, "changed": false}

TASK [tailscale : Remove legacy state folder] ************************************************************
ok: [server1] => {"changed": false, "path": "/root/.ocl-tailscale", "state": "absent"}

TASK [tailscale : Determine state folder] ****************************************************************
ok: [server1] => {"ansible_facts": {"tailscale_state_folder": "/root/.ocl-tailscale/state"}, "changed": false}

TASK [tailscale : Set state folder] **********************************************************************
changed: [server1] => (item=/root/.ocl-tailscale/state) => {"ansible_loop_var": "item", "changed": true, "gid": 0, "group": "root", "item": "/root/.ocl-tailscale/state", "mode": "0700", "owner": "root", "path": "/root/.ocl-tailscale/state", "size": 4096, "state": "directory", "uid": 0}

TASK [tailscale : Enable Service] ************************************************************************
changed: [server1] => {"changed": true, "enabled": true, "name": "tailscaled", "state": "started", "status": {"ActiveEnterTimestamp": "n/a", "ActiveEnterTimestampMonotonic": "0", "ActiveExitTimestamp": "n/a", "ActiveExitTimestampMonotonic": "0"}}

TASK [tailscale : Fetch Tailscale status] ****************************************************************
ok: [server1] => {"changed": false, "cmd": ["tailscale", "status", "--json"], "delta": "0:00:00.009270", "end": "2025-03-03 10:58:57.578413", "msg": "", "rc": 0, "start": "2025-03-03 10:58:57.569143", "stderr": "", "stderr_lines": [], "stdout": "{\n  \"Version\": \},", "  \"Health\": [", "    \"Tailscale is stopped.\"", "  ],", "  \"MagicDNSSuffix\": \"\",", "  \"CurrentTailnet\": null,", "  \"CertDomains\": null,", "  \"Peer\": null,", "  \"User\": null,", "  \"ClientVersion\": null", "}"

TASK [tailscale : Parse status JSON] *********************************************************************
ok: [server1] => {"ansible_facts": {"tailscale_is_online": false, "tailscale_version": "1.80.2-t62b8bf6a0-g3c35ee987"}, "changed": false}

TASK [tailscale : Tailscale version and online status] ***************************************************
ok: [server1] => {
    "msg": "Ver: 1.80.2-t62b8bf6a0-g3c35ee987 Online: False"
}

TASK [tailscale : Prepend 'tag:' to each item in the list] ***********************************************
ok: [server1] => {"ansible_facts": {"tailscale_prepared_tags": []}, "changed": false}

TASK [tailscale : Build `tailscale up` arguments strings] ************************************************
ok: [server1] => {"censored": "the output has been hidden due to the fact that 'no_log: true' was specified for this result", "changed": false}

TASK [tailscale : Authkey Type] **************************************************************************
ok: [server1] => {
    "msg": "API Token"
}

TASK [tailscale : Build the final tailscale_args] ********************************************************
ok: [server1] => {"censored": "the output has been hidden due to the fact that 'no_log: true' was specified for this result", "changed": false}

TASK [tailscale : Final `tailscale up` arguments string] *************************************************
ok: [server1] => {"censored": "the output has been hidden due to the fact that 'no_log: true' was specified for this result"}

TASK [tailscale : Save State] ****************************************************************************
changed: [server1] => {"changed": true, "checksum": "6840e7a34a5009e6f9988b68a559dbfbfbc5cb12", "dest": "/root/.ocl-tailscale/state/.ocl-tailscale", "gid": 0, "group": "root", "md5sum": "0ecd2ac3b081d6acd26d94319586e671", "mode": "0644", "owner": "root", "size": 65, "src": "/root/.ansible/tmp/ansible-tmp-1740999538.916947-51922-58809767000563/.source", "state": "file", "uid": 0}

TASK [tailscale : Bring Tailscale Up] ********************************************************************
ASYNC OK on server1: jid=j691183833068.2672121
changed: [server1] => {"ansible_job_id": "j691183833068.2672121", "changed": true, "cmd": ["tailscale", "up", "--auth-key=REDACTED", "--hostname=", "--ssh", "--timeout=120s", "--authkey=REDACTED", "--hostname=", "--ssh"], "delta": "0:00:01.210223", "end": "2025-03-03 10:59:21.134695", "finished": 1, "msg": "", "rc": 0, "results_file": "/root/.ansible_async/j691183833068.2672121", "start": "2025-03-03 10:59:19.924472", "started": 1, "stderr": "", "stderr_lines": [], "stdout": "", "stdout_lines": []}

TASK [tailscale : Report non-sensitive stdout from "tailscale up"] ***************************************
skipping: [server1] => {"false_condition": "tailscale_start is failed"}

TASK [tailscale : Pausing to highlight stdout message above] *********************************************
skipping: [server1] => {"changed": false, "false_condition": "nonsensitive_stdout is not skipped", "skip_reason": "Conditional result was False"}

TASK [tailscale : Clear State Upon Error] ****************************************************************
skipping: [server1] => {"changed": false, "false_condition": "tailscale_start is failed", "skip_reason": "Conditional result was False"}

TASK [tailscale : Report redacted failure from "tailscale up"] *******************************************
skipping: [server1] => {"changed": false, "false_condition": "tailscale_start is failed", "skip_reason": "Conditional result was False"}

TASK [tailscale : Facts | Get IPv4 address] **************************************************************
ok: [server1] => {"changed": false, "cmd": ["tailscale", "ip", "--4"], "delta": "0:00:00.011243", "end": "2025-03-03 10:59:41.008350", "msg": "", "rc": 0, "start": "2025-03-03 10:59:40.997107", "stderr": "", "stderr_lines": [], "stdout": "100.82.9.43", "stdout_lines": ["100.82.9.43"]}

TASK [tailscale : Facts | Register IP facts] *************************************************************
ok: [server1] => {"ansible_facts": {"tailscale_node_ipv4": "100.82.9.43"}, "changed": false}

TASK [tailscale : Facts | Get Tailscale host facts] ******************************************************
ok: [server1] => {"changed": false, "cmd": ["tailscale", "whois", "--json", "100.82.9.43"], "delta": "0:00:00.008875", "end": "2025-03-03 10:59:46.783116", "msg": "", "rc": 0, "start": "2025-03-03 10:59:46.774241", "stderr": "", "stderr_lines": [], "stdout": " "}

TASK [tailscale : Facts | Parse Tailscale host information] **********************************************
ok: [server1] => {"ansible_facts": {"tailscale_whois": }, "changed": false}

TASK [tailscale : Facts | Set Tailscale host facts] ******************************************************
ok: [server1] => {"ansible_facts": }, "changed": false

TASK [tailscale : Facts | Display key facts] *************************************************************
ok: [server1] => (item=tailscale_node_hostname_full) => {
}

RUNNING HANDLER [tailscale : Fetch Tailscale status] *****************************************************
ok: [server1] => {"changed": false, "cmd": ["tailscale", "status", "--json"], "delta": "0:00:00.011259", "end": "2025-03-03 10:59:52.933426", "msg": "", "rc": 0, "start": "2025-03-03 10:59:52.922167", "stderr": "", "stderr_lines": [], "stdout": "{\n  \"Version\": \"1.80.2-t62b8bf6a0-g3c35ee987\" "}}

RUNNING HANDLER [tailscale : Parse status JSON] **********************************************************
ok: [server1] => {"ansible_facts": {"tailscale_is_online": true}, "changed": false}

RUNNING HANDLER [tailscale : Tailscale online status] ****************************************************
ok: [server1] => {
    "msg": "Online: True"
}

RUNNING HANDLER [tailscale : Assert Tailscale is Connected] **********************************************
ok: [server1] => {
    "changed": false,
    "msg": "All assertions passed"
}

PLAY RECAP ***********************************************************************************************
server1             : ok=29   changed=4    unreachable=0    failed=0    skipped=6    rescued=0    ignored=0
```
