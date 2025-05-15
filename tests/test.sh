#!/bin/bash

# Test script for Google Keep SOAP API
# This script tests the functionality of the SOAP API by making SOAP requests

# Set variables
HOST="localhost"
PORT="8001"
ENDPOINT="http://$HOST:$PORT/soap"
WSDL_URL="http://$HOST:$PORT/wsdl"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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
  local output=$(curl -s -X POST "$ENDPOINT" \
    -H "Content-Type: text/xml;charset=UTF-8" \
    -H "SOAPAction: \"http://keep.soap.api/$action\"" \
    -d "$body")
  
  echo "$output"
}

# Function to extract value from SOAP response
extract_value() {
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

# Check if the SOAP server is running
echo -e "${YELLOW}Checking if SOAP server is running...${NC}"
if ! curl -s "$WSDL_URL" > /dev/null; then
  echo -e "${RED}Error: SOAP server is not running at $WSDL_URL${NC}"
  echo -e "${YELLOW}Please start the SOAP server before running tests.${NC}"
  exit 1
fi
echo -e "${GREEN}SOAP server is running!${NC}"

echo -e "\n${YELLOW}Starting tests...${NC}"

# Test 1: Register a user
echo -e "\n${YELLOW}Test 1: Register a user${NC}"
USER_USERNAME="testuser_$(date +%s)"
USER_PASSWORD="password123"

REGISTER_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
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

REGISTER_RESPONSE=$(make_soap_request "RegisterUser" "$REGISTER_REQUEST")
USER_ID=$(extract_value "$REGISTER_RESPONSE" "id")

if [ -n "$USER_ID" ]; then
  print_result "Register user" 0 ""
  echo "  Created user with ID: $USER_ID"
else
  print_result "Register user" 1 "Failed to register user or extract user ID"
  echo "$REGISTER_RESPONSE"
fi

# Test 2: Login
echo -e "\n${YELLOW}Test 2: Login${NC}"
LOGIN_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
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

LOGIN_RESPONSE=$(make_soap_request "Login" "$LOGIN_REQUEST")
AUTH_TOKEN=$(extract_value "$LOGIN_RESPONSE" "token")

if [ -n "$AUTH_TOKEN" ]; then
  print_result "Login" 0 ""
  echo "  Got auth token: ${AUTH_TOKEN:0:20}..."
else
  print_result "Login" 1 "Failed to login or extract auth token"
  echo "$LOGIN_RESPONSE"
fi

# Test 3: Create a note
echo -e "\n${YELLOW}Test 3: Create a note${NC}"
NOTE_TITLE="Test Note"
NOTE_CONTENT="This is a test note created by the automated test script."

CREATE_NOTE_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:CreateNoteRequest>
         <typ:auth>
            <typ:token>$AUTH_TOKEN</typ:token>
         </typ:auth>
         <typ:note>
            <typ:title>$NOTE_TITLE</typ:title>
            <typ:content>$NOTE_CONTENT</typ:content>
            <typ:tags>test</typ:tags>
            <typ:tags>automation</typ:tags>
         </typ:note>
      </wsdl:CreateNoteRequest>
   </soapenv:Body>
</soapenv:Envelope>"

CREATE_NOTE_RESPONSE=$(make_soap_request "CreateNote" "$CREATE_NOTE_REQUEST")
NOTE_ID=$(extract_value "$CREATE_NOTE_RESPONSE" "id")

if [ -n "$NOTE_ID" ]; then
  print_result "Create note" 0 ""
  echo "  Created note with ID: $NOTE_ID"
else
  print_result "Create note" 1 "Failed to create note or extract note ID"
  echo "$CREATE_NOTE_RESPONSE"
fi

# Test 4: Get notes
echo -e "\n${YELLOW}Test 4: Get notes${NC}"
GET_NOTES_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:GetNotesRequest>
         <typ:auth>
            <typ:token>$AUTH_TOKEN</typ:token>
         </typ:auth>
      </wsdl:GetNotesRequest>
   </soapenv:Body>
</soapenv:Envelope>"

GET_NOTES_RESPONSE=$(make_soap_request "GetNotes" "$GET_NOTES_REQUEST")

if [[ "$GET_NOTES_RESPONSE" == *"$NOTE_TITLE"* && "$GET_NOTES_RESPONSE" == *"$NOTE_CONTENT"* ]]; then
  print_result "Get notes" 0 ""
else
  print_result "Get notes" 1 "Failed to retrieve notes or note content doesn't match"
  echo "$GET_NOTES_RESPONSE"
fi

# Test 5: Update a note
echo -e "\n${YELLOW}Test 5: Update a note${NC}"
UPDATED_NOTE_TITLE="Updated Test Note"
UPDATED_NOTE_CONTENT="This note has been updated by the test script."

UPDATE_NOTE_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:UpdateNoteRequest>
         <typ:auth>
            <typ:token>$AUTH_TOKEN</typ:token>
         </typ:auth>
         <typ:id>
            <typ:id>$NOTE_ID</typ:id>
         </typ:id>
         <typ:update>
            <typ:title>$UPDATED_NOTE_TITLE</typ:title>
            <typ:content>$UPDATED_NOTE_CONTENT</typ:content>
         </typ:update>
      </wsdl:UpdateNoteRequest>
   </soapenv:Body>
</soapenv:Envelope>"

UPDATE_NOTE_RESPONSE=$(make_soap_request "UpdateNote" "$UPDATE_NOTE_REQUEST")
UPDATE_MESSAGE=$(extract_value "$UPDATE_NOTE_RESPONSE" "message")

if [[ "$UPDATE_MESSAGE" == *"updated successfully"* ]]; then
  print_result "Update note" 0 ""
else
  print_result "Update note" 1 "Failed to update note"
  echo "$UPDATE_NOTE_RESPONSE"
fi

# Test 6: Create a tag
echo -e "\n${YELLOW}Test 6: Create a tag${NC}"
TAG_NAME="TestTag_$(date +%s)"

CREATE_TAG_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:CreateTagRequest>
         <typ:auth>
            <typ:token>$AUTH_TOKEN</typ:token>
         </typ:auth>
         <typ:tag>
            <typ:name>$TAG_NAME</typ:name>
         </typ:tag>
      </wsdl:CreateTagRequest>
   </soapenv:Body>
</soapenv:Envelope>"

CREATE_TAG_RESPONSE=$(make_soap_request "CreateTag" "$CREATE_TAG_REQUEST")
TAG_ID=$(extract_value "$CREATE_TAG_RESPONSE" "id")

if [ -n "$TAG_ID" ]; then
  print_result "Create tag" 0 ""
  echo "  Created tag with ID: $TAG_ID"
else
  print_result "Create tag" 1 "Failed to create tag or extract tag ID"
  echo "$CREATE_TAG_RESPONSE"
fi

# Test 7: Get tags
echo -e "\n${YELLOW}Test 7: Get tags${NC}"
GET_TAGS_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:GetTagsRequest>
         <typ:auth>
            <typ:token>$AUTH_TOKEN</typ:token>
         </typ:auth>
      </wsdl:GetTagsRequest>
   </soapenv:Body>
</soapenv:Envelope>"

GET_TAGS_RESPONSE=$(make_soap_request "GetTags" "$GET_TAGS_REQUEST")

if [[ "$GET_TAGS_RESPONSE" == *"$TAG_NAME"* ]]; then
  print_result "Get tags" 0 ""
else
  print_result "Get tags" 1 "Failed to retrieve tags or tag name doesn't match"
  echo "$GET_TAGS_RESPONSE"
fi

# Test 8: Update a tag
echo -e "\n${YELLOW}Test 8: Update a tag${NC}"
UPDATED_TAG_NAME="UpdatedTestTag_$(date +%s)"

UPDATE_TAG_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:UpdateTagRequest>
         <typ:auth>
            <typ:token>$AUTH_TOKEN</typ:token>
         </typ:auth>
         <typ:id>
            <typ:id>$TAG_ID</typ:id>
         </typ:id>
         <typ:update>
            <typ:name>$UPDATED_TAG_NAME</typ:name>
         </typ:update>
      </wsdl:UpdateTagRequest>
   </soapenv:Body>
</soapenv:Envelope>"

UPDATE_TAG_RESPONSE=$(make_soap_request "UpdateTag" "$UPDATE_TAG_REQUEST")
UPDATE_TAG_MESSAGE=$(extract_value "$UPDATE_TAG_RESPONSE" "message")

if [[ "$UPDATE_TAG_MESSAGE" == *"updated successfully"* ]]; then
  print_result "Update tag" 0 ""
else
  print_result "Update tag" 1 "Failed to update tag"
  echo "$UPDATE_TAG_RESPONSE"
fi

# Test 9: Delete a note
echo -e "\n${YELLOW}Test 9: Delete a note${NC}"
DELETE_NOTE_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:DeleteNoteRequest>
         <typ:auth>
            <typ:token>$AUTH_TOKEN</typ:token>
         </typ:auth>
         <typ:id>
            <typ:id>$NOTE_ID</typ:id>
         </typ:id>
      </wsdl:DeleteNoteRequest>
   </soapenv:Body>
</soapenv:Envelope>"

DELETE_NOTE_RESPONSE=$(make_soap_request "DeleteNote" "$DELETE_NOTE_REQUEST")
DELETE_NOTE_MESSAGE=$(extract_value "$DELETE_NOTE_RESPONSE" "message")

if [[ "$DELETE_NOTE_MESSAGE" == *"deleted successfully"* ]]; then
  print_result "Delete note" 0 ""
else
  print_result "Delete note" 1 "Failed to delete note"
  echo "$DELETE_NOTE_RESPONSE"
fi

# Test 10: Delete a tag
echo -e "\n${YELLOW}Test 10: Delete a tag${NC}"
DELETE_TAG_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:DeleteTagRequest>
         <typ:auth>
            <typ:token>$AUTH_TOKEN</typ:token>
         </typ:auth>
         <typ:id>
            <typ:id>$TAG_ID</typ:id>
         </typ:id>
      </wsdl:DeleteTagRequest>
   </soapenv:Body>
</soapenv:Envelope>"

DELETE_TAG_RESPONSE=$(make_soap_request "DeleteTag" "$DELETE_TAG_REQUEST")
DELETE_TAG_MESSAGE=$(extract_value "$DELETE_TAG_RESPONSE" "message")

if [[ "$DELETE_TAG_MESSAGE" == *"deleted successfully"* ]]; then
  print_result "Delete tag" 0 ""
else
  print_result "Delete tag" 1 "Failed to delete tag"
  echo "$DELETE_TAG_RESPONSE"
fi

# Test 11: Logout
echo -e "\n${YELLOW}Test 11: Logout${NC}"
LOGOUT_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:LogoutRequest>
         <typ:auth>
            <typ:token>$AUTH_TOKEN</typ:token>
         </typ:auth>
      </wsdl:LogoutRequest>
   </soapenv:Body>
</soapenv:Envelope>"

LOGOUT_RESPONSE=$(make_soap_request "Logout" "$LOGOUT_REQUEST")
LOGOUT_MESSAGE=$(extract_value "$LOGOUT_RESPONSE" "message")

if [[ "$LOGOUT_MESSAGE" == *"successful"* ]]; then
  print_result "Logout" 0 ""
else
  print_result "Logout" 1 "Failed to logout"
  echo "$LOGOUT_RESPONSE"
fi

# Test 12: Verify token is invalidated
echo -e "\n${YELLOW}Test 12: Verify token is invalidated${NC}"
GET_NOTES_AFTER_LOGOUT_REQUEST="<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:wsdl=\"http://keep.soap.api/wsdl\" xmlns:typ=\"http://keep.soap.api/types\">
   <soapenv:Header/>
   <soapenv:Body>
      <wsdl:GetNotesRequest>
         <typ:auth>
            <typ:token>$AUTH_TOKEN</typ:token>
         </typ:auth>
      </wsdl:GetNotesRequest>
   </soapenv:Body>
</soapenv:Envelope>"

GET_NOTES_AFTER_LOGOUT_RESPONSE=$(make_soap_request "GetNotes" "$GET_NOTES_AFTER_LOGOUT_REQUEST")

if [[ "$GET_NOTES_AFTER_LOGOUT_RESPONSE" == *"Token has been revoked"* || "$GET_NOTES_AFTER_LOGOUT_RESPONSE" == *"Invalid token"* ]]; then
  print_result "Verify token invalidation" 0 ""
else
  print_result "Verify token invalidation" 1 "Token was not properly invalidated"
  echo "$GET_NOTES_AFTER_LOGOUT_RESPONSE"
fi

# Print test summary
echo -e "\n${YELLOW}Test Summary${NC}"
echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
echo -e "Total tests: $TESTS_TOTAL"

if [ "$TESTS_FAILED" -eq 0 ]; then
  echo -e "\n${GREEN}All tests passed successfully!${NC}"
  exit 0
else
  echo -e "\n${RED}Some tests failed. Please check the output above for details.${NC}"
  exit 1
fi
