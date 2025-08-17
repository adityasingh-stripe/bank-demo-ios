const express = require("express");
const router = express.Router();
const paymentsController = require("../controllers/payments");

// Payment-related routes
router.post("/connection_token", paymentsController.createConnectionToken);
router.post(
  "/create_payment_intent",
  paymentsController.validateCustomer,
  paymentsController.createPaymentIntent
);
router.get("/locations", paymentsController.getLocations);

module.exports = router;
