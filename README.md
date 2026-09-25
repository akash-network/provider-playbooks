# Akash Provider Playbooks

Ansible automation for building and operating an Akash provider on Ubuntu 24.04
LTS x86_64 hosts.

The interactive installer supports three independent cluster modes:

- **Kubespray** — downloads the pinned Kubespray release and creates a dedicated
  Kubespray environment only when this mode is selected.
- **K3s** — uses this repository's K3s role and project-owned Ansible
  environment. It does not download or use Kubespray.
- **Existing cluster** — installs neither Kubernetes distribution and applies
  only the selected provider roles.

## Requirements

- Ubuntu 24.04 LTS x86_64 on every cluster node
- Root access on the machine running the installer
- SSH console or out-of-band access to authorize the installer's public key;
  password-based SSH is not supported
- Passwordless sudo for non-root SSH users
- A domain and DNS control for provider endpoints
- At least the resources documented in the current Akash provider hardware
  requirements

The installer validates the OS, architecture, CPU, memory, SSH access, and
cluster access before deploying provider services.

During provider configuration, the wizard performs a read-only lookup from the
first node's public IP to suggest its country, city code, UTC offset, and the
accepted Akash `location-region`. It also reads CPU and memory metadata from
that node. Every detected profile is shown for confirmation, and the guided
fallback remains available when IP geolocation or firmware data is incomplete.
Location lookup uses multiple providers to tolerate service outages and rate
limits, and reports the specific failure when automatic detection cannot finish.

The reachable SSH address for each node must be entered first. The wizard
selects an existing local SSH key or generates a dedicated Ed25519 key, displays
the public key and target users, and waits for the operator to add it to each
node's `authorized_keys`. It verifies key-only SSH before performing any
discovery, then detects private and public node addresses over that connection.
SSH continues to use the entered address; when both networks are available, the
operator chooses which one Kubernetes uses for inter-node traffic. Private
addressing is recommended. Public addresses must be directly bound or routed
to their nodes rather than shared behind NAT.

## Install

```bash
git clone https://github.com/akash-network/provider-playbooks.git
cd provider-playbooks
sudo ./scripts/setup_provider.sh
```

The normal installation creates:

- `.venv/` — pinned Ansible environment used by this repository
- `.generated/inventory/` — generated inventory and encoded key material; this
  is the only project runtime directory created by configuration-only mode
- `.cache/kubespray/` — only when Kubespray is selected

All three paths are ignored by Git. Generated files containing wallet, DNS, or
Tailscale credentials are mode `0600`. Base64-encoded credentials are still
secrets and must not be copied into source control.

Use configuration-only mode to inspect generated inventory without installing
packages or changing hosts:

```bash
./scripts/setup_provider.sh --config-only
```

Configuration-only mode does not create `.venv/`, install the isolated Python
runtime on the remote nodes, download Kubespray, or deploy any selected role.
The generated inventory is therefore not immediately runnable on a fresh clone;
complete the local and remote bootstrap under [Manual execution](#manual-execution)
before invoking a role.

## Components

- OS tuning and provider maintenance jobs
- K3s with Calico, or Kubespray Kubernetes
- NVIDIA GPU Operator for GPU nodes, with PCI-ID detection against a pinned
  Akash `provider-configs` database to derive model, memory, interface, and
  Fabric Manager settings automatically
- Rook-Ceph persistent storage
- NGINX Gateway Fabric, cert-manager, and Akash Gateway
- Akash provider, hostname operator, and inventory operator (optional in-cluster Akash node)
- Optional Tailscale access with Kubernetes API TLS SAN integration

GPU nodes must be clean: do not preinstall NVIDIA drivers, CUDA, Container
Toolkit, or the standalone NVIDIA device plugin. Existing host-driver providers
must follow the GPU Operator migration guide before using the GPU role.

## Version policy

All compatibility pins live in [`versions.yml`](versions.yml). The installer and
roles load this file rather than independently selecting `latest` releases.
Update the matrix together with documentation and validation tests.
Wallet creation, recovery, address lookup, and export use the unified `akt` CLI;
the installer verifies the pinned release checksum before installing it. It
creates a dedicated file-backed `provider` context for Akash mainnet
non-interactively, avoiding AKT's general-purpose first-run network wizard.

## Manual execution

Run manual commands from the repository root. A completed normal installation
has already prepared both Python environments, so a role can be rerun directly:

```bash
source .venv/bin/activate
ansible-playbook -i .generated/inventory/hosts.ini playbooks.yml --tags provider
```

After configuration-only mode on a fresh Ubuntu clone, first install the local
prerequisites that normal mode would have installed, then create the pinned
Ansible environment and install its collections:

```bash
sudo apt-get update
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates curl git jq openssh-client openssl \
  python3 python3-pip python3-venv unzip
python3 -m venv .venv
.venv/bin/pip install --requirement requirements.txt
.venv/bin/ansible-galaxy collection install --requirements-file requirements.yml
```

The generated inventory selects the isolated remote interpreter, which does not
exist until the preflight role creates it. Bootstrap every configured node with
the system Python interpreter before running any other tag:

```bash
ANSIBLE_CONFIG="$PWD/ansible.cfg" .venv/bin/ansible-playbook \
  --inventory .generated/inventory/hosts.ini playbooks.yml \
  --tags preflight \
  --extra-vars ansible_python_interpreter=/usr/bin/python3
```

Once preflight succeeds, the generated interpreter setting is usable and the
selected roles can be run normally. For example, on an existing healthy
Kubernetes cluster:

```bash
ANSIBLE_CONFIG="$PWD/ansible.cfg" .venv/bin/ansible-playbook \
  --inventory .generated/inventory/hosts.ini playbooks.yml \
  --tags provider
```

Configuration-only mode does not build a Kubernetes cluster. Run the normal
installer when Kubespray should create the cluster, or run the `k3s` tag after
preflight before applying cluster-dependent roles.

Available tags include `preflight`, `tailscale`, `k3s`, `os`, `local-path`,
`gpu`, `rook-ceph`, and `provider`.

## Validation

```bash
bash -n scripts/setup_provider.sh scripts/lib/*.sh tests/*.sh
shellcheck -x scripts/setup_provider.sh scripts/lib/*.sh tests/*.sh
bash tests/test_installer.sh
.venv/bin/yamllint .
.venv/bin/ansible-playbook --syntax-check -i tests/inventory.ini playbooks.yml
.venv/bin/ansible-playbook -i tests/inventory.ini tests/render_provider.yml
```

CI runs the same shell and Ansible checks.

## Support

- [Akash provider documentation](https://akash.network/docs/providers/)
- [Akash Discord](https://discord.gg/akash)
- Repository issues for reproducible playbook defects
