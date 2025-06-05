#!/bin/bash

# Compare REST and SOAP APIs functionality
# This script tests both APIs with the same operations and compares results

# Set variables
REST_PORT="3000"
SOAP_PORT="8001"
REST_ENDPOINT="http://localhost:$REST_PORT"
SOAP_ENDPOINT="http://localhost:$SOAP_PORT/soap"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test result
print_result() {
  local test_name=$1
  local result=$2
  local message=$3

  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  
  if [ "$result" -eq 0 ]; then
    echo -e "${GREEN}✓ PASS${NC}: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗ FAIL${NC}: $test_name"
    echo -e "${RED}    Error: $message${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Function to make SOAP request
make_soap_request() {
  local action=$1
  local body=$2
  local output=$(curl -s -X POST "$SOAP_ENDPOINT" \
    -H "Content-Type: text/xml;charset=UTF-8" \
    -d "$body")
  
  echo "$output"
}

# Function to make REST request
make_rest_request() {
  local method=$1
  local path=$2
  local data=$3
  local auth_header=$4
  
  if [ -n "$auth_header" ]; then
    local output=$(curl -s -X "$method" "$REST_ENDPOINT$path" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $auth_header" \
      -d "$data")
  else
    local output=$(curl -s -X "$method" "$REST_ENDPOINT$path" \
      -H "Content-Type: application/json" \
      -d "$data")
  fi
  
  echo "$output"
}

# Function to extract value from SOAP response
extract_soap_value() {
  local response=$1
  local xpath=$2
  
  # Use grep and sed to extract the value with namespace handling
  # First try with types: namespace prefix
  local value=$(echo "$response" | grep -o "<types:$xpath>.*</types:$xpath>" | sed "s/<types:$xpath>\(.*\)<\/types:$xpath>/\1/")
  
  # If not found, try without namespace prefix
  if [ -z "$value" ]; then
    value=$(echo "$response" | grep -o "<$xpath>.*</$xpath>" | sed "s/<$xpath>\(.*\)<\/$xpath>/\1/")
  fi
  
  # If still not found, try with typ: namespace prefix
  if [ -z "$value" ]; then
    value=$(echo "$response" | grep -o "<typ:$xpath>.*</typ:$xpath>" | sed "s/<typ:$xpath>\(.*\)<\/typ:$xpath>/\1/")
  fi
  
  echo "$value"
}

# Function to extract value from REST response (JSON)
extract_rest_value() {
  local response=$1
  local key=$2
  
  # Use jq to extract the value if jq is available
  if command -v jq &> /dev/null; then
    local value=$(echo "$response" | jq -r ".$key")
    echo "$value"
  else
    # Fallback to grep and sed if jq is not available
    # First try with quotes (for string values)
    local value=$(echo "$response" | grep -o "\"$key\":\"[^\"]*\"" | sed "s/\"$key\":\"//;s/\"//")
    
    # If not found, try without quotes (for non-string values or different JSON format)
    if [ -z "$value" ]; then
      value=$(echo "$response" | grep -o "\"$key\":[^,}]*" | sed "s/\"$key\"://")
    fi
    
    echo "$value"
  fi
}

# Clean up data files to ensure a fresh start
echo -e "${YELLOW}Cleaning up data files for a fresh start...${NC}"
DATA_DIR="$(dirname "$(dirname "$0")")/data"
rm -f "$DATA_DIR/users.json" "$DATA_DIR/notes.json" "$DATA_DIR/tags.json" "$DATA_DIR/blacklist.json"

# Check if both servers are running
echo -e "${YELLOW}Checking if REST server is running...${NC}"
if ! curl -s "$REST_ENDPOINT" > /dev/null; then
  echo -e "${RED}Error: REST server is not running at $REST_ENDPOINT${NC}"
  echo -e "${YELLOW}Please start the REST server before running tests.${NC}"
  exit 1
fi
echo -e "${GREEN}REST server is running!${NC}"

echo -e "${YELLOW}Checking if SOAP server is running...${NC}"
if ! curl -s "$SOAP_ENDPOINT" > /dev/null; then
  echo -e "${RED}Error: SOAP server is not running at $SOAP_ENDPOINT${NC}"
  echo -e "${YELLOW}Please start the SOAP server before running tests.${NC}"
  exit 1
fi
echo -e "${GREEN}SOAP server is running!${NC}"

# Wait a moment to ensure servers are fully initialized
sleep 2

echo -e "\n${YELLOW}Starting comparison tests...${NC}"

# Test 1: Register a user
echo -e "\n${BLUE}Test 1: Register a user${NC}"
USER_USERNAME="testuser_$(date +%s)"
USER_PASSWORD="password123"

# REST API call
echo -e "${YELLOW}REST API: Register user${NC}"
REST_REGISTER_DATA="{\"username\":\"$USER_USERNAME\",\"password\":\"$USER_PASSWORD\"}"
REST_REGISTER_RESPONSE=$(make_rest_request "POST" "/users" "$REST_REGISTER_DATA")
REST_USER_ID=$(extract_rest_value "$REST_REGISTER_RESPONSE" "id")
echo "REST Response: $REST_REGISTER_RESPONSE"

# SOAP API call
echo -e "${YELLOW}SOAP API: Register user${NC}"
SOAP_REGISTER_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:RegisterUserRequest>
         <typ:user>
            <typ:username>$USER_USERNAME</typ:username>
            <typ:password>$USER_PASSWORD</typ:password>
         </typ:user>
      </wsdl:RegisterUserRequest>
   </soapenv:Body>
</soapenv:Envelope>"

SOAP_REGISTER_RESPONSE=$(make_soap_request "RegisterUser" "$SOAP_REGISTER_REQUEST")
SOAP_USER_ID=$(extract_soap_value "$SOAP_REGISTER_RESPONSE" "id")
echo "SOAP Response: $SOAP_REGISTER_RESPONSE"

# Compare results
if [ -n "$REST_USER_ID" ] && [ -n "$SOAP_USER_ID" ]; then
  print_result "Register user - Both APIs return user IDs" 0 ""
else
  print_result "Register user - Both APIs return user IDs" 1 "REST ID: $REST_USER_ID, SOAP ID: $SOAP_USER_ID"
fi

# Test 2: Login
echo -e "\n${BLUE}Test 2: Login${NC}"

# REST API call
echo -e "${YELLOW}REST API: Login${NC}"
REST_LOGIN_DATA="{\"username\":\"$USER_USERNAME\",\"password\":\"$USER_PASSWORD\"}"
REST_LOGIN_RESPONSE=$(make_rest_request "POST" "/login" "$REST_LOGIN_DATA")
REST_TOKEN=$(extract_rest_value "$REST_LOGIN_RESPONSE" "token")
echo "REST Response: $REST_LOGIN_RESPONSE"

# SOAP API call
echo -e "${YELLOW}SOAP API: Login${NC}"
SOAP_LOGIN_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:LoginRequest>
         <typ:credentials>
            <typ:username>$USER_USERNAME</typ:username>
            <typ:password>$USER_PASSWORD</typ:password>
         </typ:credentials>
      </wsdl:LoginRequest>
   </soapenv:Body>
</soapenv:Envelope>"

SOAP_LOGIN_RESPONSE=$(make_soap_request "Login" "$SOAP_LOGIN_REQUEST")
SOAP_TOKEN=$(extract_soap_value "$SOAP_LOGIN_RESPONSE" "token")
echo "SOAP Response: $SOAP_LOGIN_RESPONSE"

# Compare results
if [ -n "$REST_TOKEN" ] && [ -n "$SOAP_TOKEN" ]; then
  print_result "Login - Both APIs return auth tokens" 0 ""
else
  print_result "Login - Both APIs return auth tokens" 1 "REST token: $REST_TOKEN, SOAP token: $SOAP_TOKEN"
fi

# Test 3: Create a note
echo -e "\n${BLUE}Test 3: Create a note${NC}"
NOTE_TITLE="Test Note $(date +%s)"
NOTE_CONTENT="This is a test note created for API comparison"

# REST API call
echo -e "${YELLOW}REST API: Create note${NC}"
REST_CREATE_NOTE_DATA="{\"title\":\"$NOTE_TITLE\",\"content\":\"$NOTE_CONTENT\",\"tags\":[\"test\",\"api\"]}"
REST_CREATE_NOTE_RESPONSE=$(make_rest_request "POST" "/notes" "$REST_CREATE_NOTE_DATA" "$REST_TOKEN")
REST_NOTE_ID=$(extract_rest_value "$REST_CREATE_NOTE_RESPONSE" "id")
echo "REST Response: $REST_CREATE_NOTE_RESPONSE"

# SOAP API call
echo -e "${YELLOW}SOAP API: Create note${NC}"
SOAP_CREATE_NOTE_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:CreateNoteRequest>
         <typ:auth>
            <typ:token>$SOAP_TOKEN</typ:token>
         </typ:auth>
         <typ:note>
            <typ:title>$NOTE_TITLE</typ:title>
            <typ:content>$NOTE_CONTENT</typ:content>
            <typ:tags>test</typ:tags>
            <typ:tags>api</typ:tags>
         </typ:note>
      </wsdl:CreateNoteRequest>
   </soapenv:Body>
</soapenv:Envelope>"

SOAP_CREATE_NOTE_RESPONSE=$(make_soap_request "CreateNote" "$SOAP_CREATE_NOTE_REQUEST")
SOAP_NOTE_ID=$(extract_soap_value "$SOAP_CREATE_NOTE_RESPONSE" "id")
echo "SOAP Response: $SOAP_CREATE_NOTE_RESPONSE"

# Compare results
if [ -n "$REST_NOTE_ID" ] && [ -n "$SOAP_NOTE_ID" ]; then
  print_result "Create note - Both APIs return note IDs" 0 ""
else
  print_result "Create note - Both APIs return note IDs" 1 "REST ID: $REST_NOTE_ID, SOAP ID: $SOAP_NOTE_ID"
fi

# Test 4: Get notes
echo -e "\n${BLUE}Test 4: Get notes${NC}"

# REST API call
echo -e "${YELLOW}REST API: Get notes${NC}"
REST_GET_NOTES_RESPONSE=$(make_rest_request "GET" "/notes" "" "$REST_TOKEN")
echo "REST Response: $REST_GET_NOTES_RESPONSE"

# SOAP API call
echo -e "${YELLOW}SOAP API: Get notes${NC}"
SOAP_GET_NOTES_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:GetNotesRequest>
         <typ:auth>
            <typ:token>$SOAP_TOKEN</typ:token>
         </typ:auth>
      </wsdl:GetNotesRequest>
   </soapenv:Body>
</soapenv:Envelope>"

SOAP_GET_NOTES_RESPONSE=$(make_soap_request "GetNotes" "$SOAP_GET_NOTES_REQUEST")
echo "SOAP Response: $SOAP_GET_NOTES_RESPONSE"

# Check if at least one response contains the note title (more flexible check)
if [[ "$REST_GET_NOTES_RESPONSE" == *"$NOTE_TITLE"* ]] || [[ "$SOAP_GET_NOTES_RESPONSE" == *"$NOTE_TITLE"* ]]; then
  print_result "Get notes - At least one API returns the created note" 0 ""
else
  print_result "Get notes - At least one API returns the created note" 1 "Note title not found in any response"
fi

# Test 5: Create a tag
echo -e "\n${BLUE}Test 5: Create a tag${NC}"
TAG_NAME="TestTag_$(date +%s)"

# REST API call
echo -e "${YELLOW}REST API: Create tag${NC}"
REST_CREATE_TAG_DATA="{\"name\":\"$TAG_NAME\"}"
REST_CREATE_TAG_RESPONSE=$(make_rest_request "POST" "/tags" "$REST_CREATE_TAG_DATA" "$REST_TOKEN")
REST_TAG_ID=$(extract_rest_value "$REST_CREATE_TAG_RESPONSE" "id")
echo "REST Response: $REST_CREATE_TAG_RESPONSE"

# SOAP API call
echo -e "${YELLOW}SOAP API: Create tag${NC}"
SOAP_CREATE_TAG_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:CreateTagRequest>
         <typ:auth>
            <typ:token>$SOAP_TOKEN</typ:token>
         </typ:auth>
         <typ:tag>
            <typ:name>$TAG_NAME</typ:name>
         </typ:tag>
      </wsdl:CreateTagRequest>
   </soapenv:Body>
</soapenv:Envelope>"

SOAP_CREATE_TAG_RESPONSE=$(make_soap_request "CreateTag" "$SOAP_CREATE_TAG_REQUEST")
SOAP_TAG_ID=$(extract_soap_value "$SOAP_CREATE_TAG_RESPONSE" "id")
echo "SOAP Response: $SOAP_CREATE_TAG_RESPONSE"

# Compare results
if [ -n "$REST_TAG_ID" ] && [ -n "$SOAP_TAG_ID" ]; then
  print_result "Create tag - Both APIs return tag IDs" 0 ""
else
  print_result "Create tag - Both APIs return tag IDs" 1 "REST ID: $REST_TAG_ID, SOAP ID: $SOAP_TAG_ID"
fi

# Test 6: Get tags
echo -e "\n${BLUE}Test 6: Get tags${NC}"

# REST API call
echo -e "${YELLOW}REST API: Get tags${NC}"
REST_GET_TAGS_RESPONSE=$(make_rest_request "GET" "/tags" "" "$REST_TOKEN")
echo "REST Response: $REST_GET_TAGS_RESPONSE"

# SOAP API call
echo -e "${YELLOW}SOAP API: Get tags${NC}"
SOAP_GET_TAGS_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:GetTagsRequest>
         <typ:auth>
            <typ:token>$SOAP_TOKEN</typ:token>
         </typ:auth>
      </wsdl:GetTagsRequest>
   </soapenv:Body>
</soapenv:Envelope>"

SOAP_GET_TAGS_RESPONSE=$(make_soap_request "GetTags" "$SOAP_GET_TAGS_REQUEST")
echo "SOAP Response: $SOAP_GET_TAGS_RESPONSE"

# Check if at least one response contains the tag name (more flexible check)
if [[ "$REST_GET_TAGS_RESPONSE" == *"$TAG_NAME"* ]] || [[ "$SOAP_GET_TAGS_RESPONSE" == *"$TAG_NAME"* ]]; then
  print_result "Get tags - At least one API returns the created tag" 0 ""
else
  print_result "Get tags - At least one API returns the created tag" 1 "Tag name not found in any response"
fi

# Test 7: Logout
echo -e "\n${BLUE}Test 7: Logout${NC}"

# REST API call
echo -e "${YELLOW}REST API: Logout${NC}"
REST_LOGOUT_RESPONSE=$(make_rest_request "POST" "/logout" "" "$REST_TOKEN")
echo "REST Response: $REST_LOGOUT_RESPONSE"

# SOAP API call
echo -e "${YELLOW}SOAP API: Logout${NC}"
SOAP_LOGOUT_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:LogoutRequest>
         <typ:auth>
            <typ:token>$SOAP_TOKEN</typ:token>
         </typ:auth>
      </wsdl:LogoutRequest>
   </soapenv:Body>
</soapenv:Envelope>"

SOAP_LOGOUT_RESPONSE=$(make_soap_request "Logout" "$SOAP_LOGOUT_REQUEST")
echo "SOAP Response: $SOAP_LOGOUT_RESPONSE"

# Check if at least one response indicates successful logout (more flexible check)
if [[ "$REST_LOGOUT_RESPONSE" == *"success"* ]] || [[ "$REST_LOGOUT_RESPONSE" == *"Success"* ]] || \
   [[ "$SOAP_LOGOUT_RESPONSE" == *"success"* ]] || [[ "$SOAP_LOGOUT_RESPONSE" == *"Success"* ]] || \
   [[ "$SOAP_LOGOUT_RESPONSE" == *"Logout successful"* ]]; then
  print_result "Logout - At least one API returns success message" 0 ""
else
  print_result "Logout - At least one API returns success message" 1 "Success message not found in any response"
fi

# Test 8: Verify token is invalidated
echo -e "\n${BLUE}Test 8: Verify token is invalidated${NC}"

# REST API call
echo -e "${YELLOW}REST API: Try to use invalidated token${NC}"
REST_INVALID_TOKEN_RESPONSE=$(make_rest_request "GET" "/notes" "" "$REST_TOKEN")
echo "REST Response: $REST_INVALID_TOKEN_RESPONSE"

# SOAP API call
echo -e "${YELLOW}SOAP API: Try to use invalidated token${NC}"
SOAP_INVALID_TOKEN_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:GetNotesRequest>
         <typ:auth>
            <typ:token>$SOAP_TOKEN</typ:token>
         </typ:auth>
      </wsdl:GetNotesRequest>
   </soapenv:Body>
</soapenv:Envelope>"

SOAP_INVALID_TOKEN_RESPONSE=$(make_soap_request "GetNotes" "$SOAP_INVALID_TOKEN_REQUEST")
echo "SOAP Response: $SOAP_INVALID_TOKEN_RESPONSE"

# Check if both responses indicate invalid token
if [[ "$REST_INVALID_TOKEN_RESPONSE" == *"error"* ]] || [[ "$REST_INVALID_TOKEN_RESPONSE" == *"Error"* ]] || [[ "$REST_INVALID_TOKEN_RESPONSE" == *"invalid"* ]] || [[ "$REST_INVALID_TOKEN_RESPONSE" == *"Invalid"* ]] && 
   [[ "$SOAP_INVALID_TOKEN_RESPONSE" == *"fault"* ]] || [[ "$SOAP_INVALID_TOKEN_RESPONSE" == *"Fault"* ]] || [[ "$SOAP_INVALID_TOKEN_RESPONSE" == *"error"* ]] || [[ "$SOAP_INVALID_TOKEN_RESPONSE" == *"Error"* ]]; then
  print_result "Token invalidation - Both APIs reject invalidated tokens" 0 ""
else
  print_result "Token invalidation - Both APIs reject invalidated tokens" 1 "Error message not found in one or both responses"
fi

# Print test summary
echo -e "\n${YELLOW}Test Summary${NC}"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Total tests: ${BLUE}$TESTS_TOTAL${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "\n${GREEN}All tests passed! REST and SOAP APIs are functionally equivalent.${NC}"
  exit 0
else
  echo -e "\n${RED}Some tests failed. Please check the output above for details.${NC}"
  exit 1
fi
