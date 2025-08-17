const stripe = require("../config/stripe");

/**
 * Create a default location for a connected account
 * @param {string} accountId - The account ID
 * @returns {Promise<object>} - Created location object
 */
async function createDefaultLocation(accountId) {
  try {
    const location = await stripe.terminal.locations.create(
      {
        display_name: "Business Location",
        address: {
          line1: "123 Business Street",
          city: "London",
          country: "GB",
          postal_code: "SW1A 1AA",
        },
      },
      {
        stripeAccount: accountId,
      }
    );

    console.info(
      `INFO: Created default location for account ${accountId}: ${location.id}`
    );
    return location;
  } catch (error) {
    console.error(
      `ERROR: Failed to create location for account ${accountId}: ${error.message}`
    );
    throw error;
  }
}

/**
 * Get locations for a connected account
 * @param {string} accountId - The account ID
 * @returns {Promise<object>} - List of locations
 */
async function getLocations(accountId) {
  const locations = await stripe.terminal.locations.list(
    {},
    {
      stripeAccount: accountId,
    }
  );

  return locations.data;
}

/**
 * Create connection token for Terminal SDK
 * @param {string} accountId - The account ID
 * @returns {Promise<object>} - Connection token object
 */
async function createConnectionToken(accountId) {
  const connectionToken = await stripe.terminal.connectionTokens.create(
    {},
    {
      stripeAccount: accountId, // Create connection token for the connected account
    }
  );

  return connectionToken;
}

module.exports = {
  createDefaultLocation,
  getLocations,
  createConnectionToken,
};
