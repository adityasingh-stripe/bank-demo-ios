# Standalone BankDemo - Stripe Connect Banking Application

A fully independent banking application demonstrating Stripe Connect embedded components, Terminal integration, and dynamic branding capabilities. This version can be opened and run directly in Xcode without requiring the full Stripe iOS workspace.

## Quick Start

### Prerequisites

- **Xcode 16.0+**
- **iOS 18.0+** deployment target
- **Swift 6.0+**
- **Node.js 18+** (for backend server)

### Running the App

1. **Clone this repository**
   ```bash
   git clone <your-repo-url>
   cd StandaloneBankDemo
   ```

2. **Open in Xcode**
   ```bash
   open BankDemo.xcodeproj
   ```
   
3. **Dependencies will be automatically resolved**
   - Xcode will automatically download and build Stripe iOS SDK via Swift Package Manager
   - No manual framework installation required

4. **Start the backend server**
   ```bash
   cd DemoBackend
   npm install
   npm start
   ```

5. **Configure Stripe keys** in `DemoBackend/.env`:
   ```
   STRIPE_SECRET_KEY=sk_test_...
   STRIPE_PUBLISHABLE_KEY=pk_test_...
   ```

6. **Build and run** the iOS app in Xcode

## What's Different from Original

This standalone version has been converted from the original Stripe iOS workspace to be completely independent:

- ✅ **Swift Package Manager**: Uses SPM for all Stripe dependencies
- ✅ **No Workspace Required**: Opens directly as Xcode project
- ✅ **Automatic Dependencies**: All frameworks download automatically
- ✅ **Backend Included**: Complete demo backend server included
- ✅ **Self-Contained**: No external workspace dependencies

## Overview

BankDemo showcases a complete banking application with:

- Stripe Connect embedded components (onboarding, payments, payouts)
- Stripe Terminal for in-person payments
- Dynamic branding and configuration system
- Backend integration for real-time data
- Multi-bank support with single configuration change

## Project Structure

```
StandaloneBankDemo/
├── BankDemo.xcodeproj/          # Xcode project (SPM-enabled)
├── BankDemo/                    # iOS app source code
│   ├── API/                     # Backend integration
│   ├── Configuration/           # Bank branding configs
│   ├── Helpers/                 # Utility classes
│   ├── Settings/                # App settings UI
│   ├── Storage/                 # Data persistence
│   ├── Views/                   # Custom UI components
│   └── Assets.xcassets          # App assets
├── BankDemoUITests/             # UI test suite
├── DemoBackend/                 # Node.js backend server
├── Resources/                   # Additional resources
├── Package.swift                # SPM package definition
└── README.md                    # This file
```

## Core Files Reference

| File                                    | Purpose                                       | Configuration               |
| --------------------------------------- | --------------------------------------------- | --------------------------- |
| `BankConfiguration.swift`               | Bank branding, colors, text, contact info     | Primary configuration file  |
| `MainViewController.swift`              | Main dashboard, UI components, business logic | Core application controller |
| `AppStartViewController.swift`          | App initialization, dynamic branding setup    | Startup configuration       |
| `BankTabBarController.swift`            | Navigation structure, tab management          | UI navigation               |
| `ProfileSelectionViewController.swift`  | User profile selection for onboarding         | User flow management        |
| `PaymentCollectionViewController.swift` | Payment collection interface                  | Payment processing          |
| `TerminalManager.swift`                 | Card reader integration, payment terminal     | Hardware integration        |
| `AppSettings.swift`                     | App preferences, server configuration         | Runtime settings            |
| `API.swift`                             | Backend communication, network requests       | API integration             |
| `BrandingManager.swift`                 | Dynamic logo loading, brand asset management  | Asset management            |
| `ImageLoader.swift`                     | Asynchronous image loading with caching       | Image handling              |

## API Models

| Model                          | Purpose                         | Usage                            |
| ------------------------------ | ------------------------------- | -------------------------------- |
| `AppInfo.swift`                | App configuration from backend  | Dynamic branding data            |
| `AccountSessionResponse.swift` | Stripe account session response | Connect component initialization |
| `APIError.swift`               | API error handling and types    | Error management                 |

## Configuration System

### Bank Configuration

Edit `BankDemo/Configuration/BankConfiguration.swift`:

```swift
// Switch between pre-configured banks
static let current = BankConfiguration.lloyds  // .hsbc, .barclays, .lloyds

// Or create custom configuration
static let customBank = BankConfiguration(
    bankName: "CustomBank",
    bankDisplayName: "Custom Bank",
    businessBankingName: "Custom Business Banking",
    domainName: "custombank.com",
    primaryColor: UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0),
    primaryColorLight: UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.1),
    primaryColorBorder: UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.3),
    logoImageName: "custom-logo",
    currentAccountName: "Custom Business Current Account",
    businessSavingsName: "Custom Business Savings",
    businessCreditCardName: "Custom Business Credit Card",
    supportPhoneNumber: "0800 123 4567",
    supportEmail: "support@custombank.com",
    errorDomain: "CustomBankDemo",
    navigationTitle: "Custom Banking",
    onboardingSubtitle: "Set up your Custom Bank business account",
    getStartedButtonTitle: "Get Started",
    laterButtonTitle: "Later",
    accountCreatedMessage: "Your Custom Bank account has been created!",
    supportMessage: "For support, call 0800 123 4567"
)
```

### App Settings

Configure in `BankDemo/Storage/AppSettings.swift`:

| Setting                 | Purpose                    | Default                 |
| ----------------------- | -------------------------- | ----------------------- |
| `defaultServerBaseURL`  | Backend server URL         | `http://localhost:4242` |
| `selectedServerBaseURL` | Runtime server URL         | User configurable       |
| `currentMerchantId`     | Active merchant account ID | Dynamic from backend    |

### Dynamic Branding

The app supports dynamic branding loaded from backend:

| Component | Source                           | Fallback                   |
| --------- | -------------------------------- | -------------------------- |
| Logo      | Backend `/api/app_info` endpoint | Local asset                |
| Colors    | Backend configuration            | `BankConfiguration` values |
| Icons     | Stripe Files API via backend     | Default system icons       |

## Backend Integration

### Required Endpoints

| Endpoint                     | Method | Purpose                                        | Response        |
| ---------------------------- | ------ | ---------------------------------------------- | --------------- |
| `/api/app_info`              | GET    | App configuration and branding                 | `AppInfo` model |
| `/api/profiles`              | GET    | Available user profiles                        | Profile list    |
| `/api/accounts`              | POST   | Create connected account                       | Account details |
| `/api/account_session`       | POST   | Create account session for embedded components | Session data    |
| `/api/create_payment_intent` | POST   | Create payment intent                          | Payment details |
| `/api/file/:fileId`          | GET    | Serve Stripe uploaded files                    | File stream     |

### Environment Variables

Backend requires:

- `STRIPE_SECRET_KEY`: Stripe secret key
- `STRIPE_PUBLISHABLE_KEY`: Stripe publishable key
- `STRIPE_ACCOUNT_ID`: Connected account ID (optional)

## Stripe Integration

### Connect Components

| Component          | Purpose                                | Implementation         |
| ------------------ | -------------------------------------- | ---------------------- |
| Account Onboarding | User account creation and verification | Embedded web component |
| Payments           | Payment history and management         | Embedded web component |
| Payouts            | Payout management and history          | Embedded web component |
| Account Management | Account settings and profile           | Embedded web component |

### Terminal Integration

| Feature               | Implementation                      | Configuration      |
| --------------------- | ----------------------------------- | ------------------ |
| Card Reader Discovery | `TerminalManager.discoverReaders()` | Automatic          |
| Payment Collection    | `TerminalManager.collectPayment()`  | Amount + customer  |
| Reader Connection     | Bluetooth and USB support           | Hardware dependent |

## UI Customization

### Navigation

| Component      | Customization                 | Location                  |
| -------------- | ----------------------------- | ------------------------- |
| Navigation Bar | Colors, title, buttons        | `setupBankBranding()`     |
| Tab Bar        | Colors, icons, labels         | `BankTabBarController`    |
| User Icon      | Style, visibility, background | `setupMobileNavigation()` |

### Colors

| Color Type           | Usage                         | Configuration             |
| -------------------- | ----------------------------- | ------------------------- |
| `primaryColor`       | Buttons, highlights, branding | `BankConfiguration`       |
| `primaryColorLight`  | Backgrounds, subtle elements  | Auto-generated with alpha |
| `primaryColorBorder` | Borders, separators           | Auto-generated with alpha |

### Assets

| Asset Type    | Location                                          | Specifications        |
| ------------- | ------------------------------------------------- | --------------------- |
| Bank Logo     | `Assets.xcassets/bank-logo-placeholder.imageset/` | 24x24pt (72x72px @3x) |
| App Icon      | `Assets.xcassets/AppIcon.appiconset/`             | Standard iOS sizes    |
| Launch Screen | `Base.lproj/LaunchScreen.storyboard`              | Storyboard-based      |

## Build Configuration

### Requirements

- iOS 18.0+
- Xcode 16.0+
- Swift 6.0+
- Stripe iOS SDK 24.17.0+

### Build Commands

```bash
# Build for simulator (from StandaloneBankDemo directory)
xcodebuild -project BankDemo.xcodeproj -scheme BankDemo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15'

# Or using Xcode
# 1. Open BankDemo.xcodeproj
# 2. Select BankDemo scheme
# 3. Choose target device
# 4. Build and run
```

### Scheme Configuration

| Configuration | Purpose     | Settings                       |
| ------------- | ----------- | ------------------------------ |
| Debug         | Development | Debug symbols, logging enabled |
| Release       | Production  | Optimized, minimal logging     |

## Testing

### UI Tests

Location: `BankDemoUITests/`

- End-to-end user flows
- Payment processing tests
- Navigation and UI interaction tests

### Running Tests

```bash
xcodebuild test -project BankDemo.xcodeproj -scheme BankDemo -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Architecture Patterns

### Configuration-Driven Design

Single source of truth for bank-specific configurations enables:

- Runtime bank switching
- White-label deployment
- Consistent branding application

### Component-Based UI

Modular UI components for:

- Reusable interface elements
- Consistent styling
- Easy maintenance

### Protocol-Oriented Programming

Extensible architecture supporting:

- New bank integrations
- Custom payment flows
- Additional features

## Development Workflow

### Adding New Banks

1. Create configuration in `BankConfiguration.swift`
2. Add logo assets to `Assets.xcassets`
3. Update `BankConfiguration.current`
4. Test branding application

### Customizing UI

1. Modify colors in `BankConfiguration`
2. Update assets if needed
3. Customize text strings
4. Test across different configurations

### Backend Integration

1. Configure server endpoints
2. Update API models if needed
3. Test data flow
4. Verify error handling

## Troubleshooting

### Common Issues

| Issue                           | Cause                              | Solution                                  |
| ------------------------------- | ---------------------------------- | ----------------------------------------- |
| White user icon not visible     | Navigation bar tint color override | Check `setupBankBranding()` method        |
| Backend connection failed       | Server not running or wrong URL    | Verify `AppSettings.defaultServerBaseURL` |
| Embedded components not loading | Missing account session            | Check `/api/account_session` endpoint     |
| Terminal reader not connecting  | Bluetooth permissions or hardware  | Check device permissions and hardware     |

### Debug Information

Enable detailed logging in `API.swift` and check console output for:

- Network request/response details
- JSON parsing errors
- Authentication issues
- Component initialization status

## Security Considerations

- Never commit Stripe secret keys to version control
- Use environment variables for sensitive configuration
- Implement proper error handling for API failures
- Validate all user inputs before processing
- Use HTTPS for all backend communications

## Performance Optimization

- Image caching implemented in `ImageLoader`
- Lazy loading of embedded components
- Efficient UI updates with `BrandingManager`
- Background thread processing for API calls
