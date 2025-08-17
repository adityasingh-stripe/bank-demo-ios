const stripe = require("../config/stripe");

/**
 * Get customers for an account
 */
async function getCustomers(req, res) {
  try {
    const { account_id } = req.query;

    if (!account_id) {
      return res.status(400).json({
        error: "account_id is required",
      });
    }

    const customers = await stripe.customers.list(
      {
        limit: 100,
      },
      {
        stripeAccount: account_id,
      }
    );

    res.json({
      customers: customers.data,
    });
  } catch (error) {
    console.error("Failed to fetch customers:", error.message);
    res.status(500).json({
      error: error.message,
    });
  }
}

/**
 * Create a customer for an account
 */
async function createCustomer(req, res) {
  try {
    const { account_id, name, email } = req.body;

    if (!account_id) {
      return res.status(400).json({
        error: "account_id is required",
      });
    }

    const customer = await stripe.customers.create(
      {
        name,
        email,
      },
      {
        stripeAccount: account_id,
      }
    );

    res.json({
      customer,
    });
  } catch (error) {
    console.error("Failed to create customer:", error.message);
    res.status(500).json({
      error: error.message,
    });
  }
}

module.exports = {
  getCustomers,
  createCustomer,
};
