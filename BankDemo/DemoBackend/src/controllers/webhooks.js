const stripe = require("../config/stripe");
const {
  handleAccountUpdated,
  fetchAndUpdateAccountStatus,
} = require("./accounts");

/**
 * Webhook endpoint for Stripe events
 */
function handleWebhook(req, res) {
  const sig = req.headers["stripe-signature"];
  let event;

  if (!sig) {
    return res.status(400).send("Missing Stripe signature");
  }

  try {
    if (process.env.STRIPE_WEBHOOK_SECRET) {
      event = stripe.webhooks.constructEvent(
        req.body,
        sig,
        process.env.STRIPE_WEBHOOK_SECRET
      );
    } else {
      console.warn("Webhook signature verification disabled");
      try {
        const bodyString = req.body.toString("utf8");
        event = JSON.parse(bodyString);
      } catch (parseError) {
        console.error(
          "Failed to parse webhook body as JSON:",
          parseError.message
        );
        return res.status(400).send(`Invalid JSON: ${parseError.message}`);
      }
    }
  } catch (err) {
    console.error("Webhook signature verification failed:", err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  switch (event.type) {
    case "account.updated":
      handleAccountUpdated(event.data.object);
      break;

    case "capability.updated":
      fetchAndUpdateAccountStatus(event.account);
      break;

    case "account.application.authorized":
      fetchAndUpdateAccountStatus(event.account);
      break;

    case "person.created":
    case "person.updated":
      fetchAndUpdateAccountStatus(event.account);
      break;

    default:
      console.info(`Unhandled event type: ${event.type}`);
  }

  res.json({ received: true });
}

module.exports = {
  handleWebhook,
};
