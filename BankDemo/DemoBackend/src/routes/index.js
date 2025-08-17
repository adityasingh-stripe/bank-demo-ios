const express = require("express");
const router = express.Router();
const healthController = require("../controllers/health");

// Import route modules
const accountsRoutes = require("./accounts");
const paymentsRoutes = require("./payments");
const customersRoutes = require("./customers");
const webhooksRoutes = require("./webhooks");

// Health check routes
router.get("/health", healthController.healthCheck);

// Webhook routes (must be before express.json() middleware)
router.use("/", webhooksRoutes);

// API routes (will use express.json() middleware)
router.use("/api", accountsRoutes);
router.use("/api", paymentsRoutes);
router.use("/api", customersRoutes);

module.exports = router;
