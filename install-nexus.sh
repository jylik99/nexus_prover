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

# Function to check system requirements
check_requirements() {
    echo -e "${GREEN}Checking system requirements...${NC}"
    
    # Check CPU cores
    CPU_CORES=$(nproc)
    if [ "$CPU_CORES" -lt 2 ]; then
        error_exit "Minimum 2 CPU cores required. Found: $CPU_CORES cores"
    fi
    
    # Check RAM (in MB)
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_RAM" -lt 6144 ]; then
        error_exit "Minimum 6GB RAM required. Found: $((TOTAL_RAM/1024))GB"
    fi
    
    # Check available disk space (in GB)
    FREE_DISK=$(df -BG --output=avail "$(pwd)" | tail -n 1 | tr -d 'G')
    if [ "$FREE_DISK" -lt 50 ]; then
        error_exit "Minimum 50GB free disk space required. Found: ${FREE_DISK}GB"
    fi
    
    echo -e "${GREEN}System requirements met:${NC}"
    echo -e "CPU Cores: ${CPU_CORES}"
    echo -e "RAM: $((TOTAL_RAM/1024))GB"
    echo -e "Available Disk Space: ${FREE_DISK}GB"
}

# Function to check and install Docker
install_docker() {
    echo -e "${GREEN}Checking Docker installation...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker not found. Installing Docker...${NC}"
        
        # Remove old versions if exist
        apt-get remove -y docker docker.io containerd runc || true
        
        # Install prerequisites
        apt-get update
        apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # Add Docker's official GPG key
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        # Set up repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
            tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Start and enable Docker service
        systemctl start docker
        systemctl enable docker
        
        echo -e "${GREEN}Docker installed successfully${NC}"
    else
        echo -e "${GREEN}Docker already installed${NC}"
    fi
    
    # Verify Docker installation
    docker --version || error_exit "Docker installation failed"
}

# Function to create project directory and files
setup_project() {
    local prover_id=$1
    local project_dir="nexus-prover"
    
    echo -e "${GREEN}Setting up project directory...${NC}"
    
    # Create project directory
    mkdir -p "$project_dir"
    
    # Create Dockerfile
    cat > "$project_dir/Dockerfile" << 'EOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies in one layer to reduce image size
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
    build-essential \
    pkg-config \
    libssl-dev \
    git-all \
    protobuf-compiler \
    cargo \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Rust in one layer
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . $HOME/.cargo/env && \
    rustup update

ENV PATH="/root/.cargo/bin:${PATH}"

# Create Nexus directory and entry point script
RUN mkdir -p /root/.nexus && \
    echo '#!/bin/bash\n\
if [ -n "$PROVER_ID" ]; then\n\
    echo "$PROVER_ID" > /root/.nexus/prover-id\n\
fi\n\
curl https://cli.nexus.xyz/ | sh\n\
tail -f /dev/null' > /entrypoint.sh && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
EOF

    # Create docker-compose.yml without resource limits
    cat > "$project_dir/docker-compose.yml" << EOF
name: nexus

services:
  prover:
    build: .
    container_name: nexus-prover
    environment:
      - PROVER_ID=$prover_id
    volumes:
      - nexus-data:/root/.nexus
    restart: unless-stopped
    logging:
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  nexus-data:
    name: nexus-data
EOF

    echo -e "${GREEN}Project files created successfully${NC}"
}

# Function to start the prover
start_prover() {
    echo -e "${GREEN}Starting Nexus Prover...${NC}"
    cd nexus-prover
    
    # Build and start containers
    echo -e "${YELLOW}Building Docker image (this may take 15-20 minutes)...${NC}"
    docker compose up -d --build
    
    # Check if container is running
    if [ "$(docker ps -q -f name=nexus-prover)" ]; then
        echo -e "${GREEN}Nexus Prover started successfully${NC}"
    else
        error_exit "Failed to start Nexus Prover container"
    fi
}

# Main script execution
echo -e "${GREEN}Starting Nexus Prover setup...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    error_exit "Please run as root (use sudo)"
fi

# Check system requirements
check_requirements

# Install Docker
install_docker

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

# Show some helpful commands
echo -e "\n${GREEN}Helpful commands:${NC}"
echo -e "View logs: ${YELLOW}docker compose logs -f${NC}"
echo -e "Stop prover: ${YELLOW}docker compose down${NC}"
echo -e "Restart prover: ${YELLOW}docker compose restart${NC}"
echo -e "Check status: ${YELLOW}docker ps${NC}"

# Show logs
echo -e "\n${GREEN}Showing logs (Ctrl+C to exit log view):${NC}"
docker compose logs -f