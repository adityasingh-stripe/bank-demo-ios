//
//  BankConfiguration.swift
//  BankDemo
//
//  Configuration file for bank-specific branding and settings.
//  Change BankConfiguration.current to switch between different banks.
//

import UIKit
import SwiftUI

// MARK: - Bank Configuration Structure
struct BankConfiguration {
    
    // MARK: - Bank Information
    let bankName: String
    let bankDisplayName: String
    let businessBankingName: String
    let domainName: String
    let errorDomain: String
    
    // MARK: - Visual Branding
    let primaryColor: UIColor
    let primaryColorLight: UIColor
    let primaryColorBorder: UIColor
    let logoImageName: String
    
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
    
    // MARK: - Computed Properties
    var primaryColorSwiftUI: Color {
        return Color(primaryColor)
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
}

// MARK: - Predefined Bank Configurations
extension BankConfiguration {
    
    static let hsbc = BankConfiguration(
        bankName: "HSBC",
        bankDisplayName: "HSBC",
        businessBankingName: "HSBC Business Banking",
        domainName: "hsbc.co.uk",
        errorDomain: "HSBCDemo",
        primaryColor: UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1.0),
        primaryColorLight: UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 0.1),
        primaryColorBorder: UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 0.3),
        logoImageName: "bank-logo-placeholder",
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
        supportMessage: "For support, call 03456 000 000 or email business.support@hsbc.co.uk"
    )
    
    static let lloyds = BankConfiguration(
        bankName: "Lloyds",
        bankDisplayName: "Lloyds Bank",
        businessBankingName: "Lloyds Business Banking",
        domainName: "lloydsbank.com",
        errorDomain: "LloydsDemo",
        primaryColor: UIColor(red: 0/255, green: 98/255, blue: 65/255, alpha: 1.0),
        primaryColorLight: UIColor(red: 0/255, green: 98/255, blue: 65/255, alpha: 0.1),
        primaryColorBorder: UIColor(red: 0/255, green: 98/255, blue: 65/255, alpha: 0.3),
        logoImageName: "bank-logo-placeholder",
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
        supportMessage: "For support, call 0345 072 5555 or email business.support@lloydsbank.com"
    )
    
    static let barclays = BankConfiguration(
        bankName: "Barclays",
        bankDisplayName: "Barclays",
        businessBankingName: "Barclays Business Banking",
        domainName: "barclays.co.uk",
        errorDomain: "BarclaysDemo",
        primaryColor: UIColor(red: 0/255, green: 174/255, blue: 239/255, alpha: 1.0),
        primaryColorLight: UIColor(red: 0/255, green: 174/255, blue: 239/255, alpha: 0.1),
        primaryColorBorder: UIColor(red: 0/255, green: 174/255, blue: 239/255, alpha: 0.3),
        logoImageName: "bank-logo-placeholder",
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
        supportMessage: "For support, call 0345 734 5345 or email business.support@barclays.co.uk"
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
} 