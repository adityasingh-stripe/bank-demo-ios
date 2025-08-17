# Deployment Guide

## Deploy to Vercel

### Prerequisites

- Vercel account
- Stripe account with API keys

### Environment Variables

Set these environment variables in your Vercel dashboard:

```
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_... (optional)
STRIPE_ACCOUNT_ID=acct_... (your platform account ID)
NODE_ENV=production
```

### Deploy Steps

1. **Install Vercel CLI**

   ```bash
   npm i -g vercel
   ```

2. **Login to Vercel**

   ```bash
   vercel login
   ```

3. **Deploy**
   ```bash
   vercel --prod
   ```

### Manual Deploy via Dashboard

1. Connect your GitHub repository to Vercel
2. Set environment variables in project settings
3. Deploy automatically on git push

### API Endpoints

Once deployed, your API will be available at:

- `https://your-app.vercel.app/api/health`
- `https://your-app.vercel.app/api/profiles`
- `https://your-app.vercel.app/api/accounts`
- And all other endpoints...

### Webhook Configuration

Update your Stripe webhook endpoint to:
`https://your-app.vercel.app/api/webhooks`
