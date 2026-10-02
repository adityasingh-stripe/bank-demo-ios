import UIKit
import SwiftUI
import Combine
@_spi(DashboardOnly) import StripeConnect

class BankTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
    }
    
    private func setupTabs() {
        // Home/Dashboard tab - Keep original MainViewController with all existing functionality
        let homeVC = MainViewController()
        let homeNav = UINavigationController(rootViewController: homeVC)
        homeNav.tabBarItem = UITabBarItem(
            title: "Home",
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )
        
        // Payments tab - Stripe embedded payments component
        let paymentsVC = PaymentsViewController()
        let paymentsNav = UINavigationController(rootViewController: paymentsVC)
        paymentsNav.tabBarItem = UITabBarItem(
            title: "Payments",
            image: UIImage(systemName: "creditcard"),
            selectedImage: UIImage(systemName: "creditcard.fill")
        )
        
        // Payouts tab - Stripe embedded payouts component
        let payoutsVC = PayoutsViewController()
        let payoutsNav = UINavigationController(rootViewController: payoutsVC)
        payoutsNav.tabBarItem = UITabBarItem(
            title: "Payouts",
            image: UIImage(systemName: "arrow.down.circle"),
            selectedImage: UIImage(systemName: "arrow.down.circle.fill")
        )
        
        // Terminal tab - hardware ordering and reader registration
        let terminalVC = TerminalViewController()
        let terminalNav = UINavigationController(rootViewController: terminalVC)
        terminalNav.tabBarItem = UITabBarItem(
            title: "Terminal",
            image: UIImage(systemName: "creditcard.and.123"),
            selectedImage: UIImage(systemName: "creditcard.and.123")
        )
        
        // Support tab
        let supportVC = SupportViewController()
        let supportNav = UINavigationController(rootViewController: supportVC)
        supportNav.tabBarItem = UITabBarItem(
            title: "Support",
            image: UIImage(systemName: "questionmark.circle"),
            selectedImage: UIImage(systemName: "questionmark.circle.fill")
        )
        
        viewControllers = [homeNav, paymentsNav, payoutsNav, terminalNav, supportNav]
    }
    
    private func setupAppearance() {
        // Bank primary color scheme
        let bankPrimary = BankConfiguration.current.primaryColor
        
        tabBar.tintColor = bankPrimary
        tabBar.unselectedItemTintColor = .gray
        tabBar.backgroundColor = .white
        tabBar.barTintColor = .white
        
        // Add subtle border
        tabBar.layer.borderWidth = 0.5
        tabBar.layer.borderColor = UIColor.lightGray.cgColor
    }
}

// MARK: - Individual Tab View Controllers

class PaymentsViewController: UIViewController {
    
    // Shared embedded component manager with bank branding
    private lazy var embeddedComponentManager: EmbeddedComponentManager = {
        return .init(
            appearance: AppSettings.shared.appearanceInfo.appearance,
            fetchClientSecret: { [weak self] in
                // Use the same backend integration as MainViewController
                guard let accountId = AppDataManager.shared.currentAccountId else {
                    print("No account ID available for payments")
                    return nil
                }
                do {
                    return try await self?.fetchAccountSession(accountId: accountId)
                } catch {
                    print("Failed to fetch account session for payments: \(error)")
                    return nil
                }
            })
    }()
    
    private var paymentsEmbeddedVC: StripeConnect.PaymentsViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Payments"
        view.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        
        setupBankBranding()
        
        // Listen for test data creation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshPayments),
            name: NSNotification.Name("TestDataCreated"),
            object: nil
        )
        
        // Listen for payment completion to refresh embedded components
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshPayments),
            name: NSNotification.Name("PaymentCompleted"),
            object: nil
        )
        
        // Listen for embedded component refresh requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshPayments),
            name: NSNotification.Name("RefreshEmbeddedComponents"),
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadEmbeddedPaymentsComponent()
    }
    
    @objc private func refreshPayments() {
        print("INFO: Refreshing embedded payments component")
        // Refresh the payments component when test data is created or payment completed
        DispatchQueue.main.async { [weak self] in
            self?.loadEmbeddedPaymentsComponent()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupBankBranding() {
        // Apply bank branding
        navigationController?.navigationBar.tintColor = BankConfiguration.current.primaryColor
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: BankConfiguration.current.primaryColor
        ]
    }
    
    private func loadEmbeddedPaymentsComponent() {
        // Check if we have an account ID
        guard AppDataManager.shared.currentAccountId != nil else {
            showSetupRequired()
            return
        }
        
        // Create embedded payments component
        let paymentsVC = embeddedComponentManager.createPaymentsViewController()
        paymentsVC.delegate = self
        paymentsEmbeddedVC = paymentsVC
        
        // Add as child view controller
        addChild(paymentsVC)
        view.addSubview(paymentsVC.view)
        paymentsVC.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            paymentsVC.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            paymentsVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            paymentsVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            paymentsVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        paymentsVC.didMove(toParent: self)
    }
    
    private func showSetupRequired() {
        let setupLabel = UILabel()
        setupLabel.text = "Account setup required.\nPlease complete onboarding from the Home tab first."
        setupLabel.textAlignment = .center
        setupLabel.numberOfLines = 0
        setupLabel.font = UIFont.systemFont(ofSize: 16)
        setupLabel.textColor = .darkGray
        setupLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let setupButton = UIButton(type: .system)
        setupButton.setTitle("Go to Home", for: .normal)
        setupButton.backgroundColor = BankConfiguration.current.primaryColor
        setupButton.setTitleColor(.white, for: .normal)
        setupButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        setupButton.layer.cornerRadius = 8
        setupButton.addTarget(self, action: #selector(goToHomeTab), for: .touchUpInside)
        setupButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(setupLabel)
        view.addSubview(setupButton)
        
        NSLayoutConstraint.activate([
            setupLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            setupLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            setupLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            setupLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            setupButton.topAnchor.constraint(equalTo: setupLabel.bottomAnchor, constant: 20),
            setupButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            setupButton.heightAnchor.constraint(equalToConstant: 44),
            setupButton.widthAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    @objc private func goToHomeTab() {
        tabBarController?.selectedIndex = 0
    }
    
    private func fetchAccountSession(accountId: String) async throws -> String? {
        // Use the same backend integration as MainViewController
        let backendBaseURL = AppSettings.shared.selectedServerBaseURL
        
        guard let url = URL(string: "\(backendBaseURL)/api/account_session") else {
            throw NSError(domain: BankConfiguration.current.errorDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid backend URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accountId, forHTTPHeaderField: "account")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: BankConfiguration.current.errorDomain, code: 2, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["clientSecret"] as? String
    }
}

// MARK: - PaymentsViewControllerDelegate
extension PaymentsViewController: PaymentsViewControllerDelegate {
    nonisolated func payments(_ payments: StripeConnect.PaymentsViewController, didFailLoadWithError error: Error) {
        print("Payments failed to load: \(error)")
        
        Task { @MainActor in
            let alert = UIAlertController(
                title: "Error Loading Payments",
                message: "Unable to load payments data. Please check your connection and try again.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}

class PayoutsViewController: UIViewController {
    
    // Shared embedded component manager with bank branding
    private lazy var embeddedComponentManager: EmbeddedComponentManager = {
        return .init(
            appearance: AppSettings.shared.appearanceInfo.appearance,
            fetchClientSecret: { [weak self] in
                guard let accountId = AppDataManager.shared.currentAccountId else {
                    print("No account ID available for payouts")
                    return nil
                }
                do {
                    return try await self?.fetchAccountSession(accountId: accountId)
                } catch {
                    print("Failed to fetch account session for payouts: \(error)")
                    return nil
                }
            })
    }()
    
    private var payoutsEmbeddedVC: StripeConnect.PayoutsViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Payouts"
        view.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        
        setupBankBranding()
        
        // Listen for test data creation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshPayouts),
            name: NSNotification.Name("TestDataCreated"),
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadEmbeddedPayoutsComponent()
    }
    
    @objc private func refreshPayouts() {
        // Refresh the payouts component when test data is created
        DispatchQueue.main.async { [weak self] in
            self?.loadEmbeddedPayoutsComponent()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupBankBranding() {
        // Apply bank branding
        navigationController?.navigationBar.tintColor = BankConfiguration.current.primaryColor
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: BankConfiguration.current.primaryColor
        ]
    }
    
    private func loadEmbeddedPayoutsComponent() {
        // Check if we have an account ID
        guard AppDataManager.shared.currentAccountId != nil else {
            showSetupRequired()
            return
        }
        
        // Create embedded payouts component
        let payoutsVC = embeddedComponentManager.createPayoutsViewController()
        payoutsVC.delegate = self
        payoutsEmbeddedVC = payoutsVC
        
        // Add as child view controller
        addChild(payoutsVC)
        view.addSubview(payoutsVC.view)
        payoutsVC.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            payoutsVC.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            payoutsVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            payoutsVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            payoutsVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        payoutsVC.didMove(toParent: self)
    }
    
    private func showSetupRequired() {
        let setupLabel = UILabel()
        setupLabel.text = "Account setup required.\nPlease complete onboarding from the Home tab first."
        setupLabel.textAlignment = .center
        setupLabel.numberOfLines = 0
        setupLabel.font = UIFont.systemFont(ofSize: 16)
        setupLabel.textColor = .darkGray
        setupLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let setupButton = UIButton(type: .system)
        setupButton.setTitle("Go to Home", for: .normal)
        setupButton.backgroundColor = BankConfiguration.current.primaryColor
        setupButton.setTitleColor(.white, for: .normal)
        setupButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        setupButton.layer.cornerRadius = 8
        setupButton.addTarget(self, action: #selector(goToHomeTab), for: .touchUpInside)
        setupButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(setupLabel)
        view.addSubview(setupButton)
        
        NSLayoutConstraint.activate([
            setupLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            setupLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            setupLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            setupLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            setupButton.topAnchor.constraint(equalTo: setupLabel.bottomAnchor, constant: 20),
            setupButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            setupButton.heightAnchor.constraint(equalToConstant: 44),
            setupButton.widthAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    @objc private func goToHomeTab() {
        tabBarController?.selectedIndex = 0
    }
    
    private func fetchAccountSession(accountId: String) async throws -> String? {
        // Use the same backend integration as MainViewController
        let backendBaseURL = AppSettings.shared.selectedServerBaseURL
        
        guard let url = URL(string: "\(backendBaseURL)/api/account_session") else {
            throw NSError(domain: BankConfiguration.current.errorDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid backend URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accountId, forHTTPHeaderField: "account")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: BankConfiguration.current.errorDomain, code: 2, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["clientSecret"] as? String
    }
}

// MARK: - PayoutsViewControllerDelegate
extension PayoutsViewController: PayoutsViewControllerDelegate {
    nonisolated func payouts(_ payouts: StripeConnect.PayoutsViewController, didFailLoadWithError error: Error) {
        print("Payouts failed to load: \(error)")
        
        Task { @MainActor in
            let alert = UIAlertController(
                title: "Error Loading Payouts",
                message: "Unable to load payouts data. Please check your connection and try again.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}

// MARK: - App Data Manager for sharing account state

@MainActor
final class AppDataManager: ObservableObject {
    static let shared = AppDataManager()
    private init() {}
    
    private let userDefaults = UserDefaults.standard
    private let accountIdKey = "ConnectedAccountId"
    private let accountCountryKey = "ConnectedAccountCountry"
    private let accountCurrencyKey = "ConnectedAccountCurrency"
    
    @Published private var _currentAccountId: String?
    
    var currentAccountId: String? {
        get {
            if _currentAccountId == nil {
                _currentAccountId = userDefaults.string(forKey: accountIdKey)
            }
            return _currentAccountId
        }
        set {
            _currentAccountId = newValue
            if let newValue = newValue {
                userDefaults.set(newValue, forKey: accountIdKey)
                print("INFO: Saved account ID to UserDefaults: \(newValue)")
            } else {
                userDefaults.removeObject(forKey: accountIdKey)
                clearAccountContext()
                print("INFO: Cleared account ID from UserDefaults")
            }
            userDefaults.synchronize()
        }
    }

    var currentAccountCountry: String? {
        userDefaults.string(forKey: accountCountryKey)
    }

    var currentAccountCurrency: String? {
        userDefaults.string(forKey: accountCurrencyKey)
    }

    func setAccountContext(country: String, currency: String) {
        userDefaults.set(country.uppercased(), forKey: accountCountryKey)
        userDefaults.set(currency.uppercased(), forKey: accountCurrencyKey)
    }

    func clearAccountContext() {
        userDefaults.removeObject(forKey: accountCountryKey)
        userDefaults.removeObject(forKey: accountCurrencyKey)
    }
    
    /// Safely retrieve the current account ID from any context
    nonisolated func getCurrentAccountId() -> String? {
        return UserDefaults.standard.string(forKey: accountIdKey)
    }
    
    /// Safely set the current account ID from any context
    nonisolated func setCurrentAccountId(_ accountId: String?) {
        if let newValue = accountId {
            UserDefaults.standard.set(newValue, forKey: accountIdKey)
            print("INFO: Saved account ID to UserDefaults: \(newValue)")
        } else {
            UserDefaults.standard.removeObject(forKey: accountIdKey)
            UserDefaults.standard.removeObject(forKey: "ConnectedAccountCountry")
            UserDefaults.standard.removeObject(forKey: "ConnectedAccountCurrency")
            print("INFO: Cleared account ID from UserDefaults")
        }
        UserDefaults.standard.synchronize()
        
        // Update the published property on main actor
        Task { @MainActor in
            self._currentAccountId = accountId
        }
    }
}

class BusinessBankingViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Business Banking"
        view.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        
        let label = UILabel()
        label.text = "Traditional business banking services including loans, investing, and account management."
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .darkGray
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
}

class SupportViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Support"
        view.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        
        let label = UILabel()
        label.text = "Get help with your account, payments, and other banking services."
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .darkGray
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
}

// MARK: - BankingDashboardViewController
class BankingDashboardViewController: UIViewController {
    
    private var accountBalance: String = BankConfiguration.current.activeMarket.format(0)
    private var accountStatus: String = "Loading..."
    private var accountId: String? {
        return AppDataManager.shared.currentAccountId
    }
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkOnboardingStatus()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.systemGroupedBackground
        title = "Home"
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        if accountId != nil {
            setupBankingDashboard()
        } else {
            setupOnboardingPrompt()
        }
    }
    
    private func setupBankingDashboard() {
        // Clear previous views
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Account Status Indicator
        let statusCard = createAccountStatusCard()
        
        // Account Balance Card
        let balanceCard = createAccountBalanceCard()
        
        // Action Buttons (Send, Get paid, etc.)
        let actionButtonsStack = createActionButtons()
        
        // Tap to Pay Section
        let tapToPayCard = createTapToPayCard()
        
        // Transactions Section with Embedded Payments
        let transactionsSection = createTransactionsSection()
        
        contentView.addSubview(statusCard)
        contentView.addSubview(balanceCard)
        contentView.addSubview(actionButtonsStack)
        contentView.addSubview(tapToPayCard)
        contentView.addSubview(transactionsSection)
        
        NSLayoutConstraint.activate([
            // Status card at top
            statusCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            statusCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Balance card
            balanceCard.topAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: 16),
            balanceCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            balanceCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            balanceCard.heightAnchor.constraint(equalToConstant: 120),
            
            // Action buttons
            actionButtonsStack.topAnchor.constraint(equalTo: balanceCard.bottomAnchor, constant: 24),
            actionButtonsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            actionButtonsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            actionButtonsStack.heightAnchor.constraint(equalToConstant: 80),
            
            // Tap to Pay card
            tapToPayCard.topAnchor.constraint(equalTo: actionButtonsStack.bottomAnchor, constant: 24),
            tapToPayCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tapToPayCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tapToPayCard.heightAnchor.constraint(equalToConstant: 80),
            
            // Transactions section
            transactionsSection.topAnchor.constraint(equalTo: tapToPayCard.bottomAnchor, constant: 24),
            transactionsSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            transactionsSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            transactionsSection.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
            transactionsSection.heightAnchor.constraint(equalToConstant: 400)
        ])
    }
    
    private func createAccountStatusCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 1)
        card.layer.shadowOpacity = 0.1
        card.layer.shadowRadius = 3
        
        let titleLabel = UILabel()
        titleLabel.text = "Account Status"
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let statusLabel = UILabel()
        statusLabel.text = accountStatus
        statusLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        statusLabel.textColor = .label
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let statusIndicator = UIView()
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusIndicator.backgroundColor = getStatusColor()
        statusIndicator.layer.cornerRadius = 4
        
        card.addSubview(titleLabel)
        card.addSubview(statusLabel)
        card.addSubview(statusIndicator)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            statusLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            
            statusIndicator.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            statusIndicator.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            statusIndicator.widthAnchor.constraint(equalToConstant: 8),
            statusIndicator.heightAnchor.constraint(equalToConstant: 8)
        ])
        
        return card
    }
    
    private func getStatusColor() -> UIColor {
        switch accountStatus.lowercased() {
        case "enabled":
            return .systemGreen
        case "pending":
            return .systemOrange
        case "restricted", "restricted soon":
            return .systemRed
        case "rejected":
            return .systemRed
        default:
            return .systemGray
        }
    }
    
    private func createAccountBalanceCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.6, alpha: 1.0)
        card.layer.cornerRadius = 16
        
        let accountLabel = UILabel()
        accountLabel.text = BankConfiguration.current.currentAccountName
        accountLabel.font = .systemFont(ofSize: 14, weight: .medium)
        accountLabel.textColor = .white.withAlphaComponent(0.8)
        accountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let balanceLabel = UILabel()
        balanceLabel.text = accountBalance
        balanceLabel.font = .systemFont(ofSize: 32, weight: .bold)
        balanceLabel.textColor = .white
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let detailsButton = UIButton(type: .system)
        detailsButton.setTitle("Details ›", for: .normal)
        detailsButton.setTitleColor(.white, for: .normal)
        detailsButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        detailsButton.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(accountLabel)
        card.addSubview(balanceLabel)
        card.addSubview(detailsButton)
        
        NSLayoutConstraint.activate([
            accountLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            accountLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            
            balanceLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            balanceLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            
            detailsButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            detailsButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20)
        ])
        
        return card
    }
    
    private func createActionButtons() -> UIStackView {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 20
        
        let sendButton = createActionButton(title: "Send", icon: "arrow.up", color: .systemBlue)
        let receiveButton = createActionButton(title: "Get paid", icon: "arrow.down", color: .systemBlue)
        let cardReaderButton = createActionButton(title: "Card Reader", icon: "creditcard", color: .systemBlue)
        let cardsButton = createActionButton(title: "Cards", icon: "rectangle.stack", color: .systemBlue)
        
        stackView.addArrangedSubview(sendButton)
        stackView.addArrangedSubview(receiveButton)
        stackView.addArrangedSubview(cardReaderButton)
        stackView.addArrangedSubview(cardsButton)
        
        return stackView
    }
    
    private func createActionButton(title: String, icon: String, color: UIColor) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = color
        button.layer.cornerRadius = 25
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.tintColor = .white
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(button)
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            button.widthAnchor.constraint(equalToConstant: 50),
            button.heightAnchor.constraint(equalToConstant: 50),
            
            label.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 8),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createTapToPayCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 1)
        card.layer.shadowOpacity = 0.1
        card.layer.shadowRadius = 3
        
        let iconImageView = UIImageView(image: UIImage(systemName: "wave.3.right"))
        iconImageView.tintColor = .systemBlue
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Tap to Pay on iPhone"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Accept contactless payments"
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(iconImageView)
        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        
        return card
    }
    
    private func createTransactionsSection() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let headerLabel = UILabel()
        headerLabel.text = "Transactions"
        headerLabel.font = .systemFont(ofSize: 20, weight: .bold)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Embed Stripe Payments component here (includes both payments and payouts as transactions)
        let paymentsContainer = createEmbeddedPaymentsView()
        
        container.addSubview(headerLabel)
        container.addSubview(paymentsContainer)
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: container.topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            paymentsContainer.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16),
            paymentsContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            paymentsContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            paymentsContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createEmbeddedPaymentsView() -> UIView {
        guard accountId != nil else {
            return createPlaceholderView()
        }
        
        // Create embedded component manager with bank branding
        lazy var embeddedComponentManager: EmbeddedComponentManager = {
            return .init(
                appearance: AppSettings.shared.appearanceInfo.appearance,
                fetchClientSecret: { [weak self] in
                    guard let self = self,
                          let accountId = self.accountId else {
                        return nil
                    }
                    do {
                        return try await self.fetchAccountSession(accountId: accountId)
                    } catch {
                        print("Failed to fetch account session: \(error)")
                        return nil
                    }
                })
        }()
        
        // Create payments view controller
        let paymentsVC = embeddedComponentManager.createPaymentsViewController()
        paymentsVC.delegate = self
        
        // Add as child view controller
        addChild(paymentsVC)
        let paymentsView = paymentsVC.view!
        paymentsView.translatesAutoresizingMaskIntoConstraints = false
        paymentsVC.didMove(toParent: self)
        
        return paymentsView
    }
    
    private func createPlaceholderView() -> UIView {
        let placeholder = UIView()
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.backgroundColor = .systemBackground
        placeholder.layer.cornerRadius = 12
        
        let label = UILabel()
        label.text = "Complete onboarding to view transactions"
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let onboardButton = UIButton(type: .system)
        onboardButton.setTitle("Start Onboarding", for: .normal)
        onboardButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        onboardButton.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.6, alpha: 1.0)
        onboardButton.setTitleColor(.white, for: .normal)
        onboardButton.layer.cornerRadius = 8
        onboardButton.translatesAutoresizingMaskIntoConstraints = false
        onboardButton.addTarget(self, action: #selector(startOnboardingTapped), for: .touchUpInside)
        
        placeholder.addSubview(label)
        placeholder.addSubview(onboardButton)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: placeholder.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: placeholder.centerYAnchor, constant: -20),
            
            onboardButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            onboardButton.centerXAnchor.constraint(equalTo: placeholder.centerXAnchor),
            onboardButton.widthAnchor.constraint(equalToConstant: 200),
            onboardButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        return placeholder
    }
    
    @objc private func startOnboardingTapped() {
        // Navigate to onboarding
        let mainVC = MainViewController()
        navigationController?.pushViewController(mainVC, animated: true)
    }
    
    private func setupOnboardingPrompt() {
        let placeholderView = createPlaceholderView()
        contentView.addSubview(placeholderView)
        
        NSLayoutConstraint.activate([
            placeholderView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            placeholderView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            placeholderView.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -32),
            placeholderView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    private func checkOnboardingStatus() {
        // Check if user has completed onboarding
        if accountId == nil {
            setupOnboardingPrompt()
        }
    }
    
    private func refreshAccountData() {
        guard let accountId = accountId else { return }
        
        // Fetch account status
        fetchAccountStatus(accountId: accountId)
    }
    
    private func fetchAccountStatus(accountId: String) {
        let backendBaseURL = AppSettings.shared.selectedServerBaseURL
        guard let url = URL(string: "\(backendBaseURL)/api/accounts/\(accountId)/status") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let accountStatus = json["account_status"] as? [String: Any],
                      let status = accountStatus["status"] as? String else {
                    return
                }
                
                self?.accountStatus = status
                self?.refreshUI()
            }
        }.resume()
    }
    
    private func refreshUI() {
        // Refresh the UI with updated data
        DispatchQueue.main.async { [weak self] in
            self?.setupUI()
        }
    }
    
    private func fetchAccountSession(accountId: String) async throws -> String? {
        let backendBaseURL = AppSettings.shared.selectedServerBaseURL
        guard let url = URL(string: "\(backendBaseURL)/api/account_session") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accountId, forHTTPHeaderField: "account")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["clientSecret"] as? String
    }
}

// MARK: - PaymentsViewControllerDelegate
extension BankingDashboardViewController: PaymentsViewControllerDelegate {
    func paymentsViewControllerDidLoadSuccessfully(_ paymentsViewController: PaymentsViewController) {
        print("Embedded payments loaded successfully in dashboard")
    }
    
    func paymentsViewController(_ paymentsViewController: PaymentsViewController, didFailLoadWithError error: Error) {
        print("Embedded payments failed to load in dashboard: \(error.localizedDescription)")
    }
}
