# Demo Backend

Express.js backend for Stripe Connect integration with iOS app.

## Folder Structure

```
demo-backend/
├── server.js              # Entry point
├── src/
│   ├── app.js             # Express app setup
│   ├── config/
│   │   ├── stripe.js      # Stripe client
│   │   └── constants.js   # Demo data & configs
│   ├── controllers/       # Request handlers
│   │   ├── accounts.js    # Account operations
│   │   ├── payments.js    # Payment & terminal
│   │   ├── customers.js   # Customer management
│   │   ├── webhooks.js    # Stripe webhooks
│   │   └── health.js      # Health checks
│   ├── services/          # Business logic
│   │   ├── accountService.js    # Account creation
│   │   ├── terminalService.js   # Terminal SDK
│   │   └── testDataService.js   # Test data generation
│   ├── utils/             # Utilities
│   │   ├── validation.js  # Input validation
│   │   └── accountStatus.js     # Status derivation
│   └── routes/            # API routes
│       ├── accounts.js    # /api/accounts/*
│       ├── payments.js    # /api/payments/*
│       ├── customers.js   # /api/customers/*
│       └── webhooks.js    # /webhook
├── package.json
└── .env                   # Environment config
```

## Setup

1. **Install dependencies:**

   ```bash
   npm install
   ```

2. **Rename `.env.example` file to `.env` and add the secrets:**

   ```bash
   STRIPE_SECRET_KEY=sk_test_51RiB***a8r
   STRIPE_PUBLISHABLE_KEY=pk_test_51R***Ezp
   STRIPE_WEBHOOK_SECRET=whsec_8d2***c07b7
   STRIPE_ACCOUNT_ID=acct_****
   PORT=4242
   ```

3. **Run server:**
   ```bash
   node server.js
   ```

Server runs on `http://localhost:3000`

## API Endpoints

### Core APIs (used by iOS app)

- `GET /api/app_info` - Returns app configuration including branding: `{"publishable_key": "pk_test_...", "logo_url": "...", "primary_color": "#FF0000"}`
- `GET /api/profiles` - Demo profiles for selection
- `POST /api/accounts` - Create connected account
- `POST /api/account_session` - Account session for embedded components
- `POST /api/connection_token` - Terminal SDK token
- `POST /api/create_payment_intent` - Payment processing
- `GET /api/locations` - Terminal locations
- `GET /api/customers` - List customers
- `POST /api/customers` - Create customer

### Utilities

- `POST /api/create_test_data` - Generate test data (5 disputes, 5 payouts)
- `POST /webhook` - Stripe webhook handler
- `GET /health` - Health check

## Test Data

Creates realistic test data:

- **25 customers** (fictional names)
- **1 top-up payment** (£10,000)
- **20 regular payments** (£2.50-£500)
- **5 disputed payments**
- **5 payouts** (real Stripe payouts)

## Demo Profiles

Random selection from:

- **Individual:** James Bond, Hermione Granger, Arthur Dent
- **Company:** Fawlty Hotels, Wonka Chocolate, Galaxy Dining
