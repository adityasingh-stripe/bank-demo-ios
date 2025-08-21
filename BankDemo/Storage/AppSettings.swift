import Foundation

@MainActor
final class AppSettings: @unchecked Sendable {
    enum  Constants {
        // Local backend for bank demo
        static let defaultServerBaseURL = "http://localhost:4242" // http://localhost:4242 or https://stripe-demo-backend-ecru.vercel.app    
        static let serverBaseURLKey = "ServerBaseURL"
        static let appearanceIdKey = "AppearanceId"

        static let selectedMerchantKey = "SelectedMerchant"

        static let presentationIsModal = "PresentationIsModal"
        static let disableEmbedInNavbar = "DisableEmbedInNavbar"
        static let embedInTabbar = "EmbedInTabbar"

        // MARK: Onboarding
        static let onboardingTermsOfServiceURL = "OnboardingTermsOfServiceURL"
        static let onboardingrecipientTermsOfServiceString = "OnboardingrecipientTermsOfServiceString"
        static let onboardingPrivacyPolicyString = "OnboardingPrivacyPolicyString"

        static let onboardingSkipTermsOfService = "OnboardingSkipTermsOfService"
        static let onboardingFieldOption = "OnboardingFieldOption"
        static let onboardingFutureRequirements = "OnboardingFutureRequirements"

    }

    static let shared = AppSettings()

    let defaults = UserDefaults.standard

    var selectedServerBaseURL: String {
        get {
            defaults.string(forKey: Constants.serverBaseURLKey) ??
            Constants.defaultServerBaseURL
        }
        set {
            defaults.setValue(newValue, forKey: Constants.serverBaseURLKey)
        }
    }

    var appearanceId: String? {
        get {
            defaults.string(forKey: Constants.appearanceIdKey)
        }
        set {
            defaults.setValue(newValue, forKey: Constants.appearanceIdKey)
        }
    }

    var onboardingSettings: OnboardingSettings {
        get {
            let settings = OnboardingSettings(
                fullTermsOfServiceString: defaults.string(forKey: Constants.onboardingTermsOfServiceURL),
                recipientTermsOfServiceString: defaults.string(forKey: Constants.onboardingrecipientTermsOfServiceString),
                privacyPolicyString: defaults.string(forKey: Constants.onboardingPrivacyPolicyString),
                skipTermsOfService: .init(rawValue: defaults.string(forKey: Constants.onboardingSkipTermsOfService)) ?? .true,
                fieldOption: .init(rawValue: defaults.string(forKey: Constants.onboardingFieldOption)) ?? .eventuallyDue,
                futureRequirement: .init(rawValue: defaults.string(forKey: Constants.onboardingFutureRequirements)) ?? .include
            )
            return settings
        }
        set {
            defaults.setValue(newValue.fullTermsOfServiceString, forKey: Constants.onboardingTermsOfServiceURL)
            defaults.setValue(newValue.recipientTermsOfServiceString, forKey: Constants.onboardingrecipientTermsOfServiceString)
            defaults.setValue(newValue.privacyPolicyString, forKey: Constants.onboardingPrivacyPolicyString)

            defaults.setValue(newValue.skipTermsOfService.rawValue, forKey: Constants.onboardingSkipTermsOfService)
            defaults.setValue(newValue.fieldOption.rawValue, forKey: Constants.onboardingFieldOption)
            defaults.setValue(newValue.futureRequirement.rawValue, forKey: Constants.onboardingFutureRequirements)
            defaults.synchronize()
        }
    }

    var presentationSettings: PresentationSettings {
        get {
            .init(
                presentationStyleIsPush: !defaults.bool(forKey: Constants.presentationIsModal),
                embedInTabBar: defaults.bool(forKey: Constants.embedInTabbar),
                embedInNavBar: !defaults.bool(forKey: Constants.disableEmbedInNavbar)
            )
        }
        set {
            defaults.set(!newValue.presentationStyleIsPush, forKey: Constants.presentationIsModal)
            defaults.set(newValue.embedInTabBar, forKey: Constants.embedInTabbar)
            defaults.set(!newValue.embedInNavBar, forKey: Constants.disableEmbedInNavbar)
        }
    }

    // Merchant ID is now managed by AppDataManager.shared.currentAccountId
    // These functions are no longer needed
}

private extension UserDefaults {
    func string(forKey defaultName: String, defaultValue: String = "") -> String {
        self.string(forKey: defaultName) ?? defaultValue
    }
}
