const express = require("express");
const router = express.Router();
const customersController = require("../controllers/customers");

// Customer-related routes
router.get("/customers", customersController.getCustomers);
router.post("/customers", customersController.createCustomer);

module.exports = router;
