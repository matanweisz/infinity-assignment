/**
 * Simple Express-based web application
 * - Root endpoint - Returns a welcome message
 * - Health endpoint - Health check endpoint
 * - Logs all requests
 */

// Import the Express framework and OS module
const express = require('express');
const os = require('os');

// Create an Express web app
const app = express();

// Use port 3000
const port = 3000;

// Logging of each request
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

/**
 * Root endpoint
 * Returns a simple welcome message
 */
app.get('/', (req, res) => {
  res.send('<h1>Welcome to my Node.js Web Application!</h1>');
});

/**
 * Health endpoint
 * Used for Kubernetes probes and health checks
 */
app.get('/health', (req, res) => {
  console.log('The /health endpoint was called');
  res.status(200).send('OK');
});

// Start the server
app.listen(port, () => {
  console.log(`The server is running and listening on port ${port}`);
});
