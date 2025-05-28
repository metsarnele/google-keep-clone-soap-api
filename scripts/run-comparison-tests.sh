#!/bin/bash

# Run both REST and SOAP servers and then run comparison tests

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Kill any existing server processes
echo -e "${YELLOW}Stopping any running servers...${NC}"
pkill -f "node src/rest-server.js" || true
pkill -f "node src/simple-soap-server.js" || true
sleep 2

# Start REST server
echo -e "${YELLOW}Starting REST server on port 3000...${NC}"
REST_PORT=3000 node src/rest-server.js &
REST_PID=$!
sleep 3

# Start SOAP server
echo -e "${YELLOW}Starting SOAP server on port 8001...${NC}"
PORT=8001 node src/simple-soap-server.js &
SOAP_PID=$!
sleep 3

# Check if servers are running
echo -e "${YELLOW}Checking if servers are running...${NC}"
if ! curl -s http://localhost:3000 > /dev/null; then
  echo -e "${RED}Error: REST server failed to start${NC}"
  kill $REST_PID $SOAP_PID 2>/dev/null || true
  exit 1
fi

if ! curl -s http://localhost:8001/soap > /dev/null; then
  echo -e "${RED}Error: SOAP server failed to start${NC}"
  kill $REST_PID $SOAP_PID 2>/dev/null || true
  exit 1
fi

echo -e "${GREEN}Both servers are running!${NC}"

# Make test script executable
chmod +x tests/compare-apis.sh

# Run comparison tests
echo -e "${YELLOW}Running comparison tests...${NC}"
tests/compare-apis.sh
TEST_RESULT=$?

# Stop servers
echo -e "${YELLOW}Stopping servers...${NC}"
kill $REST_PID $SOAP_PID 2>/dev/null || true

# Return test result
if [ $TEST_RESULT -eq 0 ]; then
  echo -e "${GREEN}Tests completed successfully!${NC}"
  exit 0
else
  echo -e "${RED}Tests failed!${NC}"
  exit 1
fi
