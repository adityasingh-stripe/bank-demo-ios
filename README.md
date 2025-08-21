# BankDemo iOS App

A professional banking demo app showcasing Stripe Terminal and Connect integration with customizable bank branding.

## Features

- **Stripe Terminal Integration**: In-person payments using Tap to Pay on iPhone
- **Stripe Connect**: Embedded onboarding and account management
- **Multi-Bank Theming**: Easy switching between bank brands (HSBC, Lloyds, Barclays)
- **Payment Failure Recovery**: Professional checkout session and payment link flow with native QR code generation
- **Native QR Code Generation**: Uses Apple's Core Image `CIFilter.qrCodeGenerator()` for high-quality QR codes
- **Professional UI**: Banking-grade design with reusable theme system
- **Comprehensive Logging**: Educational print statements showing SDK function calls and API interactions

## Quick Start

### Prerequisites

- Xcode 15.0+
- iOS 17.0+
- Stripe Account with Terminal and Connect enabled

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/adityasingh-stripe/bank-demo-ios.git
   cd bank-demo-ios
   ```

2. **Open in Xcode**

   ```bash
   open BankDemo.xcodeproj
   ```

3. (Optional) **Start Backend**

   You can skip this step if you wish to use the existing demo backend.

   This app requires a Node.js backend server. You can use the dedicated backend repository:

   ```bash
   git clone https://github.com/adityasingh-stripe/stripe-demo-backend.git
   cd stripe-demo-backend
   npm install
   npm start
   ```

   See the [Backend Repository](https://github.com/adityasingh-stripe/stripe-demo-backend) for complete setup and deployment instructions.

4. **Configure Backend URL**

   - Update `BankDemo/Storage/AppSettings.swift` if needed to set your backend URL
   - The app by default uses `https://stripe-demo-backend-ecru.vercel.app` for backend operations. You can also use your local backend e.g. `http://localhost:4242`

5. **Build and Run**
   - Select your target device (e.g. iPhone 16 pro simulator)
   - Build and run the project

## Bank Theming System

### Switching Banks

Change the active bank in `BankDemo/Configuration/BankConfiguration.swift`:

```swift
extension BankConfiguration {
    // Change this line to switch between different banks
    static let current = BankConfiguration.hsbc  // or .lloyds, .barclays
}
```

### Available Banks

- **HSBC**: Red theme (`#C92B23`)
- **Lloyds**: Green theme (`#006241`)
- **Barclays**: Blue theme (`#00AEEF`)

### Adding New Banks

1. **Add Bank Configuration**

   ```swift
   static let yourBank = BankConfiguration(
       bankName: "YourBank",
       bankDisplayName: "Your Bank",
       businessBankingName: "Your Bank Business",
       domainName: "yourbank.com",
       errorDomain: "YourBankDemo",
       primaryColor: UIColor(red: 255/255, green: 0/255, blue: 0/255, alpha: 1.0),
       primaryColorLight: UIColor(red: 255/255, green: 0/255, blue: 0/255, alpha: 0.1),
       primaryColorBorder: UIColor(red: 255/255, green: 0/255, blue: 0/255, alpha: 0.3),
       // ... other properties
   )
   ```

2. **Update Current Configuration**
   ```swift
   static let current = BankConfiguration.yourBank
   ```

### Theme Properties

The theme system includes:

- **Colors**: Primary, success, error, warning colors
- **Typography**: Font sizes for titles, headlines, body text, captions
- **Spacing**: Default, large, and small spacing values
- **UI Components**: Button heights, corner radii, card styling
- **Messages**: Bank-specific text and error messages

### Using Theme in Code

```swift
class YourViewController: UIViewController {
    private let theme = BankConfiguration.current

    private func setupUI() {
        // Use theme colors
        view.backgroundColor = theme.primaryColor

        // Use theme typography
        let titleLabel = theme.titleLabel(text: "Your Title")

        // Use theme components
        let button = theme.styledButton(title: "Action", style: .primary)

        // Use theme spacing
        stackView.spacing = theme.defaultSpacing
    }
}
```

## Architecture

### Key Components

- **BankConfiguration**: Centralized theming and branding system
- **TerminalManager**: Stripe Terminal SDK integration
- **PaymentCollectionViewController**: Main payment flow
- **CheckoutSessionViewController**: Online payment fallback
- **QRCodeViewController**: QR code generation for cross-device payments

### Payment Flow

1. **In-Person Payment**: Tap to Pay on iPhone using Terminal SDK
2. **Payment Failure**: Professional failure screen with options
3. **Checkout Session**: Creates Stripe Checkout for online payment
4. **QR Code**: Generates QR code for payment on another device

### QR Code Implementation

The app uses Apple's native **Core Image framework** for QR code generation for payment links / checkout sessions:

```swift
import CoreImage.CIFilterBuiltins

private func generateQRCode(from string: String) -> UIImage? {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()

    filter.message = Data(string.utf8)

    if let outputImage = filter.outputImage {
        // Scale up the QR code for better quality
        let scaleX = 240 / outputImage.extent.size.width
        let scaleY = 240 / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
            return UIImage(cgImage: cgImage)
        }
    }
    return nil
}
```

Reference: [Apple Developer Documentation - CIFilter.qrCodeGenerator()](https://developer.apple.com/documentation/coreimage/cifilter/3228262-qrcodegenerator)

## Backend Integration

This iOS app requires a Node.js backend server to handle Stripe API operations and serve payment success pages.

### Backend Repository

The backend is maintained in a separate repository: **[stripe-demo-backend](https://github.com/adityasingh-stripe/stripe-demo-backend)**

## Testing

### Payment Testing

- **Tap to Pay Testing**: Use Stripe test cards for in-person payment testing
- **Payment Failure Recovery**: Test failure scenarios and checkout session flow
- **QR Code Functionality**: Verify native QR code generation and cross-device payments
- **Customer Management**: Test customer creation and selection
- **Multi-Bank Themes**: Switch between bank configurations (HSBC, Lloyds, Barclays)
- **Success Page Branding**: Verify actual business names appear on success pages

### Device Testing

- Test on multiple iPhone models
- Verify Tap to Pay functionality
- Test in different network conditions

## Troubleshooting

### Debug Logging

The app includes comprehensive logging for debugging:

- Terminal SDK operations
- API calls and responses
- Payment flow events
- UI state changes

## Contributing

### Code Style

- Use the established theme system for all UI components
- Follow existing logging patterns
- Maintain bank-agnostic code structure

### Adding Features

1. Use `BankConfiguration.current` for all styling
2. Add comprehensive logging
3. Test with all bank themes
4. Update documentation

## Support

For technical support or questions:

- Check the troubleshooting section
- Review Stripe Terminal documentation
- Contact @adityasingh on slack

---

**Note**: This app is for demonstration purposes. Ensure proper security measures and compliance requirements for production use.
