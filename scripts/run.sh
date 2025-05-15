#!/bin/bash

# Run script for Google Keep SOAP API
# This script starts the SOAP server

# Set variables
PORT=8001
NODE_ENV=development

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env file exists, if not create it with default values
if [ ! -f .env ]; then
  echo -e "${YELLOW}Creating .env file with default values...${NC}"
  echo "PORT=$PORT" > .env
  echo "NODE_ENV=$NODE_ENV" >> .env
  echo "SECRET_KEY=your_secret_key_here" >> .env
  echo -e "${GREEN}Created .env file. Please update SECRET_KEY for production use.${NC}"
fi

# Check if node_modules directory exists, if not run npm install
if [ ! -d "node_modules" ]; then
  echo -e "${YELLOW}Installing dependencies...${NC}"
  npm install
  echo -e "${GREEN}Dependencies installed.${NC}"
fi

# Start the SOAP server
echo -e "${YELLOW}Starting SOAP server on port $PORT...${NC}"
node src/simple-soap-server.js
