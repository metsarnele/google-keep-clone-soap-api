# Google Keep SOAP API Clone

This is a SOAP API implementation of a Google Keep clone built using Node.js and Express. It provides the same functionality as a REST API but using the SOAP protocol.

## Prerequisites

Ensure you have the following installed on your system:
- [Node.js](https://nodejs.org/) (v14 or later)
- [npm](https://www.npmjs.com/) (comes with Node.js)

## Building the Application

This is a Node.js application, so building simply requires installing dependencies:

```sh
npm install
```

If you're using a different package manager like Yarn, you can use:

```sh
yarn install
```

## Installation

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

### SOAP API
The SOAP API is defined in the WSDL file located at `wsdl/google-keep-soap.wsdl`. This file describes all available operations, message formats, and data types.

The SOAP API is documented through its WSDL file:
   ```
   http://localhost:8001/wsdl
   ```

## SOAP API Implementation

The SOAP API provides the same functionality as the REST API but using SOAP protocol. It includes:

- User management (register, update, delete)
- Authentication (login, logout)
- Note management (create, read, update, delete)
- Tag management (create, read, update, delete)

## Implementation Notes

While this implementation uses Node.js, the SOAP protocol is language-agnostic. The WSDL file (`wsdl/google-keep-soap.wsdl`) defines the service contract and can be used with any programming language that supports SOAP.

To implement a client in another language, use the WSDL file to generate client code using your preferred SOAP toolkit.

### Testing the SOAP API

You can test the SOAP API using the provided test script:

```sh
bash tests/test.sh
```

This script will run a series of tests to verify that all SOAP operations are working correctly.

### Using the SOAP Client

A sample SOAP client is provided in the `client` directory. You can run it using:

```sh
node client/example.js
```

This interactive client allows you to test all SOAP operations from the command line.

### Alternative Client Examples

#### Using curl (Command Line)

```sh
curl -X POST http://localhost:8001/soap \
  -H "Content-Type: text/xml" \
  -d '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wsdl="http://keep.soap.api/wsdl" xmlns:typ="http://keep.soap.api/types"><soapenv:Header/><soapenv:Body><wsdl:LoginRequest><typ:credentials><typ:username>testuser</typ:username><typ:password>password123</typ:password></typ:credentials></wsdl:LoginRequest></soapenv:Body></soapenv:Envelope>'
```

#### Using Other Languages

You can use any programming language that supports SOAP to interact with this API. Here are some examples:

**Python (using zeep):**
```python
from zeep import Client

client = Client('http://localhost:8001/wsdl')
result = client.service.Login(credentials={'username': 'testuser', 'password': 'password123'})
print(result)
```

**Java (using JAX-WS):**
```java
import javax.xml.namespace.QName;
import jakarta.xml.ws.Service;

URL wsdlURL = new URL("http://localhost:8001/wsdl");
QName qname = new QName("http://keep.soap.api/wsdl", "GoogleKeepService");
Service service = Service.create(wsdlURL, qname);
GoogleKeepPortType port = service.getPort(GoogleKeepPortType.class);

// Call operations
SessionResponse response = port.login(credentials);
```

