# Google Keep SOAP API Clone

This is a SOAP API implementation of a Google Keep clone built using Node.js and Express. It provides the same functionality as a REST API but using the SOAP protocol.

## Prerequisites

Ensure you have the following installed on your system:
- [Node.js](https://nodejs.org/) (v14 or later)
- [npm](https://www.npmjs.com/) (comes with Node.js)

## Quick Setup

We provide a setup script that automates the installation process:

```sh
# Make the setup script executable
chmod +x scripts/setup.sh

# Run the setup script
bash scripts/setup.sh
```

The setup script will:
1. Verify Node.js is installed (v14 or later)
2. Install all dependencies
3. Create a `.env` file with a secure random secret key
4. Set up the data directory
5. Make all scripts executable

### Manual Installation

If you prefer to install manually:

1. **Install dependencies**
   ```sh
   npm install
   ```

2. **Set up environment variables**
   ```sh
   cp .env.example .env
   ```
   Then edit the `.env` file to add your own values for the environment variables.

## Running the Application

### Start the SOAP Server
   ```sh
   bash scripts/run.sh
   ```
   Or run directly:
   ```sh
   node src/simple-soap-server.js
   ```

The SOAP server will start at:
   ```
   http://localhost:8001
   ```

The WSDL file will be available at:
   ```
   http://localhost:8001/wsdl
   ```

The SOAP endpoint will be available at:
   ```
   http://localhost:8001/soap
   ```

## API Documentation

The SOAP API is defined in the WSDL file located at `wsdl/google-keep-soap.wsdl`. This file describes all available operations, message formats, and data types.

When the server is running, the WSDL is available at: `http://localhost:8001/wsdl`

### Features

This API provides the following functionality:

- User management (register, update, delete)
- Authentication (login, logout)
- Note management (create, read, update, delete)
- Tag management (create, read, update, delete)

## Implementation Notes

While this implementation uses Node.js, the SOAP protocol is language-agnostic. The WSDL file (`wsdl/google-keep-soap.wsdl`) defines the service contract and can be used with any programming language that supports SOAP.

To implement a client in another language, use the WSDL file to generate client code using your preferred SOAP toolkit.

## Testing

### Testing the SOAP API

You can test the SOAP API using the provided test script:

```sh
bash tests/test.sh
```

This script will run a series of tests to verify that all SOAP operations are working correctly.

### Comparing REST and SOAP APIs

To verify the functional equivalence between the REST and SOAP APIs, you can run the comparison tests:

```sh
bash scripts/run-comparison-tests.sh
```

This script will:
1. Start both REST and SOAP servers
2. Run a series of tests against both APIs
3. Compare the results to verify functional equivalence
4. Stop the servers after testing

### Common Issues and Solutions

If you encounter any issues running the tests, check these common solutions:

1. **Port conflicts**: If ports 3000 or 8001 are already in use, you can modify the port numbers in the `.env` file.

2. **Missing dependencies**: Run `npm install` to ensure all dependencies are installed.

3. **Permission issues**: Make sure all scripts are executable with `chmod +x scripts/*.sh tests/*.sh`.

4. **Data persistence**: If tests are failing due to existing data, you can clear the data directory with `rm -rf data/*.json` before running tests.

5. **Token extraction issues**: If the login test is failing, ensure you're using the latest version of the test script which properly extracts tokens from both REST and SOAP responses.

## Client Examples

### Using the Provided Client

A sample SOAP client is provided in the `client` directory:

```sh
node client/example.js
```

### Using curl

```sh
curl -X POST http://localhost:8001/soap \
  -H "Content-Type: text/xml" \
  -d '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wsdl="http://keep.soap.api/wsdl" xmlns:typ="http://keep.soap.api/types"><soapenv:Header/><soapenv:Body><wsdl:LoginRequest><typ:credentials><typ:username>testuser</typ:username><typ:password>password123</typ:password></typ:credentials></wsdl:LoginRequest></soapenv:Body></soapenv:Envelope>'
```

### Using Other Languages

You can use any programming language that supports SOAP to interact with this API:

**Python (using zeep):**
```python
from zeep import Client

client = Client('http://localhost:8001/wsdl')
result = client.service.Login(credentials={'username': 'testuser', 'password': 'password123'})
```

**Java (using JAX-WS):**
```java
URL wsdlURL = new URL("http://localhost:8001/wsdl");
QName qname = new QName("http://keep.soap.api/wsdl", "GoogleKeepService");
Service service = Service.create(wsdlURL, qname);
GoogleKeepPortType port = service.getPort(GoogleKeepPortType.class);
```

