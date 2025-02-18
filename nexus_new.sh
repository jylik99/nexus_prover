#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Installing required packages
echo -e "${GREEN}Installing required packages...${NC}"
apt-get update
apt-get install -y pkg-config libssl-dev build-essential curl git expect

# Creating nexus directory if it doesn't exist
mkdir -p /root/.nexus

# Request PROVER_ID
echo -e "${GREEN}Prover ID is required for node operation${NC}"
read -p "Enter your Prover ID: " PROVER_ID

if [ -z "$PROVER_ID" ]; then
    echo -e "${YELLOW}Prover ID cannot be empty${NC}"
    exit 1
fi

# Save PROVER_ID
echo "$PROVER_ID" > /root/.nexus/prover-id
echo -e "${GREEN}Prover ID saved${NC}"

# Install Rust and update environment
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

echo -e "\n${GREEN}Starting Nexus Prover...${NC}"

# Try with expect
expect -c '
spawn bash -c "curl https://cli.nexus.xyz/ | sh"
expect "Terms of Use"
send "Y\r"
expect "continue?"
send "Y\r"
expect eof
'