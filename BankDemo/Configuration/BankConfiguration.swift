//
//  BankConfiguration.swift
//  BankDemo
//
//  Configuration file for bank-specific branding and settings.
//  Change BankConfiguration.current to switch between different banks.
//

import UIKit
import SwiftUI

// MARK: - Payment Fallback Configuration
enum PaymentFallbackType {
    case checkoutSession    // Use Stripe Checkout Sessions (recommended)
    case paymentLink       // Use Stripe Payment Links (legacy)
    
    var displayName: String {
        switch self {
        case .checkoutSession:
            return "Online Checkout"
        case .paymentLink:
            return "Payment Link"
        }
    }
    
    var subtitle: String {
        switch self {
        case .checkoutSession:
            return "Complete payment securely online"
        case .paymentLink:
            return "Share a secure payment link"
        }
    }
    
    var systemIcon: String {
        switch self {
        case .checkoutSession:
            return "globe"
        case .paymentLink:
            return "link"
        }
    }
}

// MARK: - Bank Configuration Structure
struct BankConfiguration {
    
    // MARK: - Bank Information
    let bankName: String
    let bankDisplayName: String
    let businessBankingName: String
    let domainName: String
    let errorDomain: String
    
    // MARK: - Payment Configuration
    let paymentFallbackType: PaymentFallbackType
    
    // MARK: - Visual Branding
    let primaryColor: UIColor
    let primaryColorLight: UIColor
    let primaryColorBorder: UIColor
    let logoImageName: String
    
    // MARK: - Payment Flow Colors
    let successColor: UIColor
    let errorColor: UIColor
    let warningColor: UIColor
    let amountColor: UIColor
    let buttonCornerRadius: CGFloat
    let cardCornerRadius: CGFloat
    
    // MARK: - Typography
    let titleFontSize: CGFloat
    let headlineFontSize: CGFloat
    let bodyFontSize: CGFloat
    let captionFontSize: CGFloat
    let amountFontSize: CGFloat
    
    // MARK: - Spacing
    let defaultSpacing: CGFloat
    let largeSpacing: CGFloat
    let smallSpacing: CGFloat
    let buttonHeight: CGFloat
    
    // MARK: - Account Information
    let currentAccountName: String
    let businessSavingsName: String
    let businessCreditCardName: String
    
    // MARK: - Contact Information
    let supportPhoneNumber: String
    let supportEmail: String
    
    // MARK: - UI Text and Messages
    let navigationTitle: String
    let onboardingSubtitle: String
    let getStartedButtonTitle: String
    let laterButtonTitle: String
    let accountCreatedMessage: String
    let supportMessage: String
    
    // MARK: - Payment Flow Messages
    let paymentFailedTitle: String
    let paymentSuccessTitle: String
    let paymentSessionTitle: String
    let qrCodeTitle: String
    let qrCodeInstructions: String
    
    // MARK: - Computed Properties
    var primaryColorSwiftUI: Color {
        return Color(primaryColor)
    }
    
    var successColorSwiftUI: Color {
        return Color(successColor)
    }
    
    var errorColorSwiftUI: Color {
        return Color(errorColor)
    }
    
    // MARK: - Helper Methods
    func accountCreatedMessage(for profileName: String) -> String {
        return "Great! Your \(bankDisplayName) business account for \(profileName) has been created. You can now start accepting payments."
    }
    
    func transactionIconColor(for type: String) -> UIColor {
        switch type.lowercased() {
        case bankName.lowercased():
            return primaryColor
        default:
            return UIColor.systemBlue
        }
    }
    
    func transactionDisplayName(for type: String) -> String {
        switch type.lowercased() {
        case bankName.lowercased():
            return "\(bankDisplayName) Payout"
        default:
            return type.uppercased()
        }
    }
    
    // MARK: - UI Component Helpers
    func styledButton(title: String, style: ButtonStyle = .primary) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: bodyFontSize, weight: .semibold)
        button.layer.cornerRadius = buttonCornerRadius
        button.translatesAutoresizingMaskIntoConstraints = false
        
        switch style {
        case .primary:
            button.backgroundColor = primaryColor
            button.setTitleColor(.white, for: .normal)
        case .secondary:
            button.backgroundColor = .clear
            button.setTitleColor(primaryColor, for: .normal)
            button.layer.borderWidth = 1
            button.layer.borderColor = primaryColor.cgColor
        case .success:
            button.backgroundColor = successColor
            button.setTitleColor(.white, for: .normal)
        case .danger:
            button.backgroundColor = errorColor
            button.setTitleColor(.white, for: .normal)
        }
        
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: buttonHeight)
        ])
        
        return button
    }
    
    func titleLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: titleFontSize, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    func headlineLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: headlineFontSize, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    func bodyLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: bodyFontSize, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    func amountLabel(amount: Double, currency: String = "£") -> UILabel {
        let label = UILabel()
        label.text = "\(currency)\(String(format: "%.2f", amount))"
        label.font = UIFont.systemFont(ofSize: amountFontSize, weight: .light)
        label.textColor = amountColor
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    func cardView() -> UIView {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = cardCornerRadius
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    
    enum ButtonStyle {
        case primary, secondary, success, danger
    }
}

// MARK: - Predefined Bank Configurations
extension BankConfiguration {
    
    static let hsbc = BankConfiguration(
        bankName: "HSBC",
        bankDisplayName: "HSBC",
        businessBankingName: "HSBC Business Banking",
        domainName: "hsbc.co.uk",
        errorDomain: "HSBCDemo",
        paymentFallbackType: .checkoutSession, // .paymentLink or .checkoutSession
        primaryColor: UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1.0),
        primaryColorLight: UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 0.1),
        primaryColorBorder: UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 0.3),
        logoImageName: "bank-logo-placeholder",
        successColor: UIColor.systemGreen,
        errorColor: UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1.0),
        warningColor: UIColor.systemOrange,
        amountColor: UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1.0),
        buttonCornerRadius: 8,
        cardCornerRadius: 12,
        titleFontSize: 28,
        headlineFontSize: 24,
        bodyFontSize: 17,
        captionFontSize: 14,
        amountFontSize: 36,
        defaultSpacing: 16,
        largeSpacing: 32,
        smallSpacing: 8,
        buttonHeight: 52,
        currentAccountName: "Business Current Account",
        businessSavingsName: "Business Savings",
        businessCreditCardName: "Business Credit Card",
        supportPhoneNumber: "03456 000 000",
        supportEmail: "business.support@hsbc.co.uk",
        navigationTitle: "HSBC Business",
        onboardingSubtitle: "Set up your HSBC business account to start accepting payments",
        getStartedButtonTitle: "Get Started",
        laterButtonTitle: "Later",
        accountCreatedMessage: "Your HSBC business account has been successfully created!",
        supportMessage: "For support, call 03456 000 000 or email business.support@hsbc.co.uk",
        paymentFailedTitle: "Payment Failed",
        paymentSuccessTitle: "Payment Successful",
        paymentSessionTitle: "Payment Session Ready",
        qrCodeTitle: "Scan to Complete Payment",
        qrCodeInstructions: "Use your phone's camera or payment app to scan this code and complete your payment securely"
    )
    
    static let lloyds = BankConfiguration(
        bankName: "Lloyds",
        bankDisplayName: "Lloyds Bank",
        businessBankingName: "Lloyds Business Banking",
        domainName: "lloydsbank.com",
        errorDomain: "LloydsDemo",
        paymentFallbackType: .checkoutSession,
        primaryColor: UIColor(red: 0/255, green: 98/255, blue: 65/255, alpha: 1.0),
        primaryColorLight: UIColor(red: 0/255, green: 98/255, blue: 65/255, alpha: 0.1),
        primaryColorBorder: UIColor(red: 0/255, green: 98/255, blue: 65/255, alpha: 0.3),
        logoImageName: "bank-logo-placeholder",
        successColor: UIColor(red: 0/255, green: 98/255, blue: 65/255, alpha: 1.0),
        errorColor: UIColor.systemRed,
        warningColor: UIColor.systemOrange,
        amountColor: UIColor(red: 0/255, green: 98/255, blue: 65/255, alpha: 1.0),
        buttonCornerRadius: 8,
        cardCornerRadius: 12,
        titleFontSize: 28,
        headlineFontSize: 24,
        bodyFontSize: 17,
        captionFontSize: 14,
        amountFontSize: 36,
        defaultSpacing: 16,
        largeSpacing: 32,
        smallSpacing: 8,
        buttonHeight: 52,
        currentAccountName: "Business Current Account",
        businessSavingsName: "Business Savings",
        businessCreditCardName: "Business Credit Card",
        supportPhoneNumber: "0345 072 5555",
        supportEmail: "business.support@lloydsbank.com",
        navigationTitle: "Lloyds Business",
        onboardingSubtitle: "Set up your Lloyds business account to start accepting payments",
        getStartedButtonTitle: "Get Started",
        laterButtonTitle: "Later",
        accountCreatedMessage: "Your Lloyds business account has been successfully created!",
        supportMessage: "For support, call 0345 072 5555 or email business.support@lloydsbank.com",
        paymentFailedTitle: "Payment Failed",
        paymentSuccessTitle: "Payment Successful",
        paymentSessionTitle: "Payment Session Ready",
        qrCodeTitle: "Scan to Complete Payment",
        qrCodeInstructions: "Use your phone's camera or payment app to scan this code and complete your payment securely"
    )
    
    static let barclays = BankConfiguration(
        bankName: "Barclays",
        bankDisplayName: "Barclays",
        businessBankingName: "Barclays Business Banking",
        domainName: "barclays.co.uk",
        errorDomain: "BarclaysDemo",
        paymentFallbackType: .checkoutSession,
        primaryColor: UIColor(red: 0/255, green: 174/255, blue: 239/255, alpha: 1.0),
        primaryColorLight: UIColor(red: 0/255, green: 174/255, blue: 239/255, alpha: 0.1),
        primaryColorBorder: UIColor(red: 0/255, green: 174/255, blue: 239/255, alpha: 0.3),
        logoImageName: "bank-logo-placeholder",
        successColor: UIColor.systemGreen,
        errorColor: UIColor.systemRed,
        warningColor: UIColor.systemOrange,
        amountColor: UIColor(red: 0/255, green: 174/255, blue: 239/255, alpha: 1.0),
        buttonCornerRadius: 8,
        cardCornerRadius: 12,
        titleFontSize: 28,
        headlineFontSize: 24,
        bodyFontSize: 17,
        captionFontSize: 14,
        amountFontSize: 36,
        defaultSpacing: 16,
        largeSpacing: 32,
        smallSpacing: 8,
        buttonHeight: 52,
        currentAccountName: "Business Current Account",
        businessSavingsName: "Business Savings",
        businessCreditCardName: "Business Credit Card",
        supportPhoneNumber: "0345 734 5345",
        supportEmail: "business.support@barclays.co.uk",
        navigationTitle: "Barclays Business",
        onboardingSubtitle: "Set up your Barclays business account to start accepting payments",
        getStartedButtonTitle: "Get Started",
        laterButtonTitle: "Later",
        accountCreatedMessage: "Your Barclays business account has been successfully created!",
        supportMessage: "For support, call 0345 734 5345 or email business.support@barclays.co.uk",
        paymentFailedTitle: "Payment Failed",
        paymentSuccessTitle: "Payment Successful",
        paymentSessionTitle: "Payment Session Ready",
        qrCodeTitle: "Scan to Complete Payment",
        qrCodeInstructions: "Use your phone's camera or payment app to scan this code and complete your payment securely"
    )
}

// MARK: - Current Configuration
extension BankConfiguration {
    // Change this line to switch between different banks
    static let current = BankConfiguration.hsbc
}

// MARK: - Convenience Extensions
extension Color {
    static var bankPrimary: Color {
        return BankConfiguration.current.primaryColorSwiftUI
    }
    
    static var bankSuccess: Color {
        return BankConfiguration.current.successColorSwiftUI
    }
    
    static var bankError: Color {
        return BankConfiguration.current.errorColorSwiftUI
    }
}

extension UIColor {
    static var bankPrimary: UIColor {
        return BankConfiguration.current.primaryColor
    }
    
    static var bankPrimaryLight: UIColor {
        return BankConfiguration.current.primaryColorLight
    }
    
    static var bankPrimaryBorder: UIColor {
        return BankConfiguration.current.primaryColorBorder
    }
    
    static var bankSuccess: UIColor {
        return BankConfiguration.current.successColor
    }
    
    static var bankError: UIColor {
        return BankConfiguration.current.errorColor
    }
    
    static var bankWarning: UIColor {
        return BankConfiguration.current.warningColor
    }
    
    static var bankAmount: UIColor {
        return BankConfiguration.current.amountColor
    }
} 