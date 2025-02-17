#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Exit script on any error
set -e

# Function to print error and exit
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Function to install required dependencies
install_dependencies() {
    echo -e "${GREEN}Installing required dependencies...${NC}"
    
    # Update package list
    apt-get update
    
    # Install required packages
    apt-get install -y \
        build-essential \
        pkg-config \
        libssl-dev \
        git-all \
        protobuf-compiler \
        cargo \
        curl \
        screen

    # Install Rust
    if ! command -v rustc &> /dev/null; then
        echo -e "${YELLOW}Installing Rust...${NC}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
    fi
    
    echo -e "${GREEN}Dependencies installed successfully${NC}"
}

# Function to setup the project
setup_project() {
    local prover_id=$1
    local project_dir="nexus-prover"
    
    echo -e "${GREEN}Setting up project directory...${NC}"
    
    # Create project directory and configuration
    mkdir -p "$HOME/.nexus"
    echo "$prover_id" > "$HOME/.nexus/prover-id"
    
    # Create project directory if it doesn't exist
    mkdir -p "$project_dir"
    
    # Create screen startup script
    cat > "$project_dir/start-prover.sh" << 'EOF'
#!/bin/bash
curl https://cli.nexus.xyz/ | sh
EOF
    
    chmod +x "$project_dir/start-prover.sh"
    
    echo -e "${GREEN}Project files created successfully${NC}"
}

# Function to start the prover in screen
start_prover() {
    echo -e "${GREEN}Starting Nexus Prover in screen...${NC}"
    
    # Check if screen session already exists
    if screen -list | grep -q "nexus-prover"; then
        error_exit "Nexus Prover screen session already exists. Use 'screen -r nexus-prover' to attach."
    fi
    
    # Start new screen session
    screen -dmS nexus-prover ./nexus-prover/start-prover.sh
    
    echo -e "${GREEN}Nexus Prover started successfully in screen session${NC}"
}

# Main script execution
echo -e "${GREEN}Starting Nexus Prover setup...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    error_exit "Please run as root (use sudo)"
fi

# Install dependencies
install_dependencies

# Get Prover ID
echo -e "${GREEN}Please enter your Nexus Prover ID:${NC}"
read -r PROVER_ID

if [ -z "$PROVER_ID" ]; then
    error_exit "Prover ID cannot be empty"
fi

# Setup project
setup_project "$PROVER_ID"

# Start prover
start_prover

# Show helpful commands
echo -e "\n${GREEN}Helpful commands:${NC}"
echo -e "Attach to prover: ${YELLOW}screen -r nexus-prover${NC}"
echo -e "Detach from screen: ${YELLOW}Ctrl+A, then press D${NC}"
echo -e "Stop prover: ${YELLOW}screen -X -S nexus-prover quit${NC}"
echo -e "List screen sessions: ${YELLOW}screen -ls${NC}"

# Show initial screen session
echo -e "\n${GREEN}Attaching to screen session (Ctrl+A, D to detach):${NC}"
screen -r nexus-prover