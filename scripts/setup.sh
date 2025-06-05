#!/bin/bash

# Setup script for Google Keep SOAP API Clone
# This script installs dependencies and sets up the environment

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Google Keep SOAP API Clone Setup ===${NC}"

# Check if Node.js is installed
echo -e "${YELLOW}Checking for Node.js...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js is not installed. Please install Node.js v14 or later.${NC}"
    echo -e "Visit https://nodejs.org/ to download and install Node.js."
    exit 1
fi

NODE_VERSION=$(node -v | cut -d 'v' -f 2)
NODE_MAJOR=$(echo $NODE_VERSION | cut -d '.' -f 1)

if [ $NODE_MAJOR -lt 14 ]; then
    echo -e "${RED}Node.js version $NODE_VERSION is too old. Please install Node.js v14 or later.${NC}"
    exit 1
fi

echo -e "${GREEN}Node.js v$NODE_VERSION is installed.${NC}"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
npm install
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to install dependencies.${NC}"
    exit 1
fi
echo -e "${GREEN}Dependencies installed successfully.${NC}"

# Create .env file if it doesn't exist
echo -e "${YELLOW}Setting up environment variables...${NC}"
if [ ! -f .env ]; then
    cp .env.example .env
    # Generate a random secret key
    SECRET_KEY=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
    # Replace the SECRET_KEY placeholder with the generated key
    sed -i.bak "s/SECRET_KEY=/SECRET_KEY=$SECRET_KEY/" .env
    rm -f .env.bak
    echo -e "${GREEN}Created .env file with a secure random secret key.${NC}"
else
    echo -e "${YELLOW}Using existing .env file.${NC}"
fi

# Create data directory if it doesn't exist
echo -e "${YELLOW}Setting up data directory...${NC}"
mkdir -p data
echo -e "${GREEN}Data directory is ready.${NC}"

# Make test scripts executable
echo -e "${YELLOW}Making scripts executable...${NC}"
chmod +x scripts/*.sh
chmod +x tests/*.sh
echo -e "${GREEN}Scripts are now executable.${NC}"

echo -e "${BLUE}=== Setup Complete ===${NC}"
echo -e "${GREEN}You can now run the servers with:${NC}"
echo -e "  ${YELLOW}bash scripts/run.sh${NC} - To run the SOAP server"
echo -e "  ${YELLOW}REST_PORT=3000 node src/rest-server.js${NC} - To run the REST server"
echo -e "${GREEN}To run comparison tests:${NC}"
echo -e "  ${YELLOW}bash scripts/run-comparison-tests.sh${NC}"
