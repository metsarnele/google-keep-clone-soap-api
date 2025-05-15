# Google Keep API Clone

This is a simple Google Keep clone API built using Node.js and Express.

## Prerequisites

Ensure you have the following installed on your system:
- [Node.js](https://nodejs.org/) (v14 or later)
- [npm](https://www.npmjs.com/) (comes with Node.js)

## Installation

1. **Clone the repository**
   ```sh
   git clone https://github.com/your-repo/google-keep-api.git
   cd google-keep-api
   ```

2. **Install dependencies**
   ```sh
   npm install
   ```

3. **Set up environment variables**
   ```sh
   cp .env.example .env
   ```
   Then edit the `.env` file to add your own values for the environment variables.

## Running the Application

### Start the Server
   ```sh
   npm start
   ```

The server will start at:
   ```
   http://localhost:3000
   ```

### API Documentation

The API is documented using Swagger. You can access the interactive documentation in both English and Estonian:

- English documentation:
   ```
   http://localhost:3000/docs/en
   ```

- Estonian documentation:
   ```
   http://localhost:3000/docs/et
   ```

Or visit the root documentation page which defaults to English:
   ```
   http://localhost:3000/docs
   ```

