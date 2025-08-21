# Payment Fallback Configuration Guide

This guide explains how to configure the payment fallback behavior when Tap to Pay transactions fail.

## Overview

The BankDemo app supports two payment fallback methods:

1. **Stripe Checkout Sessions** (Recommended) - Modern, hosted checkout experience
2. **Stripe Payment Links** (Legacy) - Simple payment links for basic use cases

## Configuration

### Single Control Point

Change the payment fallback type in `BankConfiguration.swift`:

```swift
// In each bank configuration, set the paymentFallbackType:

static let hsbc = BankConfiguration(
    // ... other properties ...
    paymentFallbackType: .checkoutSession,  // or .paymentLink
    // ... other properties ...
)
```

### Available Options

#### Option 1: Checkout Sessions (Recommended)

```swift
paymentFallbackType: .checkoutSession
```

**Features:**

- Full hosted checkout experience
- Built-in payment method selection
- Automatic tax calculation support
- Better conversion rates
- Mobile-optimized interface
- Success/cancel page handling

**User Experience:**

- Shows "Pay using online checkout" option
- Creates Stripe Checkout Session
- Generates QR code for cross-device payments
- Professional checkout interface

#### Option 2: Payment Links (Legacy)

```swift
paymentFallbackType: .paymentLink
```

**Features:**

- Simple payment link generation
- Basic payment processing
- Minimal configuration required
- Direct Stripe-hosted experience

**User Experience:**

- Shows "Pay using payment link" option
- Creates Stripe Payment Link
- Generates QR code for sharing
- Basic payment interface

## Implementation Details

### Flow Architecture

1. **Payment Failure Detection**

   ```swift
   private func handlePaymentError(_ error: Error) {
       showPaymentFailureScreen(amount: amount, error: error)
   }
   ```

2. **Dynamic Option Display**

   ```swift
   // PaymentFailureViewController automatically adapts based on configuration
   let fallbackOption = createOptionRow(
       systemIcon: theme.paymentFallbackType.systemIcon,
                   title: fallbackTitle,
       subtitle: theme.paymentFallbackType.subtitle,
       isEnabled: true,
       action: fallbackAction  // Automatically routes to correct flow
   )
   ```

3. **Automatic Routing**

   ```swift
   // PaymentCollectionViewController handles both flows
   func didSelectCheckout() {
       let checkoutVC = CheckoutSessionViewController(amount: amount, customer: selectedCustomer)
       present(checkoutVC, animated: true)
   }

   func didSelectPaymentLink() {
       let paymentLinkVC = PaymentLinkViewController(amount: amount, customer: selectedCustomer)
       present(paymentLinkVC, animated: true)
   }
   ```

### Backend Requirements

#### For Checkout Sessions

Required endpoint: `POST /api/create_checkout_session`

```javascript
{
  "amount": 2000,
  "currency": "gbp",
  "account_id": "acct_...",
  "customer": {"id": "cus_...", "name": "John Doe"},
  "business_name": "HSBC Business"
}
```

#### For Payment Links

Required endpoint: `POST /api/create_payment_link`

```javascript
{
  "amount": 2000,
  "currency": "gbp",
  "account_id": "acct_...",
  "customer": {"id": "cus_...", "name": "John Doe"},
  "description": "Payment"
}
```

## Bank-Specific Configuration

### HSBC Configuration

```swift
static let hsbc = BankConfiguration(
    bankName: "HSBC",
    paymentFallbackType: .checkoutSession,  // Recommended for enterprise
    // ... other HSBC-specific settings
)
```

### Lloyds Configuration

```swift
static let lloyds = BankConfiguration(
    bankName: "Lloyds",
    paymentFallbackType: .checkoutSession,  // Modern checkout experience
    // ... other Lloyds-specific settings
)
```

### Barclays Configuration

```swift
static let barclays = BankConfiguration(
    bankName: "Barclays",
    paymentFallbackType: .paymentLink,     // Simple link-based approach
    // ... other Barclays-specific settings
)
```

## Theme Integration

The configuration system integrates with the theming system:

### Dynamic UI Elements

```swift
// Icons adapt to fallback type
systemIcon: theme.paymentFallbackType.systemIcon
// "globe" for checkout sessions, "link" for payment links

// Text adapts to fallback type with appropriate wording
let fallbackTitle: String
switch theme.paymentFallbackType {
case .checkoutSession:
    fallbackTitle = "Pay using \(theme.paymentFallbackType.displayName.lowercased())"
    // Results in: "Pay using online checkout"
case .paymentLink:
    fallbackTitle = "Share a payment link"
    // Uses more natural wording for sharing links
}

// Subtitles provide context
subtitle: theme.paymentFallbackType.subtitle
// "Complete payment securely online" vs "Pay using a secure payment link"
```

### Consistent Styling

Both flows use the same theme system:

- Colors from `BankConfiguration.current`
- Typography using theme font sizes
- Spacing using theme spacing values
- Button styles from theme button factory

## Testing Different Configurations

### Quick Switch Test

1. Open `BankConfiguration.swift`
2. Change `paymentFallbackType` in current bank configuration
3. Build and run the app
4. Trigger a payment failure to test the flow

### A/B Testing Setup

```swift
// Example: Environment-based configuration
static let current: BankConfiguration = {
    let baseConfig = BankConfiguration.hsbc

    #if DEBUG
    // Test checkout sessions in debug
    return BankConfiguration(
        // ... copy all properties from baseConfig ...
        paymentFallbackType: .checkoutSession
    )
    #else
    // Use payment links in production
    return BankConfiguration(
        // ... copy all properties from baseConfig ...
        paymentFallbackType: .paymentLink
    )
    #endif
}()
```

## Best Practices

### Recommendation: Use Checkout Sessions

- Better user experience
- Higher conversion rates
- More payment methods supported
- Better mobile optimization
- Built-in success/error handling

### When to Use Payment Links

- Simple integration requirements
- Minimal backend changes needed
- Basic payment processing sufficient
- Legacy system compatibility

### Configuration Management

1. **Centralized Control**: All configuration in one place
2. **Type Safety**: Enum-based configuration prevents errors
3. **Theme Integration**: UI automatically adapts to configuration
4. **Easy Testing**: Simple switch between modes for testing

## Troubleshooting

### Common Issues

1. **Wrong Endpoint Called**

   - Check `paymentFallbackType` configuration
   - Verify backend endpoints are implemented
   - Check API request logs

2. **UI Shows Wrong Option**

   - Verify theme system is using `BankConfiguration.current`
   - Check that UI updates after configuration changes
   - Rebuild app after configuration changes

3. **Backend Errors**
   - Ensure both endpoints are implemented
   - Check Stripe account has required features enabled
   - Verify API keys have correct permissions

### Debug Logging

Both flows include comprehensive logging:

```
🛒 Checkout option selected - creating checkout session
✅ Checkout session created: https://checkout.stripe.com/...

🔗 Payment link option selected - creating payment link
✅ Payment link created: https://buy.stripe.com/...
```

## Migration Guide

### From Payment Links to Checkout Sessions

1. Implement `/api/create_checkout_session` endpoint
2. Update configuration: `paymentFallbackType: .checkoutSession`
3. Test the complete flow
4. Deploy backend and app together

### From Checkout Sessions to Payment Links

1. Implement `/api/create_payment_link` endpoint
2. Update configuration: `paymentFallbackType: .paymentLink`
3. Test the simplified flow
4. Deploy backend and app together

---

**Note**: This configuration system provides maximum flexibility while maintaining code simplicity and type safety. Choose the fallback method that best fits your business requirements and user experience goals.
