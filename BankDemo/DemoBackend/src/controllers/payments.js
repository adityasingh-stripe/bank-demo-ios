const stripe = require("../config/stripe");

/**
 * Middleware to validate customer exists if provided
 */
async function validateCustomer(req, res, next) {
  try {
    const { customer, account_id } = req.body;

    if (customer && customer.id) {
      console.log(
        `Validating customer: ${customer.id} for account: ${account_id}`
      );

      try {
        const stripeCustomer = await stripe.customers.retrieve(customer.id, {
          stripeAccount: account_id,
        });

        console.log(
          `Customer validation successful: ${stripeCustomer.id} (${stripeCustomer.name})`
        );
        // Store validated customer in request for use in payment intent creation
        req.validatedCustomer = stripeCustomer;
      } catch (error) {
        console.error(
          `Customer validation failed for ${customer.id}:`,
          error.message
        );
        return res.status(400).json({
          error: `Customer ${customer.id} not found`,
          details: error.message,
        });
      }
    } else {
      console.log(
        "No customer provided - payment intent will be created without customer"
      );
      req.validatedCustomer = null;
    }

    next();
  } catch (error) {
    console.error("Customer validation middleware error:", error);
    res.status(500).json({ error: error.message });
  }
}

/**
 * Create connection token for Terminal SDK
 */
async function createConnectionToken(req, res) {
  try {
    const { account_id } = req.body;

    if (!account_id) {
      return res.status(400).json({ error: "account_id is required" });
    }

    const connectionToken = await stripe.terminal.connectionTokens.create(
      {},
      { stripeAccount: account_id }
    );

    res.json({ secret: connectionToken.secret });
  } catch (error) {
    console.error("Error creating connection token:", error);
    res.status(500).json({ error: error.message });
  }
}

/**
 * Create payment intent with optional customer attachment
 */
async function createPaymentIntent(req, res) {
  try {
    const {
      amount,
      currency = "gbp",
      account_id,
      payment_method_types = ["card_present"],
      capture_method = "automatic",
    } = req.body;

    if (!account_id) {
      return res.status(400).json({ error: "account_id is required" });
    }

    if (!amount || amount <= 0) {
      return res.status(400).json({ error: "Valid amount is required" });
    }

    // Build payment intent data
    const paymentIntentData = {
      amount,
      currency,
      payment_method_types,
      capture_method,
    };

    // Add customer if validated (from middleware)
    if (req.validatedCustomer) {
      paymentIntentData.customer = req.validatedCustomer.id;
      console.log(
        `Creating payment intent for customer: ${req.validatedCustomer.id} (${req.validatedCustomer.name})`
      );
    } else {
      console.log("Creating payment intent without customer");
    }

    const paymentIntent = await stripe.paymentIntents.create(
      paymentIntentData,
      { stripeAccount: account_id }
    );

    console.log(
      `Payment intent created: ${paymentIntent.id} for £${amount / 100}`
    );

    res.json({
      clientSecret: paymentIntent.client_secret,
      customer: req.validatedCustomer || null,
      paymentIntent: {
        id: paymentIntent.id,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
      },
    });
  } catch (error) {
    console.error("Error creating payment intent:", error);
    res.status(500).json({ error: error.message });
  }
}

/**
 * Get locations for Terminal SDK
 */
async function getLocations(req, res) {
  try {
    const { account_id } = req.query;

    if (!account_id) {
      return res.status(400).json({ error: "account_id is required" });
    }

    const locations = await stripe.terminal.locations.list(
      {},
      { stripeAccount: account_id }
    );

    res.json({ locations: locations.data });
  } catch (error) {
    console.error("Error fetching locations:", error);
    res.status(500).json({ error: error.message });
  }
}

module.exports = {
  createConnectionToken,
  createPaymentIntent,
  getLocations,
  validateCustomer, // Export middleware
};
