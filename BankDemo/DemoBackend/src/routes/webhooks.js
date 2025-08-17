const express = require("express");
const router = express.Router();
const webhooksController = require("../controllers/webhooks");

// Webhook endpoint - must use raw body parser
router.post(
  "/webhook",
  express.raw({ type: "application/json" }),
  webhooksController.handleWebhook
);

module.exports = router;
