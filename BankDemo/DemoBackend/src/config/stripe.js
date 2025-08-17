const dotenv = require("dotenv");

// Load environment variables
dotenv.config();

// Initialize Stripe with your secret key
const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);

module.exports = stripe;
