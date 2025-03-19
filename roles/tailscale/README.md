This guide provides details on how to use the Tailscale Ansible role to install, configure  and uninstall tailscale on a host.

note: This role is based on the work at https://github.com/artis3n/ansible-role-tailscale
Original work Copyright (c) Ari Kalfus under Apache License 2.0    

### Running the playbooks
```
ansible-playbook playbooks.yml -e 'host=target' -i inventory_example.yml -v -t install -e 'tailscale_authkey=<auth key> host=k8s_cluster'
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
| `tailscale_statefile_name`     | Tailscale statefile name                                 | No       | refer vars/main.yml  |
| `tailscale_apt_keyring_path`   | Apt key ring path                                        | No       | refer vars/main.yml  |
| `tailscale_apt_repo`           | Apt repository for the Tailscale Install                 | No       | refer vars/main.yml  |
| `tailscale_apt_signkey`        | GPU key for the Tailscale                                | No       | refer vars/main.yml  |
| `tailscale_apt_dependencies`   | Dependencies needed for Tailscale Install                | No       | refer vars/main.yml  |
