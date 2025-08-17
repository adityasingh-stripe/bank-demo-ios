const express = require("express");
const cors = require("cors");
const webhooksRoutes = require("./routes/webhooks");
const accountsRoutes = require("./routes/accounts");
const paymentsRoutes = require("./routes/payments");
const customersRoutes = require("./routes/customers");
const healthController = require("./controllers/health");
const filesController = require("./controllers/files");

const app = express();

// Middleware
app.use(cors());

// Webhook endpoint (needs raw body parsing)
app.use(webhooksRoutes);

// JSON parsing for all other routes
app.use(express.json());

// App info endpoint (returns publishable key)
app.get("/api/app_info", healthController.healthCheck);

// File serving endpoint (for Stripe uploaded files)
app.get("/api/file/:fileId", filesController.serveStripeFile);

// API routes
app.use("/api", accountsRoutes);
app.use("/api", paymentsRoutes);
app.use("/api", customersRoutes);

module.exports = app;
