#!/usr/bin/env bash

install_system_prerequisites() {
    run "Updating apt metadata" apt-get update
    run "Installing setup prerequisites" env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates curl git jq openssh-client openssl python3 python3-pip python3-venv unzip
}

setup_project_environment() {
    if [[ ! -x "$PROJECT_VENV/bin/ansible-playbook" ]]; then
        run "Creating the project Ansible environment" python3 -m venv "$PROJECT_VENV"
    fi
    run "Installing pinned Python dependencies" "$PROJECT_VENV/bin/pip" install --requirement "$REPO_ROOT/requirements.txt"
    run "Installing pinned Ansible collections" \
        "$PROJECT_VENV/bin/ansible-galaxy" collection install --requirements-file "$REPO_ROOT/requirements.yml"
}

install_akt() {
    local akt_version installed_version archive expected_sha256 actual_sha256
    akt_version=$(version_value akt_version)
    if [[ -x $AKT_BIN ]]; then
        installed_version=$("$AKT_BIN" version | awk '{print $2}')
        [[ $installed_version == "$akt_version" ]] && return 0
    fi

    expected_sha256=$(version_value akt_linux_amd64_sha256)
    archive=$(mktemp)
    TEMP_PATHS+=("$archive")
    curl --fail --silent --show-error --location \
        "https://github.com/akash-network/akt/releases/download/v${akt_version}/akt_${akt_version}_linux_amd64.zip" \
        --output "$archive"
    actual_sha256=$(sha256sum "$archive" | awk '{print $1}')
    [[ $actual_sha256 == "$expected_sha256" ]] || die "AKT CLI archive checksum verification failed."
    unzip -o "$archive" akt -d /usr/local/bin >/dev/null
    chmod 0755 /usr/local/bin/akt
    rm -f "$archive"
    [[ -x $AKT_BIN ]] || die "AKT CLI installation failed."
    installed_version=$("$AKT_BIN" version | awk '{print $2}')
    [[ $installed_version == "$akt_version" ]] || die "AKT CLI version verification failed."
}

ensure_akt_context() {
    local keyrings
    if "$AKT_BIN" --context "$AKT_CONTEXT" context show </dev/null >/dev/null 2>&1; then
        return
    fi

    if ! "$AKT_BIN" context network show mainnet </dev/null >/dev/null 2>&1; then
        run "Configuring the AKT mainnet network" \
            "$AKT_BIN" --quiet context network create mainnet --template mainnet </dev/null
    fi

    keyrings=$("$AKT_BIN" --output json context keyring list </dev/null 2>/dev/null || true)
    if ! jq -e --arg name "$AKT_CONTEXT" '.[] | select(.name == $name)' <<<"$keyrings" >/dev/null 2>&1; then
        run "Creating the AKT provider keyring" \
            "$AKT_BIN" --quiet context keyring create "$AKT_CONTEXT" file </dev/null
    fi

    run "Creating the AKT provider context" \
        "$AKT_BIN" --quiet context create "$AKT_CONTEXT" \
        --network mainnet --keyring "$AKT_CONTEXT" </dev/null
}

run_akt_with_passwords() {
    local keyring_password=$1 export_password=$2
    shift 2
    printf '%s\n%s\n' "$keyring_password" "$export_password" | \
        python3 "$SCRIPT_DIR/lib/akt_password_helper.py" -- "$@"
}

setup_kubespray_environment() {
    local kubespray_version cached_version environment_marker cached_environment_version=
    kubespray_version=$(version_value kubespray_version)
    environment_marker="$KUBESPRAY_DIR/venv/.provider-playbooks-version"
    mkdir -p "$CACHE_DIR"
    if [[ ! -d "$KUBESPRAY_DIR/.git" ]]; then
        run "Downloading Kubespray ${kubespray_version}" git clone --branch "$kubespray_version" --depth 1 \
            https://github.com/kubernetes-sigs/kubespray.git "$KUBESPRAY_DIR"
    else
        cached_version=$(git -C "$KUBESPRAY_DIR" tag --points-at HEAD --list "$kubespray_version" 2>/dev/null || true)
        if [[ $cached_version != "$kubespray_version" ]]; then
            run "Fetching Kubespray ${kubespray_version}" git -C "$KUBESPRAY_DIR" fetch --depth 1 origin \
                "refs/tags/${kubespray_version}:refs/tags/${kubespray_version}"
            run "Switching Kubespray to ${kubespray_version}" git -C "$KUBESPRAY_DIR" checkout \
                --detach --force "refs/tags/${kubespray_version}"
            run "Removing the stale Kubespray Python environment" rm -rf "$KUBESPRAY_DIR/venv"
        fi
    fi
    if [[ -r $environment_marker ]]; then
        cached_environment_version=$(<"$environment_marker")
    fi
    if [[ ! -x "$KUBESPRAY_DIR/venv/bin/ansible-playbook" || \
          $cached_environment_version != "$kubespray_version" ]]; then
        run "Creating the Kubespray Python environment" python3 -m venv --clear "$KUBESPRAY_DIR/venv"
        run "Installing Kubespray dependencies" "$KUBESPRAY_DIR/venv/bin/pip" install \
            --requirement "$KUBESPRAY_DIR/requirements.txt"
        printf '%s\n' "$kubespray_version" >"$environment_marker"
    fi
}

run_project_playbook() {
    local tags=$1
    shift
    ANSIBLE_CONFIG="$REPO_ROOT/ansible.cfg" \
        "$PROJECT_VENV/bin/ansible-playbook" \
        --inventory "$INVENTORY_FILE" "$REPO_ROOT/playbooks.yml" --tags "$tags" "$@"
}
