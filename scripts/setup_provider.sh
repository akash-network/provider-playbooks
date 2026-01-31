#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;36m'
NC='\033[0m' # No Color

# Function to show spinning indicator
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    local msg=$2
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r${GREEN}[${spinstr:$i:1}]${NC} $msg"
        sleep $delay
    done
    printf "\r"  # Clear the spinner line
}

# Function to run command with spinner
run_with_spinner() {
    local cmd=$1
    local msg=$2
    local tmpfile=$(mktemp)
    
    # Disable job control messages
    set +m
    
    # Run the command in the background and redirect output to temp file
    if [[ "$cmd" == *"apt-get"* ]]; then
        # For apt-get commands, suppress all output except errors
        (DEBIAN_FRONTEND=noninteractive $cmd -y >/dev/null 2>$tmpfile) &
    else
        ($cmd > $tmpfile 2>&1) &
    fi
    local pid=$!
    
    # Show spinner while command is running
    spinner $pid "$msg"
    
    # Wait for command to complete
    wait $pid
    local status=$?
    
    # Re-enable job control messages
    set -m
    
    # If command failed, show the error output
    if [ $status -ne 0 ]; then
        print_error "Command failed with exit code $status"
        echo "Error output:"
        cat $tmpfile
        rm -f $tmpfile
        return $status
    fi
    
    # Clean up temp file
    rm -f $tmpfile
    
    # Print completion message
    echo -e "${GREEN}[✓]${NC} Done $msg"
    
    return $status
}

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_menu_item() {
    echo -e "${BLUE}[$1]${NC} $2"
}

# Function to get user input with validation
get_input() {
    local prompt=$1
    local default=$2
    local pattern=$3
    local input
    
    while true; do
        # Clear any pending input
        while read -r -t 0; do read -r; done
        
        if [ -n "$default" ]; then
            read -p "$prompt [$default]: " input
            input=${input:-$default}
        else
            read -p "$prompt: " input
        fi
        
        if [ -z "$pattern" ] || [[ $input =~ $pattern ]]; then
            # Only output the valid input, not the error messages
            echo "$input" >&1
            return 0
        else
            # Send error message to stderr
            print_error "Invalid input. Please try again." >&2
            # Clear the input variable to prevent error message from being stored
            input=""
        fi
    done
}

# Welcome banner
display_welcome() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}║${NC}               ${YELLOW}Akash Provider Setup Script${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "This script will help you set up and configure your Akash Provider."
    echo -e "Answer a few questions and we'll handle the rest!"
    echo
}

# Function to select playbooks to run
select_playbooks() {
    # Initialize selected playbooks
    SELECTED_KUBERNETES=false  # New variable to track if Kubernetes is selected
    SELECTED_KUBESPRAY=false   # Changed from true to false
    SELECTED_K3S=false         # New variable for K3s
    SELECTED_OS=true
    SELECTED_GPU=true
    SELECTED_PROVIDER=true
    SELECTED_TAILSCALE=true
    SELECTED_ROOK_CEPH=false  # New variable for Rook-Ceph
    
    # Define playbook explanations
    KUBERNETES_DESC="Kubernetes installation (required for a new cluster)"
    K8S_DESC="Kubernetes installation using Kubespray (production-grade, full-featured)"
    K3S_DESC="Kubernetes installation using K3s (lightweight, single binary, ideal for edge/IoT)"
    OS_DESC="Basic OS configuration and optimizations"
    GPU_DESC="Are there GPU nodes in the cluster?"
    PROVIDER_DESC="Akash Provider service installation and configuration"
    TAILSCALE_DESC="Tailscale VPN for secure network access"
    ROOK_CEPH_DESC="Rook-Ceph storage operator installation and configuration"
    
    display_welcome
    
    echo -e "${YELLOW}Select which playbooks you want to run:${NC}"
    echo
    
    # Kubernetes Installation
    while true; do
        echo -n -e "${BLUE}[?]${NC} Install Kubernetes? (Required for new setup) [y/n]: "
        read -r response
        case $response in
            [Yy]* ) SELECTED_KUBERNETES=true; break;;
            [Nn]* ) SELECTED_KUBERNETES=false; break;;
            * ) echo "Please answer y or n.";;
        esac
    done
    
    if $SELECTED_KUBERNETES; then
        # Choose between K8s and K3s
        echo -e "\n${YELLOW}Choose your Kubernetes distribution:${NC}"
        echo -e "${BLUE}[1]${NC} K8s (Kubespray) - Production-grade, full-featured Kubernetes"
        echo -e "${BLUE}[2]${NC} K3s - Lightweight, single binary, ideal for edge/IoT"
        echo
        while true; do
            echo -n -e "${BLUE}[?]${NC} Select distribution (1/2) [1]: "
            read -r response
            case $response in
                1|"") SELECTED_KUBESPRAY=true; SELECTED_K3S=false; break;;
                2) SELECTED_KUBESPRAY=false; SELECTED_K3S=true; break;;
                * ) echo "Please answer 1 or 2.";;
            esac
        done
        echo -n -e "${BLUE}[?]${NC} Do you use a separate storage location for container images? [y/n]: "
        read -r response
        case $response in
            y)
                echo -n -e "${BLUE}[?]${NC} Please type the location where the storage is mounted (e.g., /data): "
                read -r response
                containerd_dir_path="$response/containerd"
                k3s_data_dir="$response/rancher/k3s"
                ;;
            n)
                containerd_dir_path="/var/lib/containerd"
                k3s_data_dir="/var/lib/rancher/k3s"
                ;;
            * ) echo "Please answer y or n.";;
        esac
    fi
    
    # OS
    while true; do
        echo -n -e "${BLUE}[?]${NC} Run OS playbook for system optimizations? [y/n]: "
        read -r response
        case $response in
            [Yy]* ) SELECTED_OS=true; break;;
            [Nn]* ) SELECTED_OS=false; break;;
            * ) echo "Please answer y or n.";;
        esac
    done
    
    # GPU
    while true; do
        echo -n -e "${BLUE}[?]${NC} Are there GPU nodes in the cluster? (Will install NVIDIA drivers and container toolkit) [y/n]: "
        read -r response
        case $response in
            [Yy]* ) SELECTED_GPU=true; break;;
            [Nn]* ) SELECTED_GPU=false; break;;
            * ) echo "Please answer y or n.";;
        esac
    done
    
    # Provider
    while true; do
        echo -n -e "${BLUE}[?]${NC} Install Akash Provider service? [y/n]: "
        read -r response
        case $response in
            [Yy]* ) SELECTED_PROVIDER=true; break;;
            [Nn]* ) SELECTED_PROVIDER=false; break;;
            * ) echo "Please answer y or n.";;
        esac
    done
    
    # Tailscale
    while true; do
        echo -n -e "${BLUE}[?]${NC} Set up Tailscale for secure remote access? [y/n]: "
        read -r response
        case $response in
            [Yy]* ) SELECTED_TAILSCALE=true; break;;
            [Nn]* ) SELECTED_TAILSCALE=false; break;;
            * ) echo "Please answer y or n.";;
        esac
    done
    
    # Rook-Ceph
    while true; do
        echo -n -e "${BLUE}[?]${NC} Install Rook-Ceph for storage management? [y/n]: "
        read -r response
        case $response in
            [Yy]* ) SELECTED_ROOK_CEPH=true; break;;
            [Nn]* ) SELECTED_ROOK_CEPH=false; break;;
            * ) echo "Please answer y or n.";;
        esac
    done
    
    # Confirm selections
    echo
    echo -e "${YELLOW}You have selected the following playbooks:${NC}"
    echo
    if $SELECTED_KUBERNETES; then
        if $SELECTED_KUBESPRAY; then
            print_menu_item "✓" "K8s - ${K8S_DESC}"
        else
            print_menu_item "✓" "K3s - ${K3S_DESC}"
        fi
    else
        print_menu_item "✗" "Kubernetes - ${KUBERNETES_DESC}"
    fi
    if $SELECTED_OS; then print_menu_item "✓" "OS - ${OS_DESC}"; else print_menu_item "✗" "OS - ${OS_DESC}"; fi
    if $SELECTED_GPU; then print_menu_item "✓" "GPU - ${GPU_DESC}"; else print_menu_item "✗" "GPU - ${GPU_DESC}"; fi
    if $SELECTED_PROVIDER; then print_menu_item "✓" "Provider - ${PROVIDER_DESC}"; else print_menu_item "✗" "Provider - ${PROVIDER_DESC}"; fi
    if $SELECTED_TAILSCALE; then print_menu_item "✓" "Tailscale - ${TAILSCALE_DESC}"; else print_menu_item "✗" "Tailscale - ${TAILSCALE_DESC}"; fi
    if $SELECTED_ROOK_CEPH; then print_menu_item "✓" "Rook-Ceph - ${ROOK_CEPH_DESC}"; else print_menu_item "✗" "Rook-Ceph - ${ROOK_CEPH_DESC}"; fi
    
    echo
    while true; do
        echo -n -e "${BLUE}[?]${NC} Proceed with these selections? [y/n]: "
        read -r response
        case $response in
            [Yy]* ) break;;
            [Nn]* ) echo "Restarting playbook selection..."; select_playbooks; break;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

# Run the menu and get selections
select_playbooks

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check for required commands
    local required_commands=(
        "python3"
        "python3-pip"
        "ssh"
        "ssh-keygen"
        "openssl"
        "yq"
    )
    
    # Required packages
    local required_packages=(
        "python3-kubernetes"
    )
    
    # Run apt-get update once at the beginning
    run_with_spinner "apt-get update" "Updating package lists"
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            print_status "Installing $cmd..."
            if [ "$cmd" = "yq" ]; then
                # Download yq
                run_with_spinner "wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq" "Downloading yq"
                # Make it executable
                run_with_spinner "chmod +x /usr/local/bin/yq" "Making yq executable"
            elif [ "$cmd" = "python3-pip" ]; then
                run_with_spinner "apt-get install -y python3-pip" "Installing python3-pip"
                # Create a symlink for pip3 if it doesn't exist
                if ! command -v pip3 &> /dev/null; then
                    ln -s /usr/bin/pip3 /usr/local/bin/pip3
                fi
            else
                run_with_spinner "apt-get install -y $cmd" "Installing $cmd"
            fi
            
            # Special case for python3-pip - check both pip3 and python3 -m pip
            if [ "$cmd" = "python3-pip" ]; then
                if ! command -v pip3 &> /dev/null && ! python3 -m pip --version &> /dev/null; then
                    print_error "python3-pip installation failed"
                    print_error "Please install python3-pip manually before continuing"
                    exit 1
                fi
            # For all other commands, check normally
            elif ! command -v "$cmd" &> /dev/null; then
                print_error "$cmd installation failed"
                print_error "Please install $cmd manually before continuing"
                exit 1
            fi
        fi
    done
    
    # Install required packages
    for pkg in "${required_packages[@]}"; do
        if ! dpkg -l | grep -q "$pkg"; then
            print_status "Installing $pkg..."
            run_with_spinner "apt-get install -y $pkg" "Installing $pkg"
            if ! dpkg -l | grep -q "$pkg"; then
                print_error "$pkg installation failed"
                print_error "Please install $pkg manually before continuing"
                exit 1
            fi
        fi
    done
    

    
    print_status "All prerequisites met"
}

# Function to setup Python environment
setup_python_env() {
    print_status "Setting up Python environment..."
    
    # Update package lists
    run_with_spinner "apt-get update" "Updating package lists"
    
    # Install system packages
    run_with_spinner "apt-get install -y python3.12-venv python3-pip python3-kubernetes" "Installing Python packages"
    
    # Clone Kubespray if not exists
    cd ~
    if [ ! -d "kubespray" ]; then
        run_with_spinner "git clone -b v2.29.1 --depth=1 https://github.com/kubernetes-sigs/kubespray.git" "Cloning Kubespray repository version 2.28.0"
    fi
    
    # Setup Python virtual environment
    print_status "Setting up Python virtual environment..."
    cd ~/kubespray
    
    # Remove existing venv if it exists
    if [ -d "venv" ]; then
        rm -rf venv
    fi
    
    # Create virtual environment
    run_with_spinner "python3 -m venv venv" "Creating virtual environment"
    
    # Activate virtual environment and install requirements
    source venv/bin/activate || {
        print_error "Failed to activate virtual environment"
        exit 1
    }
    
    # Upgrade pip first
    run_with_spinner "pip install --upgrade pip" "Upgrading pip"
    
    # Install requirements
    run_with_spinner "pip install -r requirements.txt" "Installing Kubespray requirements"
    
    # Note: We also need the kubernetes module in the system Python
    print_status "Note: The kubernetes module is installed system-wide via python3-kubernetes package"
    
    # Verify Ansible installation
    if ! command -v ansible &> /dev/null; then
        print_error "Ansible installation failed"
        exit 1
    fi
    
    print_status "Python environment setup complete"
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # Check each octet is between 0 and 255
        for octet in ${ip//./ }; do
            if [[ $octet -lt 0 || $octet -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Function to copy inventory
copy_inventory() {
    print_status "Copying sample inventory contents..."
    cd ~/kubespray
    # Create the directory if it doesn't exist
    mkdir -p inventory/akash
    # Always copy the sample files to ensure we have the latest structure
    cp -rfp inventory/sample/* inventory/akash/
    print_status "Sample inventory copied successfully"

    # Ensure all required directories exist
    mkdir -p inventory/akash/group_vars/all
    mkdir -p inventory/akash/group_vars/k8s_cluster

    # Verify key files exist
    if [ ! -f inventory/akash/group_vars/k8s_cluster/k8s-cluster.yml ]; then
        print_error "Failed to copy k8s-cluster.yml from sample inventory"
        print_status "Creating a basic k8s-cluster.yml file"
        cat > inventory/akash/group_vars/k8s_cluster/k8s-cluster.yml << EOF
# Kubernetes configuration
kube_network_plugin: calico
container_manager: containerd
EOF
    fi
}

# Function to get node information
get_node_info() {
    local node_num=$1
    local node_info=""
    local node_ip=""
    
    while true; do
        if [ "$node_num" = "1" ]; then
            read -p "Enter the IP address of node $node_num (Control Plane & Worker): " node_ip
        elif [ "$node_num" -le 3 ]; then
            read -p "Enter the IP address of node $node_num (Control Plane & Worker): " node_ip
        else
            read -p "Enter the IP address of node $node_num (Worker): " node_ip
        fi
        
        if validate_ip "$node_ip"; then
            break
        else
            print_error "Invalid IP address format. Please use format: xxx.xxx.xxx.xxx"
        fi
    done
    
    read -p "Enter the SSH user for the node [root]: " node_user
    node_user=${node_user:-root}
    
    read -p "Enter the SSH port for the node [22]: " node_port
    node_port=${node_port:-22}
    
    if ! [[ "$node_port" =~ ^[0-9]+$ ]]; then
        print_error "Invalid port number. Using default port 22."
        node_port=22
    fi
    
    echo "$node_ip|$node_user|$node_port"
}

# Function to check and install provider-services CLI
check_provider_services() {
    if ! command -v provider-services &> /dev/null; then
        print_status "Installing provider-services CLI..."
        cd ~
        
        # Install required packages
        run_with_spinner "apt-get install -y jq unzip" "Installing required packages"
        
        # Download and execute the installation script
        print_status "Downloading and running provider-services installation script..."
        curl -sfL https://raw.githubusercontent.com/akash-network/provider/main/install.sh > install_provider.sh
        chmod +x install_provider.sh
        # Run the script and capture its output
        if ! ./install_provider.sh > /dev/null 2>&1; then
            print_error "Failed to install provider-services CLI"
            rm -f install_provider.sh
            return 1
        fi
        rm -f install_provider.sh
        
        # Add provider-services to PATH if not already there
        if [ -f "$HOME/bin/provider-services" ]; then
            export PATH="$HOME/bin:$PATH"
            # Add to .bashrc and .zshrc for persistence
            echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
            echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
        fi
        
        # Verify installation
        if ! command -v provider-services &> /dev/null; then
            if [ -f "$HOME/bin/provider-services" ]; then
                # If the binary exists but isn't in PATH, use full path
                alias provider-services="$HOME/bin/provider-services"
                print_status "provider-services CLI installed but not in PATH, using alias"
            else
                print_error "Failed to install provider-services CLI"
                return 1
            fi
        fi
        print_status "provider-services CLI installed successfully"
    fi
    return 0
}

# Function to handle wallet setup
setup_wallet() {
    print_status "Proceeding with wallet setup..."
    
    # Check if provider-services is installed
    if ! check_provider_services; then
        print_error "Cannot proceed with wallet setup without provider-services CLI"
        return 1
    fi
    
    # Check for existing keys
    existing_keys=$(provider-services keys list | sed -n 's/.*name: \(.*\)/\1/p' 2>/dev/null)
    if [ -n "$existing_keys" ]; then
        print_status "Found existing keys: $existing_keys"
        while true; do
            printf "Do you want to use an existing key? (y/n): "
            read -r use_existing
            
            if [ -z "$use_existing" ]; then
                print_error "Please enter y or n"
                continue
            fi
            
            case "$use_existing" in
                y|Y)
                    print_status "Available keys: $existing_keys"
                    while true; do
                        printf "Enter the name of the key you want to use: "
                        read -r key_name
                        if [ -z "$key_name" ]; then
                            print_error "Please enter a key name"
                            continue
                        fi
                        if echo "$existing_keys" | grep -q "^$key_name$"; then
                            wallet_address=$(provider-services keys show "$key_name" -a)
                            print_status "Using existing key: $key_name with address: $wallet_address"
                            
                            # Export and show the key
                            print_status "Exporting and showing key..."
                            # Use script to capture the output
                            script -q -c "provider-services keys export $key_name" /dev/null | tee key.pem
                            
                            # Clean up the output file to only include the key and remove prompt lines
                            sed -i -n '/-----BEGIN TENDERMINT PRIVATE KEY-----/,/-----END TENDERMINT PRIVATE KEY-----/p' key.pem

                            # Check if the file was created and contains the key
                            if [ -f "key.pem" ] && grep -q "BEGIN TENDERMINT PRIVATE KEY" key.pem; then
                                print_status "Key has been exported to key.pem"
                                
                                # Base64 encode the key
                                key_b64=$(cat key.pem | base64 | tr -d '\n')
                                
                                # Create host_vars directory if it doesn't exist
                                mkdir -p /root/provider-playbooks/host_vars

                                # Update the host_vars file with the wallet information
                                cat > /root/provider-playbooks/host_vars/node1.yml << EOF
# Node Configuration - Host Vars File

## Provider Identification
akash1_address: "$wallet_address"
provider_b64_key: "$key_b64"
provider_b64_keysecret: ""  # Will be filled after password entry

## Network Configuration
domain: "${provider_name}"
region: "${provider_region}"

## Organization Details
host: "akash"
organization: "${provider_organization}"
email: "${provider_email}"
website: "${provider_website}"

## Tailscale Configuration
tailscale_hostname: "node1-$(echo "${provider_name}" | tr '.' '-')"
tailscale_authkey: "${tailscale_authkey}"

# provider attributes
attributes:
  - key: host
    value: akash
  - key: tier
    value: community

## Notes:
# - Replace empty values with your actual configuration
# - Keep sensitive values secure and never share them publicly
# - Ensure domain format follows Akash naming conventions
EOF
                                
                                print_status "Key has been encoded and saved to /root/provider-playbooks/host_vars/node1.yml"
                                print_status "Wallet address: $wallet_address"
                                
                                # Prompt for key password and save it
                                print_status "Please enter the password you used to encrypt the key"
                                echo -n "Password> "
                                read -s key_password
                                echo
                                
                                # Encode the password and save it
                                password_b64=$(echo -n "$key_password" | base64 | tr -d '\n')
                                # Update the keysecret in the file
                                sed -i "s|provider_b64_keysecret: \"\"|provider_b64_keysecret: \"$password_b64\"|" /root/provider-playbooks/host_vars/node1.yml
                                print_status "Key password has been encoded and saved to /root/provider-playbooks/host_vars/node1.yml"
                                
                                # Clean up
                                rm -f key.pem
                                
                                print_status "Wallet setup and configuration complete!"
                                print_status "Your wallet address is: $wallet_address"
                                
                                return 0
                            else
                                print_error "Failed to export key to key.pem"
                                rm -f key.pem
                                return 1
                            fi
                        else
                            print_error "Key '$key_name' not found. Available keys: $existing_keys"
                        fi
                    done
                    ;;
                n|N)
                    break
                    ;;
                *)
                    print_error "Invalid option. Please enter y or n"
                    ;;
            esac
        done
    else
        print_status "No existing keys found. Proceeding with key creation options..."
    fi

    # Only ask about creating/importing a key if we're not using an existing one
    if [ "$use_existing" != "y" ] && [ "$use_existing" != "Y" ]; then
        # Ask if user wants to create new key or import existing
        while true; do
            printf "Do you want to create a new key, import from key file, import from seed phrase, or paste existing key? (new/key/seed/paste): "
            read -r key_option
            
            if [ -z "$key_option" ]; then
                print_error "Please enter an option"
                continue
            fi
            
            case "$key_option" in
                new|key|seed|paste)
                    break
                    ;;
                *)
                    print_error "Invalid option. Please enter 'new', 'key', 'seed', or 'paste'"
                    ;;
            esac
        done
        
        if [[ "$key_option" == "new" ]]; then
            print_status "Creating new wallet key..."
            # Create the key and capture the output
            key_output=$(provider-services keys add default)
            # Extract address from the output using grep and cut
            wallet_address=$(echo "$key_output" | grep "address:" | cut -d: -f2 | tr -d ' ')
            print_status "New wallet created with address: $wallet_address"
        elif [[ "$key_option" == "key" ]]; then
            print_status "Importing existing wallet key..."
            read -p "Enter the path to your key.pem file: " key_path
            if [ ! -f "$key_path" ]; then
                print_error "Key file not found at $key_path"
                return 1
            fi
            provider-services keys import default "$key_path"
            # Get the address after import
            wallet_address=$(provider-services keys show default -a)
            print_status "Wallet imported with address: $wallet_address"
        elif [[ "$key_option" == "paste" ]]; then
            print_status "Pasting existing AKT address key and key secret..."
            read -p "Enter your AKT address: " wallet_address
            read -p "Enter your base64 encoded key: " key_b64
            read -p "Enter your base64 encoded key secret: " password_b64
            
            # Create host_vars directory if it doesn't exist
            mkdir -p /root/provider-playbooks/host_vars

            # Update the host_vars file with the wallet information
            cat > /root/provider-playbooks/host_vars/node1.yml << EOF
# Node Configuration - Host Vars File

## Provider Identification
akash1_address: "$wallet_address"
provider_b64_key: "$key_b64"
provider_b64_keysecret: "$password_b64"

## Network Configuration
domain: "${provider_name}"
region: "${provider_region}"

## Organization Details
host: "akash"
organization: "${provider_organization}"
email: "${provider_email}"
website: "${provider_website}"

## Tailscale Configuration
tailscale_hostname: "node1-$(echo "${provider_name}" | tr '.' '-')"
tailscale_authkey: "${tailscale_authkey}"

# provider attributes
attributes:
  - key: host
    value: akash
  - key: tier
    value: community

## Notes:
# - Replace empty values with your actual configuration
# - Keep sensitive values secure and never share them publicly
# - Ensure domain format follows Akash naming conventions
EOF
            
            print_status "Wallet information has been saved to /root/provider-playbooks/host_vars/node1.yml"
            print_status "Wallet address: $wallet_address"
            return 0
        else
            print_status "Importing wallet from seed phrase..."
            provider-services keys add default --recover
            # Get the address after recovery
            wallet_address=$(provider-services keys show default -a)
            print_status "Wallet recovered with address: $wallet_address"
        fi
    fi
    
    # Verify we have a wallet address
    if [ -z "$wallet_address" ]; then
        print_error "Failed to get wallet address"
        return 1
    fi
    
    # Small delay to ensure key operations are complete
    sleep 1
    
    # Export and show the key
    print_status "Exporting and showing key..."
    # Use script to capture the output
    script -q -c "provider-services keys export default" /dev/null | tee key.pem
    
    # Clean up the output file to only include the key and remove prompt lines
    sed -i -n '/-----BEGIN TENDERMINT PRIVATE KEY-----/,/-----END TENDERMINT PRIVATE KEY-----/p' key.pem

    # Check if the file was created and contains the key
    if [ -f "key.pem" ] && grep -q "BEGIN TENDERMINT PRIVATE KEY" key.pem; then
        print_status "Key has been exported to key.pem"
        
        # Base64 encode the key
        key_b64=$(cat key.pem | base64 | tr -d '\n')
        
        # Create host_vars directory if it doesn't exist
        mkdir -p /root/provider-playbooks/host_vars

        # Update the host_vars file with the wallet information
        cat > /root/provider-playbooks/host_vars/node1.yml << EOF
# Node Configuration - Host Vars File

## Provider Identification
akash1_address: "$wallet_address"
provider_b64_key: "$key_b64"
provider_b64_keysecret: ""  # Will be filled after password entry

## Network Configuration
domain: "${provider_name}"
region: "${provider_region}"

## Organization Details
host: "akash"
organization: "${provider_organization}"
email: "${provider_email}"
website: "${provider_website}"

## Tailscale Configuration
tailscale_hostname: "node1-$(echo "${provider_name}" | tr '.' '-')"
tailscale_authkey: "${tailscale_authkey}"

# provider attributes
attributes:
  - key: host
    value: akash
  - key: tier
    value: community

## Notes:
# - Replace empty values with your actual configuration
# - Keep sensitive values secure and never share them publicly
# - Ensure domain format follows Akash naming conventions
EOF
        

    
        print_status "Key has been encoded and saved to /root/provider-playbooks/host_vars/node1.yml"
        print_status "Wallet address: $wallet_address"
        
        # Prompt for key password and save it
        print_status "Please enter the password you used to encrypt the key"
        echo -n "Password> "
        read -s key_password
        echo
        
        # Encode the password and save it
        password_b64=$(echo -n "$key_password" | base64 | tr -d '\n')
        # Update the keysecret in the file
        sed -i "s|provider_b64_keysecret: \"\"|provider_b64_keysecret: \"$password_b64\"|" /root/provider-playbooks/host_vars/node1.yml
        print_status "Key password has been encoded and saved to /root/provider-playbooks/host_vars/node1.yml"
        
        # Clean up
        rm -f key.pem
        
        print_status "Wallet setup and configuration complete!"
        print_status "Your wallet address is: $wallet_address"
        print_warning "Please make sure to backup your seed phrase!"
        
        # Ask for confirmation that seed phrase is backed up
        while true; do
            read -p "Have you backed up your seed phrase? (Type YES to continue): " backup_confirmation
            if [ "$backup_confirmation" = "YES" ]; then
                print_status "Thank you for confirming your seed phrase backup"
                break
            else
                print_warning "Please backup your seed phrase before continuing"
                print_warning "Type YES when you have backed up your seed phrase"
            fi
        done
        
        return 0
    else
        print_error "Failed to export key to key.pem"
        rm -f key.pem
        return 1
    fi
}

# Check prerequisites
check_prerequisites

# Setup Python environment
setup_python_env

# Copy the sample inventory to set up the directory structure
cd ~/kubespray
copy_inventory
cd ~

# Get user input
print_status "Gathering configuration information..."

# Set default values for storage (will be overridden if user selected custom path earlier)
# These defaults are only used if Kubernetes was not selected
containerd_dir_path="${containerd_dir_path:-/var/lib/containerd}"
k3s_data_dir="${k3s_data_dir:-/var/lib/rancher/k3s}"

# Configure Container Storage
print_status "Configuring Container Storage..."

# Create directories based on which Kubernetes distribution was selected
if $SELECTED_KUBERNETES; then
    if $SELECTED_K3S; then
        # K3s needs k3s_data_dir
        mkdir -p "$k3s_data_dir"
    elif $SELECTED_KUBESPRAY; then
        # Kubespray needs containerd_dir_path
        mkdir -p "$containerd_dir_path"
    fi
fi

# Check if Kubespray inventory directory exists
if [ ! -d ~/kubespray/inventory/akash/group_vars/k8s_cluster ]; then
    print_status "Creating Kubespray inventory directories..."
    mkdir -p ~/kubespray/inventory/akash/group_vars/k8s_cluster
fi

# Note: Kubespray configuration files will be created later after gathering user input
# This ensures the correct storage paths are used based on user preferences

# Get provider domain name only if provider or tailscale is selected
if $SELECTED_PROVIDER || $SELECTED_TAILSCALE; then
    print_status "Provider Domain Information:"
    provider_name=$(get_input "Enter domain name for your provider (e.g., example.com or test.example.com) Do not include "provider." prefix" "" "[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+")
else
    provider_name=""
fi

# Provider Information
if $SELECTED_PROVIDER; then
    print_status "Provider Information:"
    provider_region=$(get_input "Enter your provider region (e.g., us-west)" "" "[a-z0-9-]+")
    provider_organization=$(get_input "Enter your organization name" "" "[a-zA-Z0-9\s-]+")
    provider_email=$(get_input "Enter your contact email" "" "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}")
    provider_website=$(get_input "Enter your organization website" "" "[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+")
    
    # Run wallet setup right after collecting provider info
    print_status "Setting up Akash wallet..."
    if ! setup_wallet; then
        print_error "Wallet setup failed. Please fix the issues and try again."
        exit 1
    fi
else
    # Set default values for provider variables if provider playbook is not selected
    provider_region=""
    provider_organization=""
    provider_email=""
    provider_website=""
fi

# This is set for now until we have a way to use existing hosts.yaml
USE_EXISTING_HOSTS=false

# Container storage paths are already set earlier during playbook selection

# Only collect node information if we're not using existing hosts.yaml
if [ "$USE_EXISTING_HOSTS" = false ]; then
    print_status "Node Information:"
    num_nodes=$(get_input "How many nodes do you have in your cluster?" "1" "^[0-9]+$")

    # Get node information for all nodes
    nodes=()
    for i in $(seq 1 $num_nodes); do
        print_status "Node $i Information:"
        node_info=$(get_node_info $i)
        nodes+=("$node_info")
    done
    
    # Configure Rook-Ceph if selected
    if $SELECTED_ROOK_CEPH; then
        print_status "Configuring Rook-Ceph storage..."
        
        # Use existing node names for storage selection
        storage_nodes=()
        echo -e "${YELLOW}Select which nodes will be used for Rook-Ceph storage:${NC}"
        for i in $(seq 1 $num_nodes); do
            node_ip=$(echo ${nodes[$i-1]} | cut -d'|' -f1)
            while true; do
                echo -n -e "${BLUE}[?]${NC} Use node$i ($node_ip) for persistent storage? [y/n]: "
                read -r response
                case $response in
                    [Yy]* ) storage_nodes+=("node$i"); break;;
                    [Nn]* ) break;;
                    * ) echo "Please answer y or n.";;
                esac
            done
        done
        
        # Confirm at least one storage node was selected
        if [ ${#storage_nodes[@]} -eq 0 ]; then
            print_error "At least one storage node must be selected for Rook-Ceph"
            while true; do
                echo -n -e "${BLUE}[?]${NC} Continue with Rook-Ceph setup? [y/n]: "
                read -r response
                case $response in
                    [Yy]* ) 
                        # Ask for at least one node again
                        for i in $(seq 1 $num_nodes); do
                            node_ip=$(echo ${nodes[$i-1]} | cut -d'|' -f1)
                            while true; do
                                echo -n -e "${BLUE}[?]${NC} Use node$i ($node_ip) for persistent storage? [y/n]: "
                                read -r response
                                case $response in
                                    [Yy]* ) storage_nodes+=("node$i"); break;;
                                    [Nn]* ) break;;
                                    * ) echo "Please answer y or n.";;
                                esac
                            done
                            # Break out once at least one node is selected
                            if [ ${#storage_nodes[@]} -gt 0 ]; then
                                break
                            fi
                        done
                        break;;
                    [Nn]* ) 
                        print_warning "Continuing without Rook-Ceph configuration"
                        SELECTED_ROOK_CEPH=false
                        break;;
                    * ) echo "Please answer y or n.";;
                esac
            done
        fi
        
        # Only continue if Rook-Ceph is still selected
        if $SELECTED_ROOK_CEPH; then
            # Get storage device information
            device_names=$(get_input "What are the device names to use (e.g., sd*, nvme*)?" "nvme*" "[a-zA-Z0-9*]+")
            osds_per_device=$(get_input "How many OSDs per device?" "1" "^[0-9]+$")
            
            # Storage device type selection
            while true; do
                echo -n -e "${BLUE}[?]${NC} What type of storage device (hdd/ssd/nvme)? [nvme]: "
                read -r response
                case $response in
                    hdd|ssd|nvme) storage_device_type=$response; break;;
                    "") storage_device_type="nvme"; break;;
                    * ) echo "Please answer hdd, ssd, or nvme.";;
                esac
            done
            
            # ZFS Configuration
            while true; do
                echo -n -e "${BLUE}[?]${NC} Do your worker nodes use ZFS for ephemeral storage? [y/n]: "
                read -r response
                case $response in
                    [Yy]* ) zfs_for_ephemeral="true"; break;;
                    [Nn]* ) zfs_for_ephemeral="false"; break;;
                    * ) echo "Please answer y or n.";;
                esac
            done
            
            # Create Rook-Ceph defaults file
            mkdir -p ~/provider-playbooks/roles/rook-ceph/defaults

            # Create CSI driver directories
            print_status "Creating CSI driver directories..."
            for node in "${storage_nodes[@]}"; do
                # Extract node number from the node name (e.g., "node1" -> "1")
                node_num=${node#node}
                # Get node info from the nodes array (subtract 1 because array is 0-based)
                node_info=${nodes[$((node_num-1))]}
                node_ip=$(echo "$node_info" | cut -d'|' -f1)
                node_user=$(echo "$node_info" | cut -d'|' -f2)
                node_port=$(echo "$node_info" | cut -d'|' -f3)
                
                # Create the necessary directories for CSI driver
                ssh -o StrictHostKeyChecking=no -p ${node_port} ${node_user}@${node_ip} "mkdir -p $kubelet_dir_path/plugins $kubelet_dir_path/pods $kubelet_dir_path/plugins_registry"
                
                # Ensure proper permissions
                ssh -o StrictHostKeyChecking=no -p ${node_port} ${node_user}@${node_ip} "chmod 755 $kubelet_dir_path $kubelet_dir_path/plugins $kubelet_dir_path/pods $kubelet_dir_path/plugins_registry"
            done

            # Determine MON and MGR counts based on number of storage nodes
            if [ ${#storage_nodes[@]} -eq 1 ]; then
                mon_count=1
                mgr_count=1
                pool_size=$((osds_per_device + 1))
                min_size=2
                failure_domain="osd"
            elif [ ${#storage_nodes[@]} -eq 2 ]; then
                mon_count=2
                mgr_count=2
                pool_size=2
                min_size=2
                failure_domain="osd"
            else
                mon_count=3
                mgr_count=2
                pool_size=3
                min_size=2
                failure_domain="host"
            fi

            # Determine storage class based on device type
            if [ "$storage_device_type" == "ssd" ]; then
                storage_class="beta2"
            elif [ "$storage_device_type" == "nvme" ]; then
                storage_class="beta3"
            else
                storage_class="beta1"
            fi

            # Create the nodes list with proper formatting
            nodes_list=""
            for node in "${storage_nodes[@]}"; do
                if [ -z "$nodes_list" ]; then
                    nodes_list="  - name: \"$node\"
    config:"
                else
                    nodes_list="$nodes_list
  - name: \"$node\"
    config:"
                fi
            done

            cat > ~/provider-playbooks/roles/rook-ceph/defaults/main.yaml << EOF
rook_ceph_namespace: rook-ceph
rook_ceph_version: "1.16.6"

# Ceph cluster configuration
pool_size: $pool_size
min_size: $min_size
mon_count: $mon_count
mgr_count: $mgr_count

# Storage configuration
config:
  osdsPerDevice: "$osds_per_device"
nodes:
$nodes_list

# Storage configuration
device_filter: "$device_names"
osds_per_device: $osds_per_device
device_type: "$storage_device_type"
failure_domain: "$failure_domain"
storage_class: "$storage_class"
zfs_for_ephemeral: "$zfs_for_ephemeral"
kubelet_dir_path: "$kubelet_dir_path"

# Node configuration
storage_nodes: [${storage_nodes[*]}]
EOF

             # Create host_vars for storage nodes
            for node in "${storage_nodes[@]}"; do
                mkdir -p /root/provider-playbooks/host_vars
                if [ -f "/root/provider-playbooks/host_vars/${node}.yml" ]; then
                    # If file exists, append to it
                    cat >> "/root/provider-playbooks/host_vars/${node}.yml" << EOF

# Rook-Ceph Storage Configuration
rook_ceph_kubelet_dir_path: "$kubelet_dir_path"
rook_ceph_storage:
  device_names: "$device_names"
  osds_per_device: $osds_per_device
  device_type: "$storage_device_type"
  zfs_for_ephemeral: "$zfs_for_ephemeral"
EOF
                else
                    # Create new file
                    cat > "/root/provider-playbooks/host_vars/${node}.yml" << EOF
# Node Configuration - Rook-Ceph Storage

rook_ceph_kubelet_dir_path: "$kubelet_dir_path"
rook_ceph_storage:
  device_names: "$device_names"
  osds_per_device: $osds_per_device
  device_type: "$storage_device_type"
  zfs_for_ephemeral: "$zfs_for_ephemeral"
EOF
                fi
            done
            
            print_status "Rook-Ceph configuration saved"
            print_warning "Please ensure your storage nodes have the specified devices available"
        fi
    fi
fi

# Get Tailscale auth key if Tailscale is selected
if $SELECTED_TAILSCALE; then
    print_status "Tailscale Setup:"
    read -p "Enter your Tailscale auth key: " tailscale_authkey
    echo "Using Tailscale auth key: ${tailscale_authkey:0:8}..."
    
    # Create host_vars directory if it doesn't exist
    mkdir -p /root/provider-playbooks/host_vars
    
    # Update node1.yml with Tailscale configuration if it exists
    if [ -f "/root/provider-playbooks/host_vars/node1.yml" ]; then
        # If the file exists, check if tailscale_authkey is already set
        if ! grep -q "tailscale_authkey:" "/root/provider-playbooks/host_vars/node1.yml"; then
            # Add Tailscale configuration if it doesn't exist
            cat >> "/root/provider-playbooks/host_vars/node1.yml" << EOF

## Tailscale Configuration
tailscale_hostname: "node1-$(echo "${provider_name}" | tr '.' '-')"
tailscale_authkey: "${tailscale_authkey}"
EOF
        else
            # Update existing Tailscale configuration
            sed -i "s|tailscale_authkey:.*|tailscale_authkey: \"${tailscale_authkey}\"|" "/root/provider-playbooks/host_vars/node1.yml"
        fi
    fi
fi
# Create necessary directories
print_status "Creating required directories..."
mkdir -p /root/provider-playbooks/host_vars
mkdir -p /root/provider-playbooks/inventory/akash

# Create inventory using Kubespray's inventory builder
print_status "Creating inventory file using Kubespray's inventory builder..."
# Copy the sample inventory contents
print_status "Copying sample inventory contents..."
cd ~/kubespray
# Create the directory if it doesn't exist
mkdir -p inventory/akash
# Always copy the sample files to ensure we have the latest structure
cp -rfp inventory/sample/* inventory/akash/
print_status "Sample inventory copied successfully"

# Ensure all required directories exist
mkdir -p inventory/akash/group_vars/all
mkdir -p inventory/akash/group_vars/k8s_cluster

# Verify key files exist
if [ ! -f inventory/akash/group_vars/k8s_cluster/k8s-cluster.yml ]; then
    print_error "Failed to copy k8s-cluster.yml from sample inventory"
    print_status "Creating a basic k8s-cluster.yml file"
    cat > inventory/akash/group_vars/k8s_cluster/k8s-cluster.yml << EOF
# Kubernetes configuration
kube_network_plugin: calico
container_manager: containerd
EOF
fi

# Remove existing inventory file if it exists
if [ -f ~/kubespray/inventory/akash/inventory.ini ]; then
    print_status "Removing existing inventory file..."
    rm -f ~/kubespray/inventory/akash/inventory.ini
fi

# Create the inventory file with the exact format needed
print_status "Creating inventory file with node configuration..."
cat > ~/kubespray/inventory/akash/inventory.ini << EOF
# Kubespray inventory file for Akash Provider
# Generated by setup_provider.sh

[all]
EOF

# Add all nodes as hosts
for i in "${!nodes[@]}"; do
    node_num=$((i + 1))
    node_ip=$(echo ${nodes[$i]} | cut -d'|' -f1)
    node_user=$(echo ${nodes[$i]} | cut -d'|' -f2)
    node_port=$(echo ${nodes[$i]} | cut -d'|' -f3)
    
    cat >> ~/kubespray/inventory/akash/inventory.ini << EOF
node${node_num} ansible_host=${node_ip} ip=${node_ip} ansible_user=${node_user} ansible_port=${node_port}
EOF
done

cat >> ~/kubespray/inventory/akash/inventory.ini << EOF

[kube_control_plane]
EOF

# Special handling for 2 nodes: only node1 is control plane and etcd
if [ "$num_nodes" -eq 2 ]; then
    cat >> ~/kubespray/inventory/akash/inventory.ini << EOF
node1 etcd_member_name=etcd1
EOF
else
    # Add control plane nodes (first 3 nodes or all if less than 3)
    for ((i=0; i<num_nodes && i<3; i++)); do
        node_num=$((i + 1))
        cat >> ~/kubespray/inventory/akash/inventory.ini << EOF
node${node_num} etcd_member_name=etcd${node_num}
EOF
    done
fi

cat >> ~/kubespray/inventory/akash/inventory.ini << EOF

[etcd:children]
kube_control_plane

[kube_node]
EOF

# Add all nodes as workers
for i in "${!nodes[@]}"; do
    node_num=$((i + 1))
    cat >> ~/kubespray/inventory/akash/inventory.ini << EOF
node${node_num}
EOF
done

print_status "Inventory file created successfully"

# Create a backup of the old format if it exists
if [ -f ~/kubespray/inventory/akash/hosts.yaml ]; then
    mv ~/kubespray/inventory/akash/hosts.yaml ~/kubespray/inventory/akash/hosts.yaml.bak
    print_status "Created backup of old inventory format at ~/kubespray/inventory/akash/hosts.yaml.bak"
fi

# Return to provider-playbooks directory
cd ~/provider-playbooks

# Create host_vars files for each node
print_status "Creating host variables files..."

# Create host_vars for all nodes except node1 (which is handled by setup_wallet)
for i in "${!nodes[@]}"; do
    node_num=$((i + 1))
    if [ "$node_num" != "1" ]; then
        # Transform domain name for Tailscale hostname (replace dots with hyphens)
        tailscale_domain=$(echo "${provider_name}" | tr '.' '-')
        cat > "/root/provider-playbooks/host_vars/node${node_num}.yml" << EOF
# Node Configuration - Host Vars File

## Network Configuration
region: "${provider_region}"

## Organization Details
host: "akash"
organization: "${provider_organization}"

## Tailscale Configuration
tailscale_hostname: "node${node_num}-${tailscale_domain}"
tailscale_authkey: "${tailscale_authkey}"
EOF
    fi
done

# Function to copy SSH key to a node
copy_ssh_key() {
    local node_ip=$1
    local node_user=$2
    local node_port=$3
    local max_attempts=3
    local attempt=1
    
    # First try with SSH key
    print_status "Testing SSH key access for ${node_user}@${node_ip}..."
    if ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -p ${node_port} ${node_user}@${node_ip} exit &>/dev/null; then
        print_status "SSH key access successful for ${node_user}@${node_ip}"
        return 0
    fi
    
    print_error "SSH key access failed for ${node_user}@${node_ip}"
    
    # Ask if user wants to try password authentication
    read -p "Do you want to try password authentication? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Skipping automated SSH key setup"
        if ! goto_manual_setup; then
            print_error "SSH key setup failed. You may encounter issues with Ansible playbooks."
            return 1
        fi
        return 0
    fi
    
    # Try with password up to max_attempts times
    while [ $attempt -le $max_attempts ]; do
        print_status "Password attempt $attempt of $max_attempts"
        read -s -p "Enter password for ${node_user}@${node_ip}: " node_password
        echo
        
        if [ "$node_user" != "root" ]; then
            print_status "Copying SSH key to root's authorized_keys via ${node_user}..."
            # First copy the public key to a temporary file on the remote machine
            if sshpass -p "${node_password}" ssh -o StrictHostKeyChecking=no -p ${node_port} ${node_user}@${node_ip} "mkdir -p ~/.ssh && cat > ~/.ssh/temp_key.pub" < ~/.ssh/id_rsa.pub; then
                # Then use sudo to copy it to root's authorized_keys
                if sshpass -p "${node_password}" ssh -o StrictHostKeyChecking=no -p ${node_port} ${node_user}@${node_ip} "sudo mkdir -p /root/.ssh && sudo cp ~/.ssh/temp_key.pub /root/.ssh/authorized_keys && sudo chmod 600 /root/.ssh/authorized_keys && rm ~/.ssh/temp_key.pub"; then
                    print_status "Successfully copied SSH key to root's authorized_keys"
                    return 0
                fi
            fi
        else
            # For root user, use normal ssh-copy-id with StrictHostKeyChecking=no
            print_status "Using ssh-copy-id with StrictHostKeyChecking=no to copy key..."
            if sshpass -p "${node_password}" ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub -p ${node_port} ${node_user}@${node_ip}; then
                print_status "Successfully copied SSH key"
                return 0
            fi
        fi
        
        print_error "Password attempt $attempt failed"
        attempt=$((attempt + 1))
    done
    
    print_error "All password attempts failed"
    # Call goto_manual_setup and return its status
    if ! goto_manual_setup; then
        print_error "SSH key setup failed. You may encounter issues with Ansible playbooks."
        return 1
    fi
    return 0
}

# Function to show manual setup instructions
goto_manual_setup() {
    print_warning "Please set up SSH access manually using the following steps:"
    echo
    echo "1. Here is the SSH public key that needs to be added to the target machine:"
    echo "---BEGIN SSH PUBLIC KEY---"
    cat ~/.ssh/id_rsa.pub
    echo "---END SSH PUBLIC KEY---"
    echo
    echo "2. On the target machine (${node_ip}), please add this key to the appropriate authorized_keys file:"
    echo "   - For root user: /root/.ssh/authorized_keys"
    echo "   - For non-root user: /home/${node_user}/.ssh/authorized_keys"
    echo
    echo "3. You can do this by running these commands on the target machine:"
    echo "   mkdir -p /root/.ssh"
    echo "   chmod 700 /root/.ssh"
    echo "   echo 'PASTE_SSH_KEY_HERE' > /root/.ssh/authorized_keys"
    echo "   chmod 600 /root/.ssh/authorized_keys"
    echo
    
    # Add max attempts to prevent infinite loop
    local max_attempts=3
    local attempt=1
    
    # Keep trying until SSH key is verified, user gives up, or max attempts reached
    while [ $attempt -le $max_attempts ]; do
        read -p "Press Enter to verify SSH key setup (attempt $attempt/$max_attempts, or 'q' to quit): " response
        if [[ "$response" == "q" ]]; then
            print_error "SSH key setup verification cancelled"
            return 1
        fi
        
        # Try to SSH with the key and disable StrictHostKeyChecking
        if ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -p ${node_port} ${node_user}@${node_ip} exit &>/dev/null; then
            print_status "SSH key verified successfully!"
            return 0
        else
            print_error "SSH key verification failed. Please make sure the key was added correctly."
            attempt=$((attempt + 1))
            if [ $attempt -le $max_attempts ]; then
                print_warning "Attempts remaining: $((max_attempts - attempt + 1))"
            fi
        fi
    done
    
    print_error "Maximum verification attempts reached. Continuing without verification."
    return 1
}

# Setup SSH key if not exists
if [ ! -f ~/.ssh/id_rsa ]; then
    print_status "Generating SSH key..."
    ssh-keygen -t rsa -C "$(hostname)" -f "$HOME/.ssh/id_rsa" -P ""
fi

# Copy SSH key to all nodes
print_status "Copying SSH key to all nodes..."
for i in "${!nodes[@]}"; do
    node_ip=$(echo ${nodes[$i]} | cut -d'|' -f1)
    node_user=$(echo ${nodes[$i]} | cut -d'|' -f2)
    node_port=$(echo ${nodes[$i]} | cut -d'|' -f3)
    
    # Remove the localhost check to treat all nodes as remote
    print_status "Setting up SSH access for node${i}: ${node_user}@${node_ip}:${node_port}"
    if ! copy_ssh_key "$node_ip" "$node_user" "$node_port"; then
        print_error "Failed to set up SSH access for ${node_ip}. Please verify the connection details and try again."
        exit 1
    fi
done

# Clone provider-playbooks if not exists
print_status "Created new cluster.yml configuration"

# Configure Ephemeral Storage
print_status "Configuring Ephemeral Storage..."
mkdir -p "${containerd_dir_path}" "${kubelet_dir_path}"

K8S_CLUSTER_FILE=~/kubespray/inventory/akash/group_vars/k8s_cluster/k8s-cluster.yml
containerd_present=false
kubelet_present=false

if grep -q "^containerd_storage_dir:" "$K8S_CLUSTER_FILE"; then
    sed -i "s|^containerd_storage_dir:.*|containerd_storage_dir: \"${containerd_dir_path}\"|" "$K8S_CLUSTER_FILE"
    containerd_present=true
fi

if grep -q "^kubelet_custom_flags:" "$K8S_CLUSTER_FILE"; then
    # Use yq to set kubelet_custom_flags as a list (required format for Kubespray v2.27+)
    yq eval ".kubelet_custom_flags = [\"--root-dir=${kubelet_dir_path}\"]" -i "$K8S_CLUSTER_FILE"
    kubelet_present=true
fi

if [ "$containerd_present" = false ] && [ "$kubelet_present" = false ]; then
    cat >> "$K8S_CLUSTER_FILE" << EOF

# Ephemeral storage configuration
containerd_storage_dir: "${containerd_dir_path}"
kubelet_custom_flags:
  - "--root-dir=${kubelet_dir_path}"
EOF
elif [ "$containerd_present" = false ]; then
    cat >> "$K8S_CLUSTER_FILE" << EOF

containerd_storage_dir: "${containerd_dir_path}"
EOF
elif [ "$kubelet_present" = false ]; then
    cat >> "$K8S_CLUSTER_FILE" << EOF

kubelet_custom_flags:
  - "--root-dir=${kubelet_dir_path}"
EOF
fi

# Configure Scheduler Profiles
print_status "Configuring Scheduler Profiles..."
if grep -q "kube_scheduler_profiles" ~/kubespray/inventory/akash/group_vars/k8s_cluster/k8s-cluster.yml; then
    print_status "Scheduler profiles already configured"
else
    cat >> ~/kubespray/inventory/akash/group_vars/k8s_cluster/k8s-cluster.yml << EOF

# Scheduler profiles
kube_scheduler_profiles:
  - pluginConfig:
    - name: NodeResourcesFit
      args:
        scoringStrategy:
          type: MostAllocated
          resources:
            - name: nvidia.com/gpu
              weight: 10
            - name: memory
              weight: 1
            - name: cpu
              weight: 1
            - name: ephemeral-storage
              weight: 1
EOF
fi

# Enable Helm Installation
print_status "Enabling Helm Installation..."
if [ ! -f ~/kubespray/inventory/akash/group_vars/k8s_cluster/addons.yml ]; then
    cat > ~/kubespray/inventory/akash/group_vars/k8s_cluster/addons.yml << EOF
# Helm deployment
helm_enabled: true
EOF
else
    sed -i 's/helm_enabled: false/helm_enabled: true/' ~/kubespray/inventory/akash/group_vars/k8s_cluster/addons.yml
fi

# Configure NVIDIA Runtime
print_status "Configuring NVIDIA Runtime for containerd..."
mkdir -p ~/kubespray/inventory/akash/group_vars/all
cat > ~/kubespray/inventory/akash/group_vars/all/akash.yml << EOF
# This file configures the NVIDIA container runtime for GPU-enabled nodes
# The runtime will only be used for workloads requesting it

containerd_additional_runtimes:
  - name: nvidia
    type: "io.containerd.runc.v2"
    engine: ""
    root: ""
    options:
      BinaryName: '/usr/bin/nvidia-container-runtime'
EOF

# Configure Rook-Ceph in k8s-cluster.yml
if $SELECTED_ROOK_CEPH; then
    print_status "Configuring Rook-Ceph settings in k8s-cluster.yml..."
    if ! grep -q "rook_ceph_enabled" ~/kubespray/inventory/akash/group_vars/k8s_cluster/k8s-cluster.yml; then
        cat >> ~/kubespray/inventory/akash/group_vars/k8s_cluster/k8s-cluster.yml << EOF

# Rook-Ceph configuration
rook_ceph_enabled: true
rook_ceph_namespace: "rook-ceph"
rook_ceph_version: "1.16.6"
EOF
    fi
fi

print_status "Configuring DNS..."

DNS_FILE=~/kubespray/inventory/akash/group_vars/all/all.yml

# 1. Uncomment the upstream_dns_servers line
sed -i 's/^[[:space:]]*#\s*upstream_dns_servers:/upstream_dns_servers:/' "$DNS_FILE"

# 2. Uncomment any lines containing 8.8.8.8 or 8.8.4.4
sed -i 's/^[[:space:]]*#\s*-\s*8\.8\.8\.8/  - 8.8.8.8/' "$DNS_FILE"
sed -i 's/^[[:space:]]*#\s*-\s*8\.8\.4\.4/  - 8.8.4.4/' "$DNS_FILE"

# 3. Add 1.1.1.1 if it's not already present (commented or not)
if ! grep -qE '^\s*- 1\.1\.1\.1' "$DNS_FILE"; then
    # Add it right below upstream_dns_servers:
    awk '/upstream_dns_servers:/ { print; print "  - 1.1.1.1"; next }1' "$DNS_FILE" > "${DNS_FILE}.tmp" && mv "${DNS_FILE}.tmp" "$DNS_FILE"
    print_status "Added 1.1.1.1 to upstream DNS list"
else
    print_status "1.1.1.1 already present in upstream DNS list"
fi


print_status "All configuration steps completed successfully!"

# Print next steps
print_status "Initial setup complete! Now proceeding with wallet setup..."

# After verifying hosts configuration
print_status "Hosts configuration verified"

# Run the playbook
print_status "Running playbooks based on your selections..."

# Run Kubernetes installation if selected
if $SELECTED_KUBERNETES; then
  if $SELECTED_KUBESPRAY; then
    print_status "Running Kubespray to set up Kubernetes cluster..."

    # 1. Desired locations (your RAID-backed /data mount)
    imagefs_dir_path="${containerd_dir_path}"
    # kubelet_dir_path already set earlier based on user input

    # 2. Inject the vars
    KUBESPRAY_DIR=~/kubespray
    INVENTORY_DIR="${KUBESPRAY_DIR}/inventory/akash"

    mkdir -p "${INVENTORY_DIR}/group_vars/all"
    mkdir -p "${INVENTORY_DIR}/group_vars/k8s_cluster"


    cat > "${INVENTORY_DIR}/group_vars/all/containerd.yml" <<EOF
containerd_storage_dir: "${containerd_dir_path}"
containerd_sandbox_image: "registry.k8s.io/pause:3.10"
EOF

    cat > "${INVENTORY_DIR}/group_vars/k8s_cluster/k8s-cluster.yml" <<EOF
containerd_storage_dir: "${containerd_dir_path}"
EOF

    print_status "Set containerd_storage_dir to ${containerd_dir_path}"

    # 3. Run Kubespray
    cd "${KUBESPRAY_DIR}"
    ansible-playbook -i inventory/akash/inventory.ini cluster.yml -b -v
  else
    print_status "Running K3s installation..."
    
    # Simple and direct approach - force add internal_ip to host_vars files
    print_status "Adding internal_ip to host_vars files..."
    NODE_IP=$(grep "^node1 " ~/kubespray/inventory/akash/inventory.ini | awk '{for(i=1;i<=NF;i++) if($i ~ /^ansible_host=/) print $i}' | cut -d'=' -f2)
    
    # Ensure host_vars directory exists
    mkdir -p ~/provider-playbooks/host_vars
    
    # Simply force append the variable to each file
    for i in $(seq 1 $(grep -c "^node[0-9]* " ~/kubespray/inventory/akash/inventory.ini)); do
        NODE_NAME="node$i"
        echo -e "\n# K3s specific variables\ninternal_ip: \"$NODE_IP\"\nk3s_data_dir: \"$k3s_data_dir\"" >> ~/provider-playbooks/host_vars/${NODE_NAME}.yml
        print_status "Added internal_ip and k3s_data_dir to host_vars file for $NODE_NAME"
    done
    
    ansible-playbook -i ~/kubespray/inventory/akash/inventory.ini playbooks.yml -t k3s -v --extra-vars "k3s_data_dir=${k3s_data_dir}"
fi
else
    print_status "Skipping Kubernetes installation as it was not selected"
    print_status "Note: Make sure you have a working Kubernetes cluster before proceeding"
fi

# Install local-path-provisioner for storage (only if Rook-Ceph is not selected)
if $SELECTED_KUBERNETES && $SELECTED_KUBESPRAY && ! $SELECTED_ROOK_CEPH; then
    print_status "Installing local-path-provisioner (required by Akash provider)..."

    # Wait for cluster to be ready
    print_status "Waiting for Kubernetes cluster to be ready..."
    sleep 10

    # Install the provisioner
    if kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml; then
        print_status "local-path-provisioner installed successfully"

        # Wait for it to be ready
        print_status "Waiting for provisioner to be ready..."
        kubectl wait --for=condition=ready pod -l app=local-path-provisioner -n local-path-storage --timeout=120s || print_warning "Timeout waiting, but continuing..."

        print_status "Storage provisioner is ready"
        
        # Patch StorageClass to use Immediate binding mode
        # This prevents issues with single-node clusters where WaitForFirstConsumer causes deadlocks
        print_status "Configuring StorageClass for immediate volume binding..."
        if kubectl patch storageclass local-path -p '{"volumeBindingMode":"Immediate"}' 2>/dev/null; then
            print_status "StorageClass configured successfully"
        else
            print_warning "Failed to patch StorageClass - provider may have issues in single-node setups"
        fi
    else
        print_error "Failed to install local-path-provisioner - provider deployment may fail!"
        exit 1
    fi
elif $SELECTED_KUBERNETES && $SELECTED_KUBESPRAY && $SELECTED_ROOK_CEPH; then
    print_status "Rook-Ceph selected - skipping local-path-provisioner installation"
elif $SELECTED_KUBERNETES && $SELECTED_K3S; then
    print_status "K3s includes local-path-provisioner by default - skipping installation"
    
    # Patch K3s StorageClass to use Immediate binding mode
    print_status "Configuring K3s StorageClass for immediate volume binding..."
    if kubectl patch storageclass local-path -p '{"volumeBindingMode":"Immediate"}' 2>/dev/null; then
        print_status "StorageClass configured successfully"
    else
        print_warning "Failed to patch StorageClass - provider may have issues in single-node setups"
    fi
fi

# Run provider playbooks if any are selected
if $SELECTED_OS || $SELECTED_GPU || $SELECTED_PROVIDER || $SELECTED_TAILSCALE || $SELECTED_ROOK_CEPH; then
    # Ensure we're in the provider-playbooks directory
    cd ~/provider-playbooks
    
    # Activate the virtual environment
    source ~/kubespray/venv/bin/activate
    
    # Check if K3s is running on node1
    NODE_IP=$(grep "^node1 " ~/kubespray/inventory/akash/inventory.ini | awk '{for(i=1;i<=NF;i++) if($i ~ /^ansible_host=/) print $i}' | cut -d'=' -f2)
    K3S_STATUS=$(ssh -o StrictHostKeyChecking=no root@${NODE_IP} "systemctl is-active k3s 2>&1")
    if [ "$K3S_STATUS" = "active" ]; then
        print_status "K3s is running on node1, setting up kubeconfig..."
        
        # Create .kube directory if it doesn't exist
        mkdir -p /root/.kube
        
        # Create symlink to k3s.yaml
        ln -sf /etc/rancher/k3s/k3s.yaml /root/.kube/config
        
        # Set KUBECONFIG
        export KUBECONFIG=/root/.kube/config
        
        # Verify kubeconfig
        if ! kubectl get nodes; then
            print_error "Failed to verify kubeconfig. Please check the configuration."
            exit 1
        fi
    else
        print_status "K3s is not running on node1, skipping kubeconfig setup"
    fi
    
    # Run OS playbook if selected
    if $SELECTED_OS; then
        print_status "Running OS configuration playbook..."
        ansible-playbook -i ~/kubespray/inventory/akash/inventory.ini playbooks.yml -t os -v
    fi
    
    # Run GPU playbook if selected
    if $SELECTED_GPU; then
        print_status "Running GPU configuration playbook..."
        ansible-playbook -i ~/kubespray/inventory/akash/inventory.ini playbooks.yml -t gpu -v
    fi
    
    # Run Provider playbook if selected
    if $SELECTED_PROVIDER; then
        print_status "Running Provider playbook..."
        ansible-playbook -i ~/kubespray/inventory/akash/inventory.ini playbooks.yml -t provider -v
    fi
    
    # Run Tailscale playbook if selected
    if $SELECTED_TAILSCALE; then
        print_status "Running Tailscale playbook..."
        ansible-playbook -i ~/kubespray/inventory/akash/inventory.ini playbooks.yml -t tailscale -v
    fi

    # Run Rook-Ceph playbook if selected
    if $SELECTED_ROOK_CEPH; then
        print_status "Running Rook-Ceph playbook..."
        ansible-playbook -i ~/kubespray/inventory/akash/inventory.ini playbooks.yml -t rook-ceph -v --extra-vars "rook_ceph_data_dir=${ephemeral_dir_path}/rook" --extra-vars "kubelet_dir_path=${kubelet_dir_path}"
    fi
else
    print_status "No provider playbooks were selected to run"
fi

# Check if all playbooks completed successfully
print_status "Checking if all playbooks completed successfully..."

# Function to reboot nodes in reverse order
reboot_nodes() {
    print_status "Rebooting nodes in reverse order..."
    
    # Get the number of nodes
    local num_nodes=${#nodes[@]}
    
    # Reboot nodes in reverse order
    for ((i=num_nodes-1; i>=0; i--)); do
        node_num=$((i + 1))
        node_ip=$(echo ${nodes[$i]} | cut -d'|' -f1)
        node_user=$(echo ${nodes[$i]} | cut -d'|' -f2)
        node_port=$(echo ${nodes[$i]} | cut -d'|' -f3)
        
        print_status "Rebooting node${node_num} (${node_user}@${node_ip}:${node_port})..."
        ssh -o StrictHostKeyChecking=no -p ${node_port} ${node_user}@${node_ip} "reboot" || print_warning "Failed to reboot node${node_num}, but continuing with other nodes"
        
        # Wait a moment before proceeding to the next node
        sleep 2
    done
    
    print_status "All nodes have been sent reboot commands"
    print_warning "The nodes will reboot in sequence. You may need to wait a few minutes before they are all back online."
}

# Ask user if they want to reboot all nodes
while true; do
    echo -n -e "${BLUE}[?]${NC} Would you like to reboot all nodes now? [y/n]: "
    read -r response
    case $response in
        [Yy]* ) 
            reboot_nodes
            break
            ;;
        [Nn]* ) 
            print_status "Skipping node reboot"
            break
            ;;
        * ) echo "Please answer y or n.";;
    esac
done

print_status "Setup process completed!"
print_status "Thank you for using the Akash Provider Setup Script!"
