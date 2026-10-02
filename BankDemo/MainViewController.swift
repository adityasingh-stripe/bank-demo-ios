//
//  MainViewController.swift
//  StripeConnect Example
//
//  Created by Mel Ludowise on 4/30/24.
//

import UIKit
import SwiftUI
import StripeConnect
@_spi(DashboardOnly) import StripeConnect
import Stripe
import StripeFinancialConnections
import StripeTerminal
import OSLog

class MainViewController: UIViewController, PaymentCollectionDelegate {
    
    // MARK: - Configuration
    private let backendBaseURL = AppSettings.shared.selectedServerBaseURL
    
    // MARK: - Terminal Manager
    private let terminalManager = TerminalManager.shared
    
    // MARK: - Properties
    var selectedProfile: Profile?
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    private var getStartedButton: UIButton?
    private var hasGeneratedTestData = false
    
    // Business Account Data - Single account as requested
    private let businessAccount = BusinessAccount(
        name: "Business Account",
        balance: 25117.27,
        available: 3517.27,
        sortCode: "77-61-27",
        accountNumber: "004923476"
    )
    
    // Current account session
    private var currentAccountSession: String?
    
    // Collection options for onboarding (set when launching onboarding)
    private var currentCollectionOptions: AccountCollectionOptions?
    
    // Embedded Component Manager for Connect components with bank branding
    lazy var embeddedComponentManager: EmbeddedComponentManager = {
        return .init(
            appearance: AppSettings.shared.appearanceInfo.appearance,
            fetchClientSecret: { [weak self] in
                guard let self = self else { return nil }
                guard let accountId = AppDataManager.shared.currentAccountId else { return nil }
                
                do {
                    let clientSecret = try await self.fetchAccountSession(accountId: accountId)
                    return clientSecret
                } catch {
                    print("ERROR: Failed to fetch account session: \(error)")
                    return nil
                }
            })
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        
        setupBankBranding()
        setupMobileNavigation()
        setupUI()
        loadBusinessBankingInterface()
        
        // Listen for logo updates from BrandingManager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(logoUpdated),
            name: .brandingLogoUpdated,
            object: nil
        )
        
        // Listen for test data creation
        // Note: Onboarding completion is now handled directly in the delegate
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshDashboard),
            name: NSNotification.Name("TestDataCreated"),
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Don't auto-refresh in viewWillAppear to prevent duplicate content
        // Dashboard refresh is handled by explicit calls and notifications

    }
    
    @objc private func refreshDashboard() {
        DispatchQueue.main.async { [weak self] in
            self?.loadBusinessBankingInterface()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupBankBranding() {
        print("Setting up bank branding for \(BankConfiguration.current.bankDisplayName)")
        
        // Configure navigation bar appearance with proper background
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = BankConfiguration.current.primaryColor
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = .white
        
        // Set title for Home tab
        title = "Home"
        
        // Add user profile icon to left - with better visibility
        let userButton = UIButton(type: .system)
        userButton.setImage(UIImage(systemName: "person.crop.circle"), for: .normal)
        userButton.tintColor = .white
        userButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        userButton.layer.cornerRadius = 16
        userButton.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        userButton.addTarget(self, action: #selector(userProfileTapped), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: userButton)
        
        // Add bank logo or title in navigation bar
        let titleLabel = UILabel()
        titleLabel.text = BankConfiguration.current.navigationTitle
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        navigationItem.titleView = titleLabel
        
        print("Navigation bar configured with primary color: \(BankConfiguration.current.primaryColor)")
        
        // Setup scroll view hierarchy
        setupScrollViewHierarchy()
    }
    
    private func setupMobileNavigation() {
        print("Setting up mobile navigation")
        
        // Add profile icon on the left if profile is selected - with better visibility
        if let profile = selectedProfile {
            let iconButton = UIButton(type: .system)
            let iconName = profile.type == "individual" ? "person.crop.circle" : "building.2.crop.circle"
            iconButton.setImage(UIImage(systemName: iconName), for: .normal)
            iconButton.tintColor = .white
            iconButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            iconButton.layer.cornerRadius = 16
            iconButton.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
            iconButton.addTarget(self, action: #selector(profileButtonTapped), for: .touchUpInside)
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: iconButton)
            
            print("Profile icon added for \(profile.type) profile: \(profile.name)")
        }
        
        // Add logout button on the right with proper visibility
        let logoutButton = UIBarButtonItem(
            title: "Logout",
            style: .plain,
            target: self,
            action: #selector(logoutButtonTapped)
        )
        logoutButton.tintColor = .white
        navigationItem.rightBarButtonItem = logoutButton
        
        print("Logout button configured with white tint color")
    }
    
    @objc private func profileButtonTapped() {
        guard let profile = selectedProfile else { return }
        
        showProfileCard(profile: profile)
    }
    
    @objc private func logoutButtonTapped() {
        print("🔐 UI: Logout button tapped on MainViewController")
        
        let alert = UIAlertController(
            title: "Logout",
            message: "Are you sure you want to logout? You'll return to profile selection.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            print("🔐 UI: Logout cancelled on MainViewController")
        })
        
        alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { [weak self] _ in
            print("🔐 UI: Logout confirmed on MainViewController")
            self?.performLogout()
        })
        
        present(alert, animated: true)
    }
    
    private func performLogout() {
        print("🔐 Authentication: Logout initiated")
        print("Logging out - clearing profile and account data")
        
        // Clear current account data
        AppDataManager.shared.currentAccountId = nil
        selectedProfile = nil
        hasGeneratedTestData = false
        
        print("Profile and account data cleared")
        
        // Disconnect from Terminal reader if connected
        if terminalManager.isConnectedToReader {
            print("Disconnecting Terminal reader on logout")
            Terminal.shared.disconnectReader { error in
                if let error = error {
                    print("Terminal reader disconnect error: \(error.localizedDescription)")
                } else {
                    print("Terminal reader disconnected successfully")
                }
            }
        }
        
        // Navigate back to profile selection
        let profileSelectionVC = ProfileSelectionViewController()
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = profileSelectionVC
            window.makeKeyAndVisible()
            print("🔐 UI: Navigation to profile selection on ProfileSelectionViewController")
            print("🔐 Authentication: Logout completed - returned to profile selection")
        }
    }
    
    private func showProfileCard(profile: Profile) {
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlayView.alpha = 0
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create card view
        let cardView = UIView()
        cardView.backgroundColor = UIColor.systemBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.2
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowRadius = 8
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        // Bank primary color
        let bankPrimary = BankConfiguration.current.primaryColor
        
        // Header with bank branding
        let headerView = UIView()
        headerView.backgroundColor = bankPrimary
        headerView.layer.cornerRadius = 16
        headerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        let profileIconView = UIImageView()
        profileIconView.image = UIImage(systemName: profile.type == "individual" ? "person.circle.fill" : "building.2.fill")
        profileIconView.tintColor = UIColor.white
        profileIconView.contentMode = .scaleAspectFit
        profileIconView.translatesAutoresizingMaskIntoConstraints = false
        
        let profileTypeLabel = UILabel()
        profileTypeLabel.text = profile.type.capitalized + " Profile"
        profileTypeLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        profileTypeLabel.textColor = UIColor.white
        profileTypeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Content
        let nameLabel = UILabel()
        nameLabel.text = profile.name
        nameLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        nameLabel.textColor = UIColor.label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let emailLabel = UILabel()
        emailLabel.text = profile.email
        emailLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        emailLabel.textColor = UIColor.secondaryLabel
        emailLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let phoneLabel = UILabel()
        phoneLabel.text = profile.phone
        phoneLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        phoneLabel.textColor = UIColor.secondaryLabel
        phoneLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Close button
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.backgroundColor = bankPrimary
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        closeButton.layer.cornerRadius = 8
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Add tap gesture to dismiss
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissProfileCard))
        overlayView.addGestureRecognizer(tapGesture)
        
        closeButton.addTarget(self, action: #selector(dismissProfileCard), for: .touchUpInside)
        
        // Build hierarchy
        view.addSubview(overlayView)
        overlayView.addSubview(cardView)
        cardView.addSubview(headerView)
        headerView.addSubview(profileIconView)
        headerView.addSubview(profileTypeLabel)
        cardView.addSubview(nameLabel)
        cardView.addSubview(emailLabel)
        cardView.addSubview(phoneLabel)
        cardView.addSubview(closeButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            cardView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: overlayView.leadingAnchor, constant: 40),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: overlayView.trailingAnchor, constant: -40),
            cardView.widthAnchor.constraint(equalToConstant: 300),
            
            headerView.topAnchor.constraint(equalTo: cardView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 80),
            
            profileIconView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            profileIconView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            profileIconView.widthAnchor.constraint(equalToConstant: 40),
            profileIconView.heightAnchor.constraint(equalToConstant: 40),
            
            profileTypeLabel.leadingAnchor.constraint(equalTo: profileIconView.trailingAnchor, constant: 12),
            profileTypeLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            profileTypeLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            nameLabel.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 24),
            nameLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            
            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            emailLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            emailLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            
            phoneLabel.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 8),
            phoneLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            phoneLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            
            closeButton.topAnchor.constraint(equalTo: phoneLabel.bottomAnchor, constant: 24),
            closeButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            closeButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20)
        ])
        
        // Animate in
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            overlayView.alpha = 1
            cardView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        }
        
        // Initially scale down card for animation
        cardView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
    }
    
    @objc private func dismissProfileCard() {
        guard let overlayView = view.subviews.last else { return }
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
            overlayView.alpha = 0
            if let cardView = overlayView.subviews.first {
                cardView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }
        } completion: { _ in
            overlayView.removeFromSuperview()
        }
    }
    
    private func setupScrollViewHierarchy() {
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup hierarchy
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        // Configure stack view
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.distribution = .fill
        stackView.alignment = .fill
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Scroll view fills the safe area
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Content view defines the scrollable area
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Stack view within content view with proper padding for centered content
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    private func createBottomTabBar() -> UIView {
        let tabBar = UIView()
        tabBar.backgroundColor = .white
        tabBar.layer.shadowColor = UIColor.black.cgColor
        tabBar.layer.shadowOpacity = 0.1
        tabBar.layer.shadowOffset = CGSize(width: 0, height: -2)
        tabBar.layer.shadowRadius = 4
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let tabs = [
            ("house.fill", "Home"),
            ("creditcard.fill", "Payments"),
            ("chart.bar.fill", "Analytics"),
            ("person.crop.circle.fill", "Profile")
        ]
        
        for (index, (icon, title)) in tabs.enumerated() {
            let tabButton = createTabButton(icon: icon, title: title, isSelected: index == 0)
            tabButton.tag = index
            tabButton.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(tabButton)
        }
        
        tabBar.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: tabBar.topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: tabBar.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor, constant: -8)
        ])
        
        return tabBar
    }
    
    private func createTabButton(icon: String, title: String, isSelected: Bool) -> UIButton {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: icon, withConfiguration: config)
        
        button.setImage(image, for: .normal)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        
        let color = isSelected ? UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1) : .gray
        button.tintColor = color
        button.setTitleColor(color, for: .normal)
        
        // Arrange image above text
        button.titleEdgeInsets = UIEdgeInsets(top: 4, left: -button.imageView!.frame.width, bottom: 0, right: 0)
        button.imageEdgeInsets = UIEdgeInsets(top: -4, left: 0, bottom: 0, right: -button.titleLabel!.frame.width)
        button.contentVerticalAlignment = .center
        
        return button
    }
    
    @objc private func tabTapped(_ sender: UIButton) {
        let tabTitles = ["Home", "Payments", "Analytics", "Profile"]
        let selectedTab = tabTitles[sender.tag]
        
        // Update visual state of tabs
        if let stackView = sender.superview as? UIStackView {
            for (index, view) in stackView.arrangedSubviews.enumerated() {
                if let tabButton = view as? UIButton {
                    let isSelected = index == sender.tag
                    let color = isSelected ? UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1) : .gray
                    tabButton.tintColor = color
                    tabButton.setTitleColor(color, for: .normal)
                }
            }
        }
        
        // Show different content based on selected tab
        switch sender.tag {
        case 0: // Home
            showInfo("Home", "You're already on the home screen")
        case 1: // Payments
            showPaymentsScreen()
        case 2: // Analytics
            showInfo("Analytics", "View your transaction analytics and spending insights")
        case 3: // Profile
            showInfo("Profile", "Manage your profile and account settings")
        default:
            break
        }
    }
    
    private func showPaymentsScreen() {
        print("INFO: Opening payments component")
        
        // Create embedded payments component
        let paymentsVC = embeddedComponentManager.createPaymentsViewController()
        paymentsVC.delegate = self
        paymentsVC.title = "Payments"
        paymentsVC.navigationItem.backButtonDisplayMode = .minimal
        
        // Add close button for modal presentation
        paymentsVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissModal)
        )
        
        // Present modally with navigation
        let navController = UINavigationController(rootViewController: paymentsVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            // Scroll view constraints - adjusted for bottom tab bar
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80), // Account for tab bar
            
            // Content view constraints
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Stack view constraints
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func showAccountMenu() {
        let actionSheet = UIAlertController(title: "Account Actions", message: nil, preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "View Statement", style: .default) { _ in
            self.showAccountStatement()
        })
        
        actionSheet.addAction(UIAlertAction(title: "Transfer Money", style: .default) { _ in
            self.showTransferMoney()
        })
        
        actionSheet.addAction(UIAlertAction(title: "Account Details", style: .default) { _ in
            self.showAccountDetails()
        })
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad support
        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        
        present(actionSheet, animated: true)
    }
    
    private func showAccountStatement() {
        let alert = UIAlertController(title: "Account Statement", message: "Your monthly statement is being generated and will be available shortly.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showTransferMoney() {
        let alert = UIAlertController(title: "Transfer Money", message: "Transfer functionality would open here with secure authentication.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showAccountDetails() {
        let message = """
        Account Name: \(businessAccount.name)
        Sort Code: \(businessAccount.sortCode)
        Account Number: \(businessAccount.accountNumber)
        Available Balance: £\(String(format: "%.2f", businessAccount.available))
        Current Balance: £\(String(format: "%.2f", businessAccount.balance))
        """
        
        let alert = UIAlertController(title: "Account Details", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func loadBusinessBankingInterface() {

        
        // Clear existing content completely
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        // Reset test data flag when loading interface (except if we already generated it)
        // This prevents duplicate content issues
        
        // Check if we have an account ID and fetch its real status
        if let accountId = AppDataManager.shared.currentAccountId {

            
            Task {
                do {
                    let statusData = try await fetchAccountStatus(accountId: accountId)
                    DispatchQueue.main.async { [weak self] in
                        self?.handleAccountStatus(statusData: statusData, accountId: accountId)
                    }
                } catch {
                    print("ERROR: Failed to fetch account status: \(error)")
                    DispatchQueue.main.async { [weak self] in
                        // If we can't fetch status, assume incomplete onboarding
                        self?.loadOnboardingInterface()
                    }
                }
            }
        } else {

            // No account ID - show onboarding CTA
            loadOnboardingInterface() 
        }
    }
    
    private func handleAccountStatus(statusData: [String: Any]?, accountId: String) {

        
        guard let statusData = statusData else {
            print("ERROR: No status data received, showing onboarding interface")
            loadOnboardingInterface()
            return
        }
        
        guard let status = statusData["status"] as? String else {
            print("ERROR: Missing 'status' field in statusData: \(statusData)")
            loadOnboardingInterface()
            return
        }
        
        guard let capabilities = statusData["capabilities"] as? [String: Any] else {
            print("ERROR: Missing 'capabilities' field in statusData: \(statusData)")
            loadOnboardingInterface()
            return
        }
        
        guard let chargesEnabled = capabilities["charges_enabled"] as? Bool,
              let payoutsEnabled = capabilities["payouts_enabled"] as? Bool else {
            print("ERROR: Missing capability flags in capabilities: \(capabilities)")
            loadOnboardingInterface()
            return
        }
        
        // Check for pending requirements that need user action
        let requirements = statusData["requirements"] as? [String: Any]
        let currentlyDue = requirements?["currently_due"] as? [String] ?? []
        let pastDue = requirements?["past_due"] as? [String] ?? []
        
        print("INFO: Account status: \(status), charges: \(chargesEnabled), payouts: \(payoutsEnabled)")
        print("INFO: Currently due requirements: \(currentlyDue)")
        print("INFO: Past due requirements: \(pastDue)")
        
        // Check if account needs updated information (has currently_due or past_due requirements)
        let needsUpdatedInfo = !currentlyDue.isEmpty || !pastDue.isEmpty
        
        if needsUpdatedInfo {
            print("INFO: Account needs additional information - showing requirements interface")
            // Account needs updated information - show requirements dashboard
            loadRequirementsNeededDashboard(statusData: statusData, accountId: accountId)
        } else {
            switch status {
            case "Enabled":
                print("INFO: Account fully enabled - showing complete dashboard")
                loadFullyEnabledDashboard(accountId: accountId)
            case "Pending":
                // Account is pending review - show limited dashboard
                loadPendingDashboard(statusData: statusData)
            case "Restricted Soon", "Restricted":
                // Account has restrictions - show dashboard with resume onboarding
                loadRestrictedDashboard(statusData: statusData, accountId: accountId)
            case "Rejected":
                // Account rejected
                loadRejectedDashboard(statusData: statusData)
            default:
                // Unknown status - treat as incomplete onboarding
                loadOnboardingInterface()
            }
        }
    }
    
    private func loadOnboardingInterface() {
        // Account Balance Card - bank account is always available
        let balanceCard = createBankAccountBalanceCard()
        stackView.addArrangedSubview(balanceCard)
        
        // Action Buttons - Banking functions always available
        let actionButtons = createBankingActionButtons()
        stackView.addArrangedSubview(actionButtons)
        
        // Tap to Pay Section (disabled until Stripe onboarding complete)
        let tapToPayCard = createDisabledTapToPaySection()
        stackView.addArrangedSubview(tapToPayCard)
        
        // Setup prompt for Stripe payments
        let setupPrompt = createSetupPromptSection()
        stackView.addArrangedSubview(setupPrompt)
    }
    
    private func createOnboardingBalanceCard() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor.systemGray4 // Disabled appearance
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        
        // Accounts button (disabled)
        let accountsButton = UIButton(type: .system)
        accountsButton.setTitle("Accounts", for: .normal)
        accountsButton.backgroundColor = .white.withAlphaComponent(0.2)
        accountsButton.setTitleColor(.white, for: .normal)
        accountsButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        accountsButton.layer.cornerRadius = 12
        accountsButton.isEnabled = false
        accountsButton.translatesAutoresizingMaskIntoConstraints = false
        
        let accountLabel = UILabel()
        accountLabel.text = BankConfiguration.current.currentAccountName
        accountLabel.font = .systemFont(ofSize: 14, weight: .medium)
        accountLabel.textColor = .white.withAlphaComponent(0.8)
        accountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let balanceLabel = UILabel()
        balanceLabel.text = "Complete setup to view balance"
        balanceLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        balanceLabel.textColor = .white
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let setupButton = UIButton(type: .system)
        setupButton.setTitle("Setup Account", for: .normal)
        setupButton.setTitleColor(.white, for: .normal)
        setupButton.backgroundColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1.0)
        setupButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        setupButton.layer.cornerRadius = 8
        setupButton.translatesAutoresizingMaskIntoConstraints = false
        setupButton.addTarget(self, action: #selector(startOnboardingTapped), for: .touchUpInside)
        
        card.addSubview(accountsButton)
        card.addSubview(accountLabel)
        card.addSubview(balanceLabel)
        card.addSubview(setupButton)
        
        NSLayoutConstraint.activate([
            accountsButton.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            accountsButton.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            accountsButton.widthAnchor.constraint(equalToConstant: 100),
            accountsButton.heightAnchor.constraint(equalToConstant: 32),
            
            accountLabel.topAnchor.constraint(equalTo: accountsButton.bottomAnchor, constant: 12),
            accountLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            
            balanceLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: 10),
            balanceLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            
            setupButton.centerYAnchor.constraint(equalTo: balanceLabel.centerYAnchor),
            setupButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            setupButton.widthAnchor.constraint(equalToConstant: 120),
            setupButton.heightAnchor.constraint(equalToConstant: 36),
            
            card.heightAnchor.constraint(equalToConstant: 140)
        ])
        
        return card
    }
    
    private func createDisabledTapToPaySection() -> UIView {
        let card = UIView()
        card.backgroundColor = .systemGray6
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 1)
        card.layer.shadowOpacity = 0.05
        card.layer.shadowRadius = 3
        
        let iconImageView = UIImageView(image: UIImage(systemName: "wave.3.right"))
        iconImageView.tintColor = .systemGray3
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Tap to Pay on iPhone"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .systemGray3
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Complete account setup to enable"
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .systemGray4
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
            subtitleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            
            card.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        return card
    }
    
    private func createRequirementsBlockedTapToPaySection() -> UIView {
        let card = UIView()
        card.backgroundColor = .systemGray6
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 1)
        card.layer.shadowOpacity = 0.05
        card.layer.shadowRadius = 3
        
        let iconImageView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
        iconImageView.tintColor = .systemOrange
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Tap to Pay on iPhone"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .systemGray3
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Blocked - account needs review"
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .systemOrange
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
            subtitleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            
            card.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        return card
    }
    
    private func createSetupPromptSection() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Start taking payments today"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = BankConfiguration.current.onboardingSubtitle
        subtitleLabel.font = .systemFont(ofSize: 16)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let getStartedButton = UIButton(type: .system)
        getStartedButton.setTitle("Get Started", for: .normal)
        getStartedButton.backgroundColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1.0)
        getStartedButton.setTitleColor(.white, for: .normal)
        getStartedButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        getStartedButton.layer.cornerRadius = 12
        getStartedButton.translatesAutoresizingMaskIntoConstraints = false
        getStartedButton.addTarget(self, action: #selector(startOnboardingTapped), for: .touchUpInside)
        
        // Store reference for state management
        self.getStartedButton = getStartedButton
        
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)
        container.addSubview(getStartedButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            
            getStartedButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            getStartedButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            getStartedButton.widthAnchor.constraint(equalToConstant: 200),
            getStartedButton.heightAnchor.constraint(equalToConstant: 50),
            getStartedButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
        ])
        
        return container
    }
    
    @objc private func startOnboardingTapped() {
        // Prevent multiple taps by disabling button and showing loading state
        guard let button = getStartedButton else { return }
        
        button.isEnabled = false
        
        print("INFO: Starting onboarding for profile: \(selectedProfile?.name ?? "Unknown")")
        
        // Check if we already have an account ID - if so, resume onboarding
        if let existingAccountId = AppDataManager.shared.currentAccountId {
            print("INFO: Resuming onboarding for existing account: \(existingAccountId)")
            button.setTitle("Resuming...", for: .normal)
            button.backgroundColor = UIColor.systemBlue
            
            DispatchQueue.main.async {
                // Restore button state
                button.isEnabled = true
                button.setTitle("Get Started", for: .normal)
                button.backgroundColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1)
                
                // Resume onboarding directly
                self.presentOnboardingFlow(accountId: existingAccountId)
            }
        } else {
            // No existing account - create new one
            button.setTitle("Creating Account...", for: .normal)
            button.backgroundColor = UIColor.systemGray
            
            // Start the onboarding flow
            createConnectedAccountAPI { [weak self] result in
                DispatchQueue.main.async {
                    // Restore button state
                    button.isEnabled = true
                    button.setTitle("Get Started", for: .normal)
                    button.backgroundColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1)
                    
                    switch result {
                    case .success(let accountId):
                        self?.presentOnboardingFlow(accountId: accountId)
                    case .failure(let error):
                        self?.showError("Failed to create account: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func loadFullyEnabledDashboard(accountId: String) {
        // Account is fully enabled - initialize Terminal SDK and show all features
        initializeTerminalSDKForOnboardedAccount()
        
        // Account Balance Card
        let balanceCard = createBankAccountBalanceCard()
        stackView.addArrangedSubview(balanceCard)
        
        // Action Buttons
        let actionButtons = createBankingActionButtons()
        stackView.addArrangedSubview(actionButtons)
        
        // Test Data Generation Banner (for fully enabled accounts) - only show if not generated yet
        if !hasGeneratedTestData {
            let testDataBanner = createTestDataBanner()
            stackView.addArrangedSubview(testDataBanner)
        }
        
        // Tap to Pay Section (enabled)
        let tapToPayCard = createTapToPaySection()
        stackView.addArrangedSubview(tapToPayCard)
        
        // Transactions Section - should expand to fill remaining space
        let transactionsSection = createTransactionsSection()
        transactionsSection.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(transactionsSection)
    }
    
    private func loadPendingDashboard(statusData: [String: Any]) {
        // Account is pending - show banking features but no Stripe features
        
        // Account Balance Card
        let balanceCard = createBankAccountBalanceCard() 
        stackView.addArrangedSubview(balanceCard)
        
        // Action Buttons
        let actionButtons = createBankingActionButtons()
        stackView.addArrangedSubview(actionButtons)
        
        // Tap to Pay Section (disabled)
        let tapToPayCard = createDisabledTapToPaySection()
        stackView.addArrangedSubview(tapToPayCard)
        
        // Resume onboarding banner for pending accounts
        let description = statusData["description"] as? String ?? "Your account is under review. Complete any missing verification requirements to activate your account."
        let resumeBanner = createResumeOnboardingBanner(message: description, accountId: AppDataManager.shared.currentAccountId ?? "")
        stackView.addArrangedSubview(resumeBanner)
        
        // Transactions Section (bank only)
        let transactionsSection = createTransactionsSection()
        transactionsSection.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(transactionsSection)
    }
    
    private func loadRestrictedDashboard(statusData: [String: Any], accountId: String) {
        // Account needs more information - show resume onboarding banner
        
        // Account Balance Card
        let balanceCard = createBankAccountBalanceCard()
        stackView.addArrangedSubview(balanceCard)
        
        // Action Buttons
        let actionButtons = createBankingActionButtons()
        stackView.addArrangedSubview(actionButtons)
        
        // Tap to Pay Section (disabled)
        let tapToPayCard = createDisabledTapToPaySection()
        stackView.addArrangedSubview(tapToPayCard)
        
        // Resume onboarding banner
        let description = statusData["description"] as? String ?? "Complete your account setup to start accepting payments"
        let resumeBanner = createResumeOnboardingBanner(message: description, accountId: accountId)
        stackView.addArrangedSubview(resumeBanner)
        
        // Transactions Section (bank only)
        let transactionsSection = createTransactionsSection()
        transactionsSection.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(transactionsSection)
    }
    
    private func loadRequirementsNeededDashboard(statusData: [String: Any], accountId: String) {
        // Account needs updated information - show dashboard with requirements notice and blocked Tap to Pay
        
        // Account Balance Card
        let balanceCard = createBankAccountBalanceCard()
        stackView.addArrangedSubview(balanceCard)
        
        // Action Buttons
        let actionButtons = createBankingActionButtons()
        stackView.addArrangedSubview(actionButtons)
        
        // Tap to Pay Section (disabled - blocked due to requirements)
        let tapToPayCard = createRequirementsBlockedTapToPaySection()
        stackView.addArrangedSubview(tapToPayCard)
        
        // Requirements notice banner
        let message = "Account needs review. Click to provide updated information."
        let requirementsBanner = createRequirementsNeededBanner(message: message, accountId: accountId)
        stackView.addArrangedSubview(requirementsBanner)
        
        // Transactions Section (bank only)
        let transactionsSection = createTransactionsSection()
        transactionsSection.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(transactionsSection)
    }
    
    private func loadRejectedDashboard(statusData: [String: Any]) {
        // Account rejected - show banking features only with rejection notice
        
        // Account Balance Card
        let balanceCard = createBankAccountBalanceCard()
        stackView.addArrangedSubview(balanceCard)
        
        // Action Buttons
        let actionButtons = createBankingActionButtons()
        stackView.addArrangedSubview(actionButtons)
        
        // Tap to Pay Section (disabled)
        let tapToPayCard = createDisabledTapToPaySection()
        stackView.addArrangedSubview(tapToPayCard)
        
        // Rejection banner
        let description = statusData["description"] as? String ?? "Account application was rejected"
        let rejectionBanner = createStatusBanner(title: "Account Rejected", message: description, type: .rejected)
        stackView.addArrangedSubview(rejectionBanner)
        
        // Transactions Section (bank only)
        let transactionsSection = createTransactionsSection()
        transactionsSection.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(transactionsSection)
    }
    
    private func createQuickActionsView() -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 12
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.1
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        container.layer.shadowRadius = 4
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 1
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let actions = [
            ("arrow.up.circle.fill", "Send Money"),
            ("arrow.down.circle.fill", "Request Money"),
            ("doc.text.fill", "Statements"),
            ("gear.circle.fill", "Settings")
        ]
        
        for (icon, title) in actions {
            let actionButton = createQuickActionButton(icon: icon, title: title)
            stackView.addArrangedSubview(actionButton)
        }
        
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            container.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        return container
    }
    
    private func createQuickActionButton(icon: String, title: String) -> UIButton {
        let button = UIButton(type: .system)
        
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let image = UIImage(systemName: icon, withConfiguration: config)
        
        button.setImage(image, for: .normal)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        button.tintColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1)
        button.setTitleColor(UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1), for: .normal)
        
        // Arrange image above text
        button.contentVerticalAlignment = .center
        button.imageEdgeInsets = UIEdgeInsets(top: -10, left: 0, bottom: 0, right: 0)
        button.titleEdgeInsets = UIEdgeInsets(top: 10, left: -button.imageView!.frame.width, bottom: -10, right: 0)
        
        button.addTarget(self, action: #selector(quickActionTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    @objc private func quickActionTapped(_ sender: UIButton) {
        guard let title = sender.titleLabel?.text else { return }
        
        switch title {
        case "Send Money":
            showInfo("Send Money", "Transfer money to another account or business")
        case "Request Money":
            showInfo("Request Money", "Request payment from customers or suppliers")
        case "Statements":
            showInfo("Statements", "View and download your account statements")
        case "Settings":
            showInfo("Settings", "Manage your account settings and preferences")
        default:
            break
        }
    }
    
    private func createMerchantServicesView() -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 12
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.1
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        container.layer.shadowRadius = 4
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let services = [
            ("creditcard.fill", "Payment Links", "Create a secure payment link for one-time payments."),
            ("creditcard.fill", "Virtual Terminal", "Process card payments over the phone or online."),
            ("creditcard.fill", "Tap to Pay", "Accept contactless payments with your iPhone."),
            ("creditcard.fill", "Card Readers", "Connect external card readers for in-person payments.")
        ]
        
        for (icon, title, description) in services {
            let serviceButton = createMerchantServiceButton(icon: icon, title: title, description: description)
            stackView.addArrangedSubview(serviceButton)
        }
        
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
        
        return container
    }
    
    private func createMerchantServiceButton(icon: String, title: String, description: String) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .medium))
        iconImageView.tintColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = UIFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = .gray
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        button.addSubview(iconImageView)
        button.addSubview(titleLabel)
        button.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: button.topAnchor, constant: 12),
            iconImageView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 12),
            iconImageView.widthAnchor.constraint(equalToConstant: 30),
            iconImageView.heightAnchor.constraint(equalToConstant: 30),
            
            titleLabel.topAnchor.constraint(equalTo: button.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -12)
        ])
        
        button.addTarget(self, action: #selector(merchantServiceTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    @objc private func merchantServiceTapped(_ sender: UIButton) {
        guard let title = sender.titleLabel?.text else { return }
        
        switch title {
        case "Payment Links":
            createPaymentLink()
        case "Virtual Terminal":
            openVirtualTerminal()
        case "Tap to Pay":
            setupTapToPay()
        case "Card Readers":
            setupCardReaders()
        default:
            break
        }
    }
    
    private func createAccountCard(for account: BusinessAccount) -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.borderWidth = 3
        container.layer.borderColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1).cgColor
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.1
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        container.layer.shadowRadius = 4
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        
                    // Remove bank logo from card - clean banking UI
        
        // Account details (center)
        let accountNameLabel = UILabel()
        accountNameLabel.text = account.name.uppercased()
        accountNameLabel.font = UIFont.boldSystemFont(ofSize: 14)
        accountNameLabel.textColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1)
        
        let sortCodeLabel = UILabel()
        sortCodeLabel.text = "Sort Code: \(account.sortCode)"
        sortCodeLabel.font = UIFont.systemFont(ofSize: 12)
        sortCodeLabel.textColor = .gray
        
        let accountNumberLabel = UILabel()
        accountNumberLabel.text = "Account: \(account.accountNumber)"
        accountNumberLabel.font = UIFont.systemFont(ofSize: 12)
        accountNumberLabel.textColor = .gray
        
        // Balance (right side, top)
        let balanceLabel = UILabel()
        balanceLabel.text = String(format: "£%.2f", account.balance)
        balanceLabel.font = UIFont.boldSystemFont(ofSize: 18)
        balanceLabel.textColor = .black
        balanceLabel.textAlignment = .right
        
        // Removed "Available for withdrawal" - cleaner banking UI
        
        // Triple dot menu button (right side, bottom)
        let menuButton = UIButton(type: .system)
        menuButton.setTitle("⋯", for: .normal)
        menuButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        menuButton.setTitleColor(UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1), for: .normal)
        menuButton.addTarget(self, action: #selector(showAccountMenu), for: .touchUpInside)
        
        // Layout
        [accountNameLabel, sortCodeLabel, accountNumberLabel, balanceLabel, menuButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            // Account details constraints (left side)
            accountNameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            accountNameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            accountNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: balanceLabel.leadingAnchor, constant: -8),
            
            sortCodeLabel.leadingAnchor.constraint(equalTo: accountNameLabel.leadingAnchor),
            sortCodeLabel.topAnchor.constraint(equalTo: accountNameLabel.bottomAnchor, constant: 4),
            
            accountNumberLabel.leadingAnchor.constraint(equalTo: accountNameLabel.leadingAnchor),
            accountNumberLabel.topAnchor.constraint(equalTo: sortCodeLabel.bottomAnchor, constant: 2),
            
            // Balance constraints (right side)
            balanceLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            balanceLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            
            // Menu button constraints
            menuButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            menuButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            menuButton.widthAnchor.constraint(equalToConstant: 30),
            menuButton.heightAnchor.constraint(equalToConstant: 30),
            
            container.heightAnchor.constraint(equalToConstant: 120)
        ])
        
        return container
    }
    
    private func createPaymentOptionsSection() -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 8
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.1
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        container.layer.shadowRadius = 4
        
        let titleLabel = UILabel()
        titleLabel.text = "Payment Processing Options"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(red: 0/255, green: 108/255, blue: 49/255, alpha: 1)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let paymentOptions = ["Payment Links", "Virtual Terminal", "Tap to Pay", "Card Readers"]
        let optionsStack = UIStackView()
        optionsStack.axis = .vertical
        optionsStack.spacing = 8
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        
        for option in paymentOptions {
            let button = UIButton(type: .system)
            button.setTitle(option, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
            button.layer.cornerRadius = 8
            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
            button.addTarget(self, action: #selector(paymentOptionTapped(_:)), for: .touchUpInside)
            optionsStack.addArrangedSubview(button)
        }
        
        container.addSubview(titleLabel)
        container.addSubview(optionsStack)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            optionsStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            optionsStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            optionsStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            optionsStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
        
        return container
    }
    
    private func createSeparatorLine() -> UIView {
        let line = UIView()
        line.backgroundColor = UIColor.lightGray
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.locale = Locale(identifier: "en_GB")
        return formatter.string(from: NSNumber(value: amount)) ?? "£0.00"
    }
    
    // MARK: - Actions
    
    @objc private func completeSetupTapped() {
        presentConnectAccountOnboarding()
    }
    
    @objc private func menuItemTapped(_ sender: UIButton) {
        guard let title = sender.titleLabel?.text else { return }
        
        let alert = UIAlertController(
            title: title,
            message: "This would navigate to the \(title) section of \(BankConfiguration.current.businessBankingName).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func accountActionTapped(_ sender: UIButton) {
        guard let action = sender.titleLabel?.text else { return }
        
        let alert = UIAlertController(
            title: action,
            message: "This would \(action.lowercased()) for your business account.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func paymentOptionTapped(_ sender: UIButton) {
        guard let option = sender.titleLabel?.text else { return }
        
        let alert = UIAlertController(
            title: option,
            message: "Setting up \(option) for your business...",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            self.setupPaymentOption(option)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func presentConnectAccountOnboarding() {

        let alert = UIAlertController(
            title: "Setting Up Payment Processing",
            message: "Creating your \(BankConfiguration.current.bankDisplayName) merchant account to start accepting payments...",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
    
            self.createConnectedAccount()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func setupPaymentOption(_ option: String) {
        switch option {
        case "Payment Links":
            createPaymentLink()
        case "Virtual Terminal": 
            openVirtualTerminal()
        case "Tap to Pay":
            setupTapToPay()
        case "Card Readers":
            setupCardReaders()
        default:
            let message = "Your \(option) is being configured. You'll be able to start accepting payments shortly."
            
            let alert = UIAlertController(
                title: "Setup Complete",
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    @objc private func createPaymentLink() {
        let alert = UIAlertController(title: "Create Payment Link", message: "Enter payment details", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Amount (£)"
            textField.keyboardType = .decimalPad
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Description"
        }
        
        alert.addAction(UIAlertAction(title: "Create Link", style: .default) { [weak self] _ in
            guard let amountText = alert.textFields?[0].text,
                  let amount = Double(amountText),
                  let description = alert.textFields?[1].text else {
                self?.showError("Please enter valid payment details")
                return
            }
            
            self?.generatePaymentLink(amount: amount, description: description)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func generatePaymentLink(amount: Double, description: String) {
        // Show loading
        let loadingAlert = UIAlertController(title: "Creating Payment Link", message: "Please wait...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // Create a real Stripe payment link
        createStripePaymentLink(amount: amount, description: description) { [weak self] result in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let paymentLink):
                        self?.showPaymentLinkCreated(link: paymentLink, amount: amount, description: description)
                    case .failure(let error):
                        self?.showError("Failed to create payment link: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func createStripePaymentLink(amount: Double, description: String, completion: @escaping @Sendable (Result<String, Error>) -> Void) {
        // In a production app, this would call your backend API
        // The backend would:
        // 1. Create a Price object with the specified amount
        // 2. Create a Payment Link with that price
        // 3. Return the payment link URL
        
        // For demo purposes, we'll simulate this with a realistic response
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { @Sendable in
            // Simulate successful payment link creation
            let paymentLinkId = "plink_\(UUID().uuidString.prefix(16))"
            let paymentLink = "https://buy.stripe.com/test_\(paymentLinkId)"
            
            completion(.success(paymentLink))
        }
    }
    
    private func showPaymentLinkCreated(link: String, amount: Double, description: String) {
        let message = """
        Payment Link Created Successfully!
        
        Amount: \(formatCurrency(amount))
        Description: \(description)
        
        Link: \(link)
        
        Share this link with your customers to accept payments.
        """
        
        let alert = UIAlertController(title: "Payment Link Ready", message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Copy Link", style: .default) { _ in
            UIPasteboard.general.string = link
            self.showSuccess("Payment link copied to clipboard!")
        })
        
        alert.addAction(UIAlertAction(title: "Share", style: .default) { _ in
            let activityVC = UIActivityViewController(activityItems: [link], applicationActivities: nil)
            self.present(activityVC, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Done", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func openVirtualTerminal() {
        let alert = UIAlertController(
            title: "Virtual Terminal",
            message: "Process card payments over the phone with our virtual terminal. Perfect for MOTO (Mail Order/Telephone Order) transactions.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Process Payment", style: .default) { [weak self] _ in
            self?.showVirtualTerminalForm()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showVirtualTerminalForm() {
        let alert = UIAlertController(title: "Process Card Payment", message: "Enter payment details", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Amount (£)"
            textField.keyboardType = .decimalPad
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Card Number"
            textField.keyboardType = .numberPad
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Expiry (MM/YY)"
        }
        
        alert.addTextField { textField in
            textField.placeholder = "CVV"
            textField.keyboardType = .numberPad
            textField.isSecureTextEntry = true
        }
        
        alert.addAction(UIAlertAction(title: "Process Payment", style: .default) { [weak self] _ in
            guard let amountText = alert.textFields?[0].text,
                  let amount = Double(amountText) else {
                self?.showError("Please enter a valid amount")
            return
            }
            
            self?.processVirtualTerminalPayment(amount: amount)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func processVirtualTerminalPayment(amount: Double) {
        let loadingAlert = UIAlertController(title: "Processing Payment", message: "Please wait...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // Simulate payment processing
        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    let paymentId = "pi_\(UUID().uuidString.prefix(10))"
                    self.showPaymentSuccess(paymentId: paymentId, amount: amount)
                }
            }
        }
    }
    
    private func showPaymentSuccess(paymentId: String, amount: Double) {
        let message = """
        Payment Processed Successfully!
        
        Amount: \(formatCurrency(amount))
        Payment ID: \(paymentId)
        
        The payment has been added to your business account.
        """
        
        let alert = UIAlertController(title: "Payment Complete", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func setupTapToPay() {
        let alert = UIAlertController(
            title: "Tap to Pay on iPhone",
            message: "Transform your iPhone into a contactless payment terminal. Accept payments from contactless cards and digital wallets without any additional hardware.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Enable Tap to Pay", style: .default) { [weak self] _ in
            self?.enableTapToPay()
        })
        
        alert.addAction(UIAlertAction(title: "Learn More", style: .default) { [weak self] _ in
            self?.showTapToPayInfo()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func enableTapToPay() {
        let alert = UIAlertController(
            title: "Tap to Pay on iPhone",
            message: "Transform your iPhone into a contactless payment terminal. Accept payments from contactless cards and digital wallets without any additional hardware.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Enable Tap to Pay", style: .default) { [weak self] _ in
            self?.enableTapToPay()
        })
        
        alert.addAction(UIAlertAction(title: "Learn More", style: .default) { [weak self] _ in
            self?.showTapToPayInfo()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showTapToPayInfo() {
        let message = """
        Tap to Pay on iPhone lets you accept contactless payments using just your iPhone.
        
        ✓ Accept contactless cards and digital wallets
        ✓ No additional hardware required
        ✓ Secure and encrypted transactions
        ✓ Real-time payment processing
        
        To enable this feature, you'll need:
        • A supported iPhone model
        • iOS 15.4 or later
        • StripeTerminal SDK integration
        • Valid merchant account
        
        Note: This feature requires additional setup and SDK integration. Contact your development team to add StripeTerminal support.
        """
        
        let alert = UIAlertController(title: "About Tap to Pay", message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Contact Support", style: .default) { [weak self] _ in
            self?.showContactSupport()
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showContactSupport() {
        let alert = UIAlertController(
            title: "Contact Support",
            message: BankConfiguration.current.supportMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Call Now", style: .default) { _ in
            if let url = URL(string: "tel:+443453000000") {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
    
    private func setupCardReaders() {
        let alert = UIAlertController(title: "Card Readers", message: "Choose a card reader for your business", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Stripe Reader S700", style: .default) { [weak self] _ in
            self?.showReaderInfo(type: "S700", description: "Advanced smartPOS reader with 5.5\" display")
        })
        
        alert.addAction(UIAlertAction(title: "Stripe Reader M2", style: .default) { [weak self] _ in
            self?.showReaderInfo(type: "M2", description: "Portable card reader for mobile businesses")
        })
        
        alert.addAction(UIAlertAction(title: "Stripe Terminal", style: .default) { [weak self] _ in
            self?.showReaderInfo(type: "Terminal", description: "Countertop payment terminal")
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showReaderInfo(type: String, description: String) {
        let message = """
        \(type) Card Reader
        
        \(description)
        
        Features:
        • Chip, contactless, and swipe payments
        • Wi-Fi connectivity
        • Long battery life
        • Secure end-to-end encryption
        
        This reader will be shipped to your registered business address.
        """
        
        let alert = UIAlertController(title: "Order \(type)", message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Order Now", style: .default) { [weak self] _ in
            self?.orderCardReader(type: type)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func orderCardReader(type: String) {
        let alert = UIAlertController(
            title: "Order Confirmed",
            message: "Your \(type) card reader has been ordered and will be shipped to your business address within 3-5 business days. You'll receive tracking information via email.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showSuccess(_ message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func createConnectedAccount() {
        print("INFO: Creating Stripe Connect account...")

        
        // Check if we already have an account
        if let existingAccountId = AppDataManager.shared.currentAccountId {
            print("INFO: Found existing account ID: \(existingAccountId)")
            // Resume existing account onboarding
            presentOnboardingFlow(accountId: existingAccountId)
            return
        }
        
        // Show loading indicator
        let alert = UIAlertController(title: "Creating Account", message: "Setting up your merchant account...", preferredStyle: .alert)
        present(alert, animated: true)
        
        // Create connected account using real backend API
        createConnectedAccountAPI { [weak self] result in
            DispatchQueue.main.async {
                alert.dismiss(animated: true) {
                    switch result {
                    case .success(let accountId):
                        self?.presentOnboardingFlow(accountId: accountId)
                    case .failure(let error):
                        self?.showError("Failed to create account: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func createConnectedAccountAPI(completion: @escaping @Sendable (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(backendBaseURL)/api/accounts") else {
            completion(.failure(NSError(domain: "InvalidURL", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid backend URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Ensure we have a selected profile
        guard let profile = selectedProfile else {
            completion(.failure(NSError(domain: "NoProfile", code: 0, userInfo: [NSLocalizedDescriptionKey: "No profile selected"])))
            return
        }
        
        // Send profile data to backend for account creation
        let requestBody: [String: Any] = [
            "profile_type": profile.type,
            "profile_data": profile.profileData,
            "business_profile": [:] // Will be filled by backend based on profile data
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { @Sendable data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received from server"])))
                return
            }
            
            do {
                if let responseString = String(data: data, encoding: .utf8) {

                }
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool,
                   success,
                   let accountId = json["account_id"] as? String {
                    print("INFO: Account created successfully with ID: \(accountId)")
                    completion(.success(accountId))
                } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let errorMessage = json["message"] as? String {
                    print("ERROR: Account creation failed with message: \(errorMessage)")
                    completion(.failure(NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                } else {
                    print("ERROR: Failed to parse account creation response")
                    completion(.failure(NSError(domain: "ParseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse server response"])))
                }
            } catch {
                print("ERROR: JSON parsing error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func presentOnboardingFlow(accountId: String) {
        // Set the account ID in shared data manager
        AppDataManager.shared.currentAccountId = accountId
        
        
        let alert = UIAlertController(
            title: "Account Created Successfully", 
            message: "Your \(BankConfiguration.current.bankDisplayName) merchant account (\(accountId)) has been created. Complete the onboarding process to start accepting payments.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Complete Onboarding", style: .default) { [weak self] _ in
            self?.startOnboardingProcess(accountId: accountId)
        })
        
        alert.addAction(UIAlertAction(title: "Later", style: .cancel) { [weak self] _ in
    
            self?.loadBusinessBankingInterface()
        })
        
        present(alert, animated: true)
    }
    
    private func startOnboardingProcess(accountId: String) {
        // Launch embedded onboarding component directly
        // No need for account links as the embedded component handles this internally
        launchOnboardingComponent(accountId: accountId)
    }
    
    private func createAccountLink(accountId: String, completion: @escaping @Sendable (Result<URL, Error>) -> Void) {
        // Call backend API to create account link for onboarding
        guard let url = URL(string: "\(backendBaseURL)/api/account_links") else {
            completion(.failure(NSError(domain: BankConfiguration.current.errorDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid backend URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let accountLinkData = [
            "account": accountId,
            "refresh_url": "\(backendBaseURL)/refresh",
            "return_url": "\(backendBaseURL)/return",
            "type": "account_onboarding"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: accountLinkData)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { @Sendable data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: BankConfiguration.current.errorDomain, code: 2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let urlString = json["url"] as? String,
                   let onboardingUrl = URL(string: urlString) {
                    completion(.success(onboardingUrl))
                } else {
                    completion(.failure(NSError(domain: BankConfiguration.current.errorDomain, code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func launchOnboardingComponent(accountId: String) {
        // Ensure the account ID is set in shared data manager
        AppDataManager.shared.currentAccountId = accountId
        print("INFO: Launching onboarding for account ID: \(accountId)")
        
        // Get onboarding settings from app settings
        let onboardingSettings = AppSettings.shared.onboardingSettings
        let collectionOptions = onboardingSettings.accountCollectionOptions
        
        // Determine if we should skip ToS collection
        let skipToS: Bool? = {
            switch onboardingSettings.skipTermsOfService {
            case .default:
                return nil // Let Stripe decide
            case .true:
                return true
            case .false:
                return false
            }
        }()
        
        print("INFO: Onboarding configuration:")
        print("INFO: - Skip ToS: \(skipToS?.description ?? "default")")
        print("INFO: - Collection fields: \(collectionOptions.fields.rawValue)")
        print("INFO: - Future requirements: \(collectionOptions.futureRequirements.rawValue)")
        
        let onboardingController = embeddedComponentManager.createAccountOnboardingController(
            fullTermsOfServiceUrl: onboardingSettings.fullTermsOfServiceUrl,
            recipientTermsOfServiceUrl: onboardingSettings.recipientTermsOfServiceUrl,
            privacyPolicyUrl: onboardingSettings.privacyPolicyUrl,
            skipTermsOfServiceCollection: skipToS,
            collectionOptions: collectionOptions
        )
        onboardingController.delegate = self
        onboardingController.title = "Complete Account Setup"
        onboardingController.present(from: self, animated: true)
    }
    
    private func showOnboardingSuccess() {
        // Don't automatically initialize Terminal SDK or show test data - wait for real status check
        
        let alert = UIAlertController(
            title: "Onboarding Submitted",
            message: "Your account information has been submitted for review. You'll be notified once your account is ready to accept payments.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            // Refresh the dashboard to show current status
            self?.loadBusinessBankingInterface()
        })
        
        present(alert, animated: true)
    }
    
    private enum BannerType {
        case pending
        case rejected
        case restrictedSoon
        case restricted
    }
    
    private func createStatusBanner(title: String, message: String, type: BannerType) -> UIView {
        let banner = UIView()
        banner.layer.cornerRadius = 12
        banner.translatesAutoresizingMaskIntoConstraints = false
        
        // Set colors based on type
        switch type {
        case .pending:
            banner.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
        case .rejected:
            banner.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        case .restrictedSoon, .restricted:
            banner.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.1)
        }
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 14, weight: .regular)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        banner.addSubview(titleLabel)
        banner.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: banner.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -16)
        ])
        
        return banner
    }
    
    private func createResumeOnboardingBanner(message: String, accountId: String) -> UIView {
        let banner = UIView()
        banner.backgroundColor = BankConfiguration.current.primaryColor.withAlphaComponent(0.1)
        banner.layer.cornerRadius = 12
        banner.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Resume Account Setup"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 14, weight: .regular)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let resumeButton = UIButton(type: .system)
        resumeButton.setTitle("Resume Setup", for: .normal)
        resumeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        resumeButton.setTitleColor(.white, for: .normal)
        resumeButton.backgroundColor = BankConfiguration.current.primaryColor
        resumeButton.layer.cornerRadius = 8
        resumeButton.translatesAutoresizingMaskIntoConstraints = false
        resumeButton.addTarget(self, action: #selector(resumeOnboardingTapped), for: .touchUpInside)
        
        banner.addSubview(titleLabel)
        banner.addSubview(messageLabel)
        banner.addSubview(resumeButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: banner.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),
            
            resumeButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 16),
            resumeButton.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            resumeButton.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),
            resumeButton.heightAnchor.constraint(equalToConstant: 44),
            resumeButton.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -16)
        ])
        
        return banner
    }
    
    private func createRequirementsNeededBanner(message: String, accountId: String) -> UIView {
        let banner = UIView()
        banner.backgroundColor = BankConfiguration.current.warningColor.withAlphaComponent(0.1)
        banner.layer.cornerRadius = 12
        banner.layer.borderWidth = 1
        banner.layer.borderColor = BankConfiguration.current.warningColor.withAlphaComponent(0.3).cgColor
        banner.translatesAutoresizingMaskIntoConstraints = false

        let iconImageView = UIImageView(image: UIImage(systemName: "exclamationmark.circle.fill"))
        iconImageView.tintColor = BankConfiguration.current.warningColor
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Account Needs Review"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 14, weight: .regular)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let provideInfoButton = UIButton(type: .system)
        provideInfoButton.setTitle("Provide Updated Information", for: .normal)
        provideInfoButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        provideInfoButton.setTitleColor(.white, for: .normal)
        provideInfoButton.backgroundColor = BankConfiguration.current.warningColor
        provideInfoButton.layer.cornerRadius = 8
        provideInfoButton.translatesAutoresizingMaskIntoConstraints = false
        provideInfoButton.addTarget(self, action: #selector(provideRequiredInfoTapped), for: .touchUpInside)
        
        banner.addSubview(iconImageView)
        banner.addSubview(titleLabel)
        banner.addSubview(messageLabel)
        banner.addSubview(provideInfoButton)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            iconImageView.topAnchor.constraint(equalTo: banner.topAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: banner.topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),
            
            messageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),
            
            provideInfoButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 16),
            provideInfoButton.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            provideInfoButton.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),
            provideInfoButton.heightAnchor.constraint(equalToConstant: 44),
            provideInfoButton.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -16)
        ])
        
        return banner
    }
    
    @objc private func resumeOnboardingTapped() {
        if let accountId = AppDataManager.shared.currentAccountId {
            launchOnboardingComponent(accountId: accountId)
        }
    }
    
    @objc private func provideRequiredInfoTapped() {
        if let accountId = AppDataManager.shared.currentAccountId {
            launchOnboardingComponent(accountId: accountId)
        }
    }
    

    
    private func createTestDataBanner() -> UIView {
        let banner = UIView()
        banner.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        banner.layer.cornerRadius = 12
        banner.layer.borderWidth = 1
        banner.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        banner.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Generate Test Data"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = UIColor.label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let messageLabel = UILabel()
        messageLabel.text = "Create sample payments and payouts to test your dashboard and embedded components"
        messageLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        messageLabel.textColor = UIColor.secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let generateButton = UIButton(type: .system)
        generateButton.setTitle("Generate Test Data", for: .normal)
        generateButton.backgroundColor = UIColor.systemBlue
        generateButton.setTitleColor(.white, for: .normal)
        generateButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        generateButton.layer.cornerRadius = 8
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        generateButton.addTarget(self, action: #selector(generateTestDataTapped), for: .touchUpInside)
        
        banner.addSubview(titleLabel)
        banner.addSubview(messageLabel) 
        banner.addSubview(generateButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: banner.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),
            
            generateButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 16),
            generateButton.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            generateButton.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),
            generateButton.heightAnchor.constraint(equalToConstant: 44),
            generateButton.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -16)
        ])
        
        return banner
    }
    
    @objc private func generateTestDataTapped() {
        createTestDataForAccount()
    }
    
    private func createTestDataForAccount() {
        guard let accountId = AppDataManager.shared.currentAccountId else {
            showError("No account ID available for test data creation")
            return
        }
        
        let loadingAlert = UIAlertController(
            title: "Creating Test Data",
            message: "Setting up test payments and payouts for your account...",
            preferredStyle: .alert
        )
        present(loadingAlert, animated: true)
        
        createTestData(accountId: accountId) { [weak self] success in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    if success {
                        self?.showTestDataSuccess()
                    } else {
                        self?.showError("Failed to create test data. Please try again later.")
                    }
                }
            }
        }
    }
    
    private func createTestData(accountId: String, completion: @escaping @Sendable (Bool) -> Void) {
        guard let url = URL(string: "\(backendBaseURL)/api/create_test_data") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["account_id": accountId]
        
        print("INFO: Creating test data for account: \(accountId)")
        print("INFO: Test data request body: \(requestBody)")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("ERROR: Failed to encode test data request: \(error)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { @Sendable data, response, error in
            if let error = error {
                print("ERROR: Test data creation network error: \(error)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("ERROR: Invalid HTTP response for test data creation")
                completion(false)
                return
            }
            
            print("INFO: Test data creation response status: \(httpResponse.statusCode)")
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("INFO: Test data creation response body: \(responseString)")
            }
            
            guard httpResponse.statusCode == 200, let data = data else {
                print("ERROR: Test data creation failed with status \(httpResponse.statusCode)")
                completion(false)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool {
                    completion(success)
                } else {
                    completion(false)
                }
            } catch {
                print("Error parsing test data response: \(error)")
                completion(false)
            }
        }.resume()
    }
    
    private func showTestDataSuccess() {
        let alert = UIAlertController(
            title: "Test Data Created!",
            message: "Your account now has sample payments and payouts. You can view all transactions in your banking dashboard.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "View Dashboard", style: .default) { [weak self] _ in
            // Mark test data as generated
            self?.hasGeneratedTestData = true
            
            // Navigate to Home tab (banking dashboard)
            self?.tabBarController?.selectedIndex = 0
            
            // Post notification to refresh dashboard (only use notification system)
            NotificationCenter.default.post(name: NSNotification.Name("TestDataCreated"), object: nil)
        })
        
        present(alert, animated: true)
    }
    
    private func showPaymentOptions() {
        let alert = UIAlertController(title: "Choose Payment Method", message: "How would you like to accept payments?", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Create Payment Link", style: .default) { [weak self] _ in
            self?.createPaymentLink()
        })
        
        alert.addAction(UIAlertAction(title: "Virtual Terminal", style: .default) { [weak self] _ in
            self?.openVirtualTerminal()
        })
        
        alert.addAction(UIAlertAction(title: "Set up Tap to Pay", style: .default) { [weak self] _ in
            self?.setupTapToPay()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showInfo(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
    
    private func createPaymentCTASection() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 0.05)
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 0.2).cgColor
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Start taking payments today"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = "Accept payments from customers with our secure payment solutions"
        descriptionLabel.font = UIFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = .darkGray
        descriptionLabel.numberOfLines = 0
        
        let ctaButton = UIButton(type: .system)
        ctaButton.setTitle("Get Started", for: .normal)
        ctaButton.backgroundColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        ctaButton.layer.cornerRadius = 8
        ctaButton.addTarget(self, action: #selector(startPaymentSetup), for: .touchUpInside)
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(descriptionLabel)
        stackView.addArrangedSubview(ctaButton)
        
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            ctaButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        return container
    }
    
    private func createQuickActionsSection() -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = "Quick Actions"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .darkGray
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let actionsStackView = UIStackView()
        actionsStackView.axis = .horizontal
        actionsStackView.distribution = .fillEqually
        actionsStackView.spacing = 12
        actionsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Quick action buttons
        let paymentLinkButton = createQuickActionButton(title: "Payment\nLinks", icon: "link", action: #selector(createPaymentLink))
        let payoutsButton = createQuickActionButton(title: "View\nPayouts", icon: "arrow.down.circle", action: #selector(viewPayouts))
        let terminalButton = createQuickActionButton(title: "Virtual\nTerminal", icon: "terminal", action: #selector(openVirtualTerminal))
        
        actionsStackView.addArrangedSubview(paymentLinkButton)
        actionsStackView.addArrangedSubview(payoutsButton)
        actionsStackView.addArrangedSubview(terminalButton)
        
        container.addSubview(titleLabel)
        container.addSubview(actionsStackView)
        
            NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            actionsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            actionsStackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            actionsStackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            actionsStackView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            actionsStackView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        return container
    }
    
    private func createQuickActionButton(title: String, icon: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.1
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 4
        stackView.isUserInteractionEnabled = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = UIFont.systemFont(ofSize: 24)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .darkGray
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        
        stackView.addArrangedSubview(iconLabel)
        stackView.addArrangedSubview(titleLabel)
        
        button.addSubview(stackView)
        button.addTarget(self, action: action, for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        
        return button
    }
    
    @objc private func startPaymentSetup() {
        // Check if we already have an account
        if let existingAccountId = AppDataManager.shared.currentAccountId {
            print("INFO: Found existing account ID: \(existingAccountId), loading dashboard")
            // Load existing account dashboard
            loadBusinessBankingInterface()
            return
        }
        
        // No existing account, create new one
        createConnectedAccount()
    }
    
    @objc private func dismissModal() {
        dismiss(animated: true)
    }
    
    @objc private func viewPayouts() {
        print("INFO: Opening payouts component")
        
        // Create embedded payouts component
        let payoutsVC = embeddedComponentManager.createPayoutsViewController()
        payoutsVC.delegate = self
        payoutsVC.title = "Payouts"
        payoutsVC.navigationItem.backButtonDisplayMode = .minimal
        
        // Add close button for modal presentation
        payoutsVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissModal)
        )
        
        // Present modally with navigation
        let navController = UINavigationController(rootViewController: payoutsVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    // MARK: - Greeting Helper
    
    private func getTimeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Good evening"
        }
    }
    
    // MARK: - Account Session API
    
    private func fetchAccountSession(accountId: String) async throws -> String? {
        print("INFO: Fetching account session for account: \(accountId)")
        
        guard let url = URL(string: "\(backendBaseURL)/api/account_session") else {
            throw NSError(domain: BankConfiguration.current.errorDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid backend URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accountId, forHTTPHeaderField: "account")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: BankConfiguration.current.errorDomain, code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: BankConfiguration.current.errorDomain, code: 2, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let clientSecret = json?["clientSecret"] as? String
        
        
        return clientSecret
    }
    
    private func fetchAccountStatus(accountId: String) async throws -> [String: Any]? {
        print("INFO: Fetching account status for account: \(accountId)")
        
        guard let url = URL(string: "\(backendBaseURL)/api/accounts/\(accountId)/status") else {
            throw NSError(domain: BankConfiguration.current.errorDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid backend URL"])
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: BankConfiguration.current.errorDomain, code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        

        

        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: BankConfiguration.current.errorDomain, code: 2, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Extract the account_status object from the response
        if let success = json?["success"] as? Bool, success,
           let accountStatus = json?["account_status"] as? [String: Any] {
    
            return accountStatus
        } else {
            print("ERROR: Backend response does not contain expected account_status format")
            if let errorMessage = json?["message"] as? String {
                throw NSError(domain: BankConfiguration.current.errorDomain, code: 3, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            return nil
        }
    }
}

// MARK: - AccountOnboardingControllerDelegate

extension MainViewController: AccountOnboardingControllerDelegate {
    nonisolated func accountOnboardingDidExit(_ accountOnboarding: AccountOnboardingController) {
        // Handle when user exits onboarding
        print("INFO: Account onboarding exited")
        
        // Immediately show loading state and disable any onboarding buttons
        DispatchQueue.main.async { [weak self] in
            self?.showOnboardingStatusCheck()
        }
        
        // Add brief delay to allow Stripe backend to process onboarding completion
        // Then check account status with retry logic
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkOnboardingCompletionStatus()
        }
    }
    
    private func showOnboardingStatusCheck() {
        // Clear existing content and show loading state
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        // Add bank account balance card first (consistent with other interfaces)
        let balanceCard = createBankAccountBalanceCard()
        stackView.addArrangedSubview(balanceCard)
        
        // Add loading banner after balance card
        let loadingBanner = createStatusCheckingBanner()
        stackView.addArrangedSubview(loadingBanner)
    }
    
    private func createStatusCheckingBanner() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        container.layer.cornerRadius = 12
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Activity indicator
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        activityIndicator.color = UIColor.systemBlue
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Checking Account Status"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = UIColor.systemBlue
        titleLabel.textAlignment = .center
        
        // Message
        let messageLabel = UILabel()
        messageLabel.text = "Verifying your onboarding completion status..."
        messageLabel.font = UIFont.systemFont(ofSize: 14)
        messageLabel.textColor = UIColor.secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        
        stackView.addArrangedSubview(activityIndicator)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(messageLabel)
        
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
        ])
        
        return container
    }
    
    private func checkOnboardingCompletionStatus(retryCount: Int = 0) {
        guard let accountId = AppDataManager.shared.currentAccountId else {
            print("ERROR: No account ID available for status check")
            loadBusinessBankingInterface()
            return
        }
        
        print("INFO: Checking onboarding completion status (attempt \(retryCount + 1))")
        
        Task {
            do {
                let statusData = try await fetchAccountStatus(accountId: accountId)
                DispatchQueue.main.async { [weak self] in
                    self?.handleOnboardingCompletionStatus(statusData: statusData, retryCount: retryCount)
                }
            } catch {
                print("ERROR: Failed to fetch account status after onboarding: \(error)")
                DispatchQueue.main.async { [weak self] in
                    // If we can't fetch status, retry up to 2 times with shorter delays
                    if retryCount < 2 {
                        let delay = Double(retryCount + 1) * 0.5 // 0.5s, 1s
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self?.checkOnboardingCompletionStatus(retryCount: retryCount + 1)
                        }
                    } else {
                        // Final fallback - just refresh normally
                        print("INFO: Network retries exhausted, showing current interface")
                        self?.loadBusinessBankingInterface()
                    }
                }
            }
        }
    }
    
    private func handleOnboardingCompletionStatus(statusData: [String: Any]?, retryCount: Int) {
        guard let statusData = statusData,
              let requirements = statusData["requirements"] as? [String: Any] else {
            print("ERROR: No requirements data in status response")
            loadBusinessBankingInterface()
            return
        }
        
        let currentlyDue = requirements["currently_due"] as? [String] ?? []
        let eventuallyDue = requirements["eventually_due"] as? [String] ?? []
        let pastDue = requirements["past_due"] as? [String] ?? []
        
        print("INFO: Post-onboarding requirements check:")
        print("INFO: Currently due: \(currentlyDue)")
        print("INFO: Eventually due: \(eventuallyDue)")
        print("INFO: Past due: \(pastDue)")
        
        // Check if onboarding is truly complete (no currently_due, past_due, or eventually_due requirements)
        let hasOutstandingRequirements = !currentlyDue.isEmpty || !pastDue.isEmpty || !eventuallyDue.isEmpty
        
        if hasOutstandingRequirements {
            print("INFO: Still has outstanding requirements, retrying...")
            // Still has requirements - retry up to 2 times with shorter delays
            if retryCount < 2 {
                let delay = Double(retryCount + 1) * 1.0 // 1s, 2s
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.checkOnboardingCompletionStatus(retryCount: retryCount + 1)
                }
            } else {
                print("INFO: Max retries reached, requirements still outstanding - showing requirements interface")
                loadBusinessBankingInterface()
            }
        } else {
            print("INFO: Onboarding completed successfully - no outstanding requirements")
            loadBusinessBankingInterface()
        }
    }
    
    nonisolated func accountOnboarding(_ accountOnboarding: AccountOnboardingController, didFailLoadWithError error: Error) {
        // Handle onboarding load errors
        print("ERROR: Account onboarding failed to load: \(error)")
        print("ERROR: Error details: \(error.localizedDescription)")
        
        DispatchQueue.main.async { [weak self] in
            self?.showAlert(
                title: "Onboarding Load Failed",
                message: "Failed to load onboarding component: \(error.localizedDescription)\n\nThis might be due to:\n• Network connectivity issues\n• Backend server issues\n• Invalid account configuration\n\nPlease try again.",
                completion: nil
            )
        }
    }
}

// MARK: - PaymentsViewControllerDelegate

extension MainViewController: PaymentsViewControllerDelegate {
    nonisolated func payments(_ payments: StripeConnect.PaymentsViewController, didFailLoadWithError error: Error) {
        print("ERROR: Payments failed to load: \(error)")
        Task { @MainActor in
            showError("Failed to load payments: \(error.localizedDescription)")
        }
    }
}

// MARK: - PayoutsViewControllerDelegate

extension MainViewController: PayoutsViewControllerDelegate {
    nonisolated func payouts(_ payouts: StripeConnect.PayoutsViewController, didFailLoadWithError error: Error) {
        print("ERROR: Payouts failed to load: \(error)")
        Task { @MainActor in
            showError("Failed to load payouts: \(error.localizedDescription)")
        }
    }
}

// MARK: - Banking Dashboard Methods

extension MainViewController {
    
    private func createAccountStatusCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .white
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
        statusLabel.text = "Loading..."
        statusLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        statusLabel.textColor = .label
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let statusIndicator = UIView()
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusIndicator.backgroundColor = .systemGray
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
        
        // Fetch and update account status
        if let accountId = AppDataManager.shared.currentAccountId {
            fetchAccountStatus(accountId: accountId) { [weak statusLabel, weak statusIndicator] status in
                DispatchQueue.main.async {
                    statusLabel?.text = status
                    statusIndicator?.backgroundColor = self.getStatusColor(for: status)
                }
            }
        }
        
        return card
    }
    
    private func createBankAccountBalanceCard() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Accounts button at the very top
        let accountsButton = UIButton(type: .system)
        accountsButton.setTitle("  Accounts", for: .normal) // Add space for icon
        accountsButton.backgroundColor = .white
        accountsButton.setTitleColor(UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1.0), for: .normal)
        accountsButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        accountsButton.layer.cornerRadius = 12
        accountsButton.layer.shadowColor = UIColor.black.cgColor
        accountsButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        accountsButton.layer.shadowOpacity = 0.1
        accountsButton.layer.shadowRadius = 2
        accountsButton.translatesAutoresizingMaskIntoConstraints = false
        accountsButton.addTarget(self, action: #selector(accountsButtonTapped), for: .touchUpInside)
        
        // Add bullet list icon to left of accounts text
        let bulletIcon = UIImageView(image: UIImage(systemName: "list.bullet"))
        bulletIcon.tintColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1.0)
        bulletIcon.translatesAutoresizingMaskIntoConstraints = false
        accountsButton.addSubview(bulletIcon)
        
        // Bank account panel below
        let card = UIView()
        card.backgroundColor = BankConfiguration.current.primaryColor
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        
        // Bank logo placeholder + account name (top left)
        let accountInfoContainer = UIView()
        accountInfoContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let logoPlaceholder = UIView()
        logoPlaceholder.backgroundColor = .white.withAlphaComponent(0.3)
        logoPlaceholder.layer.cornerRadius = 12
        logoPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        
        // Bank logo image - will be updated when branding loads
        let logoImageView = UIImageView()
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set initial logo (fallback or dynamic)
        updateLogoImage(logoImageView)
        
        // Fallback text if image not found
        let logoLabel = UILabel()
        logoLabel.text = BankConfiguration.current.bankDisplayName
        logoLabel.font = .systemFont(ofSize: 8, weight: .bold)
        logoLabel.textColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1.0)
        logoLabel.textAlignment = .center
        logoLabel.translatesAutoresizingMaskIntoConstraints = false
        logoLabel.isHidden = logoImageView.image != nil // Hide text if image exists
        
        let accountNameLabel = UILabel()
        accountNameLabel.text = BankConfiguration.current.currentAccountName
        accountNameLabel.font = .systemFont(ofSize: 14, weight: .medium)
        accountNameLabel.textColor = .white
        accountNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        logoPlaceholder.addSubview(logoImageView)
        logoPlaceholder.addSubview(logoLabel)
        accountInfoContainer.addSubview(logoPlaceholder)
        accountInfoContainer.addSubview(accountNameLabel)
        
        // Balance (bottom left)
        let balanceLabel = UILabel()
        balanceLabel.text = "£\(String(format: "%.2f", businessAccount.balance))"
        balanceLabel.font = .systemFont(ofSize: 28, weight: .bold)
        balanceLabel.textColor = .white
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Details button (top right)
        let detailsButton = UIButton(type: .system)
        detailsButton.setTitle("Details >", for: .normal)
        detailsButton.setTitleColor(.white.withAlphaComponent(0.9), for: .normal)
        detailsButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        detailsButton.translatesAutoresizingMaskIntoConstraints = false
        detailsButton.addTarget(self, action: #selector(accountDetailsButtonTapped), for: .touchUpInside)
        
        container.addSubview(accountsButton)
        container.addSubview(card)
        card.addSubview(accountInfoContainer)
        card.addSubview(balanceLabel)
        card.addSubview(detailsButton)
        
        NSLayoutConstraint.activate([
            // Accounts button at very top - smaller and centered
            accountsButton.topAnchor.constraint(equalTo: container.topAnchor),
            accountsButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            accountsButton.widthAnchor.constraint(equalToConstant: 120),
            accountsButton.heightAnchor.constraint(equalToConstant: 36),
            
            // Bullet icon to the left of accounts text
            bulletIcon.leadingAnchor.constraint(equalTo: accountsButton.leadingAnchor, constant: 12),
            bulletIcon.centerYAnchor.constraint(equalTo: accountsButton.centerYAnchor),
            bulletIcon.widthAnchor.constraint(equalToConstant: 14),
            bulletIcon.heightAnchor.constraint(equalToConstant: 14),
            
            // Bank account card below accounts button
            card.topAnchor.constraint(equalTo: accountsButton.bottomAnchor, constant: 12),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            card.heightAnchor.constraint(equalToConstant: 100),
            
            // Logo placeholder in account info container
            logoPlaceholder.leadingAnchor.constraint(equalTo: accountInfoContainer.leadingAnchor),
            logoPlaceholder.centerYAnchor.constraint(equalTo: accountInfoContainer.centerYAnchor),
            logoPlaceholder.widthAnchor.constraint(equalToConstant: 24),
            logoPlaceholder.heightAnchor.constraint(equalToConstant: 24),
            
            // Logo image constraints
            logoImageView.centerXAnchor.constraint(equalTo: logoPlaceholder.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: logoPlaceholder.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalTo: logoPlaceholder.widthAnchor, constant: -4),
            logoImageView.heightAnchor.constraint(equalTo: logoPlaceholder.heightAnchor, constant: -4),
            
            // Fallback text constraints (centered same as image)
            logoLabel.centerXAnchor.constraint(equalTo: logoPlaceholder.centerXAnchor),
            logoLabel.centerYAnchor.constraint(equalTo: logoPlaceholder.centerYAnchor),
            
            // Account name next to logo
            accountNameLabel.leadingAnchor.constraint(equalTo: logoPlaceholder.trailingAnchor, constant: 8),
            accountNameLabel.centerYAnchor.constraint(equalTo: accountInfoContainer.centerYAnchor),
            accountNameLabel.trailingAnchor.constraint(equalTo: accountInfoContainer.trailingAnchor),
            
            // Account info container (top left)
            accountInfoContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            accountInfoContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            accountInfoContainer.heightAnchor.constraint(equalToConstant: 24),
            
            // Balance (bottom left)
            balanceLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            balanceLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            
            // Details button (top right)
            detailsButton.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            detailsButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20)
        ])
        
        return container
    }
    
    private func createBankingActionButtons() -> UIView {
        let container = UIView()
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 20
        
        let sendButton = createActionButton(title: "Send", icon: "arrow.up", color: BankConfiguration.current.primaryColor, action: #selector(sendButtonTapped))
        let receiveButton = createActionButton(title: "Get paid", icon: "arrow.down", color: BankConfiguration.current.primaryColor, action: #selector(getPaidButtonTapped))
        let cardReaderButton = createActionButton(title: "Card Reader", icon: "creditcard", color: BankConfiguration.current.primaryColor, action: nil as Selector?)
        let cardsButton = createActionButton(title: "Cards", icon: "rectangle.stack", color: BankConfiguration.current.primaryColor, action: nil as Selector?)
        
        stackView.addArrangedSubview(sendButton)
        stackView.addArrangedSubview(receiveButton)
        stackView.addArrangedSubview(cardReaderButton)
        stackView.addArrangedSubview(cardsButton)
        
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        return container
    }
    
    private func createActionButton(title: String, icon: String, color: UIColor, action: Selector?) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = color
        button.layer.cornerRadius = 25
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.tintColor = .white
        
        // Add action if provided
        if let action = action {
            button.addTarget(self, action: action, for: .touchUpInside)
        }
        
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
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    @objc private func sendButtonTapped() {
        presentSendModal()
    }
    
    @objc private func getPaidButtonTapped() {
        presentGetPaidModal()
    }
    
    @objc private func accountDetailsButtonTapped() {
        let detailsVC = AccountDetailsViewController()
        let navController = UINavigationController(rootViewController: detailsVC)
        present(navController, animated: true)
    }
    
    private func presentSendModal() {
        let alert = UIAlertController(title: "Send Money", message: "Available balance: £\(String(format: "%.2f", businessAccount.balance))", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Make a payment", style: .default) { _ in
            print("Make a payment selected")
        })
        
        alert.addAction(UIAlertAction(title: "Make an international payment", style: .default) { _ in
            print("International payment selected")
        })
        
        alert.addAction(UIAlertAction(title: "Run your own payroll", style: .default) { _ in
            print("Payroll selected")
        })
        
        alert.addAction(UIAlertAction(title: "Upcoming payments", style: .default) { _ in
            print("Upcoming payments selected")
        })
        
        alert.addAction(UIAlertAction(title: "Payment approvals", style: .default) { _ in
            print("Payment approvals selected")
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func presentGetPaidModal() {
        let alert = UIAlertController(title: "Get Paid", message: "\(BankConfiguration.current.currentAccountName): £\(String(format: "%.2f", businessAccount.balance))", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Add money", style: .default) { _ in
            print("Add money selected")
        })
        
        alert.addAction(UIAlertAction(title: "Sell items online", style: .default) { _ in
            print("Sell items online selected")
        })
        
        alert.addAction(UIAlertAction(title: "Create an invoice", style: .default) { _ in
            print("Create invoice selected")
        })
        
        alert.addAction(UIAlertAction(title: "Send a Payment Link", style: .default) { _ in
            print("Payment link selected")
        })
        
        alert.addAction(UIAlertAction(title: "Request money", style: .default) { _ in
            print("Request money selected")
        })
        
        alert.addAction(UIAlertAction(title: "Tap to Pay on iPhone", style: .default) { _ in
            print("Tap to Pay selected")
        })
        
        alert.addAction(UIAlertAction(title: "Share account details", style: .default) { _ in
            print("Share account details selected")
        })
        
        alert.addAction(UIAlertAction(title: "Deposit cash and cheques", style: .default) { _ in
            print("Deposit cash selected")
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func createTapToPaySection() -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 1)
        card.layer.shadowOpacity = 0.1
        card.layer.shadowRadius = 3
        
        // Main icon
        let iconImageView = UIImageView(image: UIImage(systemName: "wave.3.right"))
        iconImageView.tintColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1.0)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title with NFC icon
        let titleContainer = UIView()
        titleContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Tap to Pay on iPhone"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let nfcIcon = UIImageView(image: UIImage(systemName: "wave.3.right.circle"))
        nfcIcon.tintColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1.0)
        nfcIcon.translatesAutoresizingMaskIntoConstraints = false
        
        titleContainer.addSubview(titleLabel)
        titleContainer.addSubview(nfcIcon)
        
        // Input field container
        let inputContainer = UIView()
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.backgroundColor = .systemGray6
        inputContainer.layer.cornerRadius = 8
        
        let currencyLabel = UILabel()
        currencyLabel.text = "£"
        currencyLabel.font = .systemFont(ofSize: 16, weight: .medium)
        currencyLabel.textColor = .label
        currencyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let amountTextField = UITextField()
        amountTextField.placeholder = "0.00"
        amountTextField.keyboardType = .decimalPad
        amountTextField.font = .systemFont(ofSize: 16)
        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Take payment button
        let takePaymentButton = UIButton(type: .system)
        takePaymentButton.setTitle("Take payment", for: .normal)
        takePaymentButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        takePaymentButton.backgroundColor = .systemGray4
        takePaymentButton.setTitleColor(.white, for: .normal)
        takePaymentButton.layer.cornerRadius = 8
        takePaymentButton.isEnabled = false
        takePaymentButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Add text field target to enable/disable button
        amountTextField.addTarget(self, action: #selector(amountTextFieldChanged(_:)), for: .editingChanged)
        takePaymentButton.addTarget(self, action: #selector(takePaymentButtonTapped(_:)), for: .touchUpInside)
        takePaymentButton.tag = 100 // Tag to identify the button
        amountTextField.tag = 101 // Tag to identify the text field
        
        inputContainer.addSubview(currencyLabel)
        inputContainer.addSubview(amountTextField)
        
        card.addSubview(iconImageView)
        card.addSubview(titleContainer)
        card.addSubview(inputContainer)
        card.addSubview(takePaymentButton)
        
        NSLayoutConstraint.activate([
            // Title container
            titleLabel.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor),
            
            nfcIcon.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            nfcIcon.trailingAnchor.constraint(equalTo: titleContainer.trailingAnchor),
            nfcIcon.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor),
            nfcIcon.widthAnchor.constraint(equalToConstant: 20),
            nfcIcon.heightAnchor.constraint(equalToConstant: 20),
            
            // Main icon
            iconImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconImageView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            // Title container
            titleContainer.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleContainer.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -16),
            titleContainer.heightAnchor.constraint(equalToConstant: 24),
            
            // Input container
            inputContainer.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor),
            inputContainer.topAnchor.constraint(equalTo: titleContainer.bottomAnchor, constant: 12),
            inputContainer.widthAnchor.constraint(equalToConstant: 100),
            inputContainer.heightAnchor.constraint(equalToConstant: 36),
            
            // Currency label
            currencyLabel.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 8),
            currencyLabel.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            
            // Amount text field
            amountTextField.leadingAnchor.constraint(equalTo: currencyLabel.trailingAnchor, constant: 4),
            amountTextField.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -8),
            amountTextField.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            
            // Take payment button
            takePaymentButton.leadingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: 12),
            takePaymentButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            takePaymentButton.widthAnchor.constraint(equalToConstant: 120),
            takePaymentButton.heightAnchor.constraint(equalToConstant: 36),
            
            // Card height
            card.heightAnchor.constraint(equalToConstant: 100),
            card.bottomAnchor.constraint(greaterThanOrEqualTo: inputContainer.bottomAnchor, constant: 16)
        ])
        
        return card
    }
    
    @objc private func amountTextFieldChanged(_ textField: UITextField) {
        // Find the take payment button in the same parent view
        guard let card = textField.superview?.superview,
              let button = card.viewWithTag(100) as? UIButton else { return }
        
        let hasText = !(textField.text?.isEmpty ?? true)
        button.isEnabled = hasText
        button.backgroundColor = hasText ? UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1.0) : .systemGray4
    }
    
    @objc private func takePaymentButtonTapped(_ sender: UIButton) {
        print("💳 UI: Take payment button tapped on MainViewController")
        
        // Find the amount text field in the same parent view - using safer approach
        var amountTextField: UITextField?
        var currentView = sender.superview
        
        // Walk up the view hierarchy to find the text field
        while currentView != nil {
            if let textField = currentView?.viewWithTag(101) as? UITextField {
                amountTextField = textField
                break
            }
            currentView = currentView?.superview
        }
        
        guard let textField = amountTextField,
              let amountText = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !amountText.isEmpty else {
            print("Invalid amount input - empty or nil")
            showAlert(title: "Invalid Amount", message: "Please enter a valid amount.", completion: nil)
            return
        }
        
        // Validate amount using NSDecimalNumber for precision and handle edge cases
        guard let amount = validateAndParseAmount(amountText) else {
            print("Invalid amount format: \(amountText)")
            showAlert(title: "Invalid Amount", message: "Please enter a valid amount (e.g., 10.50).", completion: nil)
            return
        }
        
        // Additional validation for reasonable payment amounts
        if amount < 0.01 {
            print("Amount too small: \(amount)")
            showAlert(title: "Invalid Amount", message: "Amount must be at least £0.01.", completion: nil)
            return
        }
        
        if amount > 10000.00 {
            print("Amount too large: \(amount)")
            showAlert(title: "Invalid Amount", message: "Amount must be less than £10,000.00.", completion: nil)
            return
        }
        
        print("💳 UI: Opening payment collection for \(amount) GBP (amount in cents: \(Int(amount * 100)))")
        
        // Create and present payment collection screen
        let paymentVC = PaymentCollectionViewController(amount: amount, terminalManager: terminalManager)
        paymentVC.delegate = self
        
        let navController = UINavigationController(rootViewController: paymentVC)
        navController.modalPresentationStyle = UIModalPresentationStyle.formSheet
        
        present(navController, animated: true)
    }
    
    /// Validates and parses amount string to Double with proper error handling
    private func validateAndParseAmount(_ amountText: String) -> Double? {
        // Remove any currency symbols and whitespace
        let cleanedText = amountText.replacingOccurrences(of: "£", with: "")
                                   .replacingOccurrences(of: "$", with: "")
                                   .replacingOccurrences(of: "€", with: "")
                                   .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Use NSDecimalNumber for precise decimal handling
        let decimal = NSDecimalNumber(string: cleanedText, locale: Locale.current)
        
        // Check for parsing errors
        guard decimal != NSDecimalNumber.notANumber else {
            return nil
        }
        
        let doubleValue = decimal.doubleValue
        
        // Check for reasonable bounds
        guard doubleValue >= 0 && doubleValue.isFinite else {
            return nil
        }
        
        return doubleValue
    }
    
    private func connectToSimulatedReader(completion: @escaping @Sendable (Bool) -> Void) {
        // Store completion for when connection actually completes
        terminalManager.onConnectionComplete = completion
        
        terminalManager.discoverSimulatedReaders { @Sendable [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Discovery successful - connection will happen in delegate callback
                    print("📱 Discovery successful, waiting for connection...")
                case .failure(let error):
                    self?.showAlert(title: "Connection Failed", message: "Failed to connect to simulated reader: \(error.localizedDescription)", completion: nil)
                    completion(false)
                }
            }
        }
    }
    
    private func processPayment(amount: UInt, button: UIButton, textField: UITextField) {
        // Update button to show payment processing
        button.setTitle("Processing...", for: .normal)
        
        terminalManager.collectPayment(amount: amount, currency: "gbp", customer: nil) { [weak self] (result: Result<PaymentIntent, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let paymentIntent):
                    self?.handlePaymentSuccess(paymentIntent: paymentIntent, button: button, textField: textField)
                case .failure(let error):
                    // Check if it's a connection error that might need user awareness
                    if error.localizedDescription.lowercased().contains("reconnecting") {
                        button.setTitle("Reconnecting...", for: .normal)
                        // Retry after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self?.processPayment(amount: amount, button: button, textField: textField)
                        }
                    } else {
                        self?.handlePaymentError(error: error, button: button, textField: textField)
                    }
                }
            }
        }
    }
    
    private func handlePaymentSuccess(paymentIntent: PaymentIntent, button: UIButton, textField: UITextField) {
        let amount = Double(paymentIntent.amount) / 100.0
        let formattedAmount = String(format: "%.2f", amount)
        
        // Log payment ID for debugging (not shown to user)
        print("INFO: Payment successful! Payment ID: \(paymentIntent.stripeId ?? "unknown")")
        
        showAlert(
            title: "Payment Successful! 🎉",
            message: "Payment of £\(formattedAmount) completed successfully.",
            completion: { [weak self] in
                self?.resetPaymentButton(button, textField: textField)
                // Clear the amount field
                textField.text = ""
                self?.amountTextFieldChanged(textField)
            }
        )
    }
    
    private func handlePaymentError(error: Error, button: UIButton, textField: UITextField) {
        showAlert(
            title: "Payment Failed",
            message: "Payment failed: \(error.localizedDescription)",
            completion: { [weak self] in
                self?.resetPaymentButton(button, textField: textField)
            }
        )
    }
    
    private func resetPaymentButton(_ button: UIButton, textField: UITextField) {
        button.setTitle("Take payment", for: .normal)
        let hasText = !(textField.text?.isEmpty ?? true)
        button.isEnabled = hasText
        button.backgroundColor = hasText ? UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1.0) : .systemGray4
    }
    
    // MARK: - Terminal SDK Setup
    
    private func initializeTerminalSDKForOnboardedAccount() {
        // Only initialize Terminal SDK if we have a valid account ID (onboarding complete)
        guard AppDataManager.shared.currentAccountId != nil else {
            print("INFO: Skipping Terminal SDK initialization - no account ID")
            return
        }
        
        print("INFO: Initializing Terminal SDK for onboarded account")
        
        // Terminal SDK is initialized automatically via TerminalManager.shared
        // Connect to simulated reader in the background for faster payments
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.connectToSimulatedReaderInBackground()
        }
    }
    

    
    private func connectToSimulatedReaderInBackground() {
        guard !terminalManager.isConnectedToReader else { return }
        
        terminalManager.discoverSimulatedReaders { [weak self] result in
            switch result {
            case .success:
                print("INFO: Background connection to simulated Tap to Pay reader successful")
            case .failure(let error):
                print("WARN: Background connection to simulated reader failed: \(error.localizedDescription)")
                // Schedule retry in 30 seconds for background connections
                DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                    self?.connectToSimulatedReaderInBackground()
                }
            }
        }
    }
    
    private func createTransactionsSection() -> UIView {
        let container = UIView()
        
        let headerLabel = UILabel()
        headerLabel.text = "Transactions"
        headerLabel.font = .systemFont(ofSize: 20, weight: .bold)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Create transactions list (bank transactions + bank payouts)
        let transactionsList = createBankTransactionsList()
        // Allow transactions to expand vertically
        transactionsList.setContentHuggingPriority(.defaultLow, for: .vertical)
        transactionsList.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        container.addSubview(headerLabel)
        container.addSubview(transactionsList)
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: container.topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            transactionsList.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16),
            transactionsList.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            transactionsList.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            transactionsList.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createBankTransactionsList() -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 12
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOffset = CGSize(width: 0, height: 1)
        container.layer.shadowOpacity = 0.1
        container.layer.shadowRadius = 3
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Sample transactions (limit to 3)
        let transactions = [
            ("\(BankConfiguration.current.bankDisplayName) Payout", "Settlement", "+£42.50", "today", BankConfiguration.current.bankName.lowercased()),
            ("STARBUCKS", "Card payment", "-£4.75", "yesterday", "starbucks"),
            ("AMAZON", "Online purchase", "-£29.99", "2 days ago", "amazon")
        ]
        
        for (index, transaction) in transactions.enumerated() {
            let transactionView = createTransactionRow(
                title: transaction.0,
                subtitle: transaction.1,
                amount: transaction.2,
                date: transaction.3,
                type: transaction.4
            )
            stackView.addArrangedSubview(transactionView)
            
            // Add separator except for last item
            if index < transactions.count - 1 {
                let separator = UIView()
                separator.backgroundColor = .systemGray5
                separator.translatesAutoresizingMaskIntoConstraints = false
                separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
                stackView.addArrangedSubview(separator)
            }
        }
        
        // Add flexible space before view more button to push it to bottom
        let spacerView = UIView()
        spacerView.setContentHuggingPriority(.defaultLow, for: .vertical)
        spacerView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(spacerView)
        
        // View more button
        let viewMoreButton = UIButton(type: .system)
        viewMoreButton.setTitle("View more", for: .normal)
        viewMoreButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        viewMoreButton.setTitleColor(UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1.0), for: .normal)
        viewMoreButton.layer.cornerRadius = 20
        viewMoreButton.layer.borderWidth = 1
        viewMoreButton.layer.borderColor = UIColor.systemGray4.cgColor
        viewMoreButton.backgroundColor = .systemBackground
        viewMoreButton.translatesAutoresizingMaskIntoConstraints = false
        viewMoreButton.addTarget(self, action: #selector(viewMoreTransactionsTapped), for: .touchUpInside)
        // Keep view more button at a fixed height
        viewMoreButton.setContentHuggingPriority(.required, for: .vertical)
        
        stackView.addArrangedSubview(viewMoreButton)
        
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            
            viewMoreButton.heightAnchor.constraint(equalToConstant: 44),
            viewMoreButton.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 16),
            viewMoreButton.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: -16)
        ])
        
        return container
    }
    
    private func createTransactionRow(title: String, subtitle: String, amount: String, date: String, type: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        
        // Icon based on transaction type
        let iconView = UIView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.backgroundColor = getTransactionIconColor(for: type)
        iconView.layer.cornerRadius = 20
        
        let iconLabel = UILabel()
        iconLabel.text = getTransactionIcon(for: type)
        iconLabel.textColor = .white
        iconLabel.font = .systemFont(ofSize: 14, weight: .bold)
        iconLabel.textAlignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        
        iconView.addSubview(iconLabel)
        
        // Transaction details
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Amount and date
        let amountLabel = UILabel()
        amountLabel.text = amount
        amountLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        amountLabel.textColor = amount.hasPrefix("+") ? .systemGreen : .label
        amountLabel.textAlignment = .right
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let dateLabel = UILabel()
        dateLabel.text = date
        dateLabel.font = .systemFont(ofSize: 12)
        dateLabel.textColor = .secondaryLabel
        dateLabel.textAlignment = .right
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        row.addSubview(iconView)
        row.addSubview(titleLabel)
        row.addSubview(subtitleLabel)
        row.addSubview(amountLabel)
        row.addSubview(dateLabel)
        
        NSLayoutConstraint.activate([
            // Icon
            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            
            iconLabel.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            
            // Transaction details
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -8),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: dateLabel.leadingAnchor, constant: -8),
            subtitleLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -16),
            
            // Amount and date
            amountLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            amountLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),
            
            dateLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            dateLabel.topAnchor.constraint(equalTo: amountLabel.bottomAnchor, constant: 2),
            dateLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -16)
        ])
        
        return row
    }
    
    private func getTransactionIcon(for type: String) -> String {
        switch type {
        case BankConfiguration.current.bankName.lowercased():
            return String(BankConfiguration.current.bankDisplayName.prefix(1))
        case "starbucks":
            return "S"
        case "amazon":
            return "A"
        default:
            return "T"
        }
    }
    
    private func getTransactionIconColor(for type: String) -> UIColor {
        switch type {
        case BankConfiguration.current.bankName.lowercased():
            return BankConfiguration.current.primaryColor
        case "starbucks":
            return UIColor(red: 0/255, green: 112/255, blue: 74/255, alpha: 1.0)
        case "amazon":
            return UIColor(red: 255/255, green: 153/255, blue: 0/255, alpha: 1.0)
        default:
            return .systemGray
        }
    }
    
    @objc private func viewMoreTransactionsTapped() {
        // Present a full transactions view (temporary implementation)
        let transactionsVC = createFullTransactionsViewController()
        let navController = UINavigationController(rootViewController: transactionsVC)
        navController.modalPresentationStyle = .fullScreen
        
        present(navController, animated: true)
    }
    
    private func createFullTransactionsViewController() -> UIViewController {
        let vc = EnhancedTransactionsViewController()
        return vc
    }
    
    @objc private func dismissFullTransactions() {
        dismiss(animated: true)
    }
    
    @objc private func userProfileTapped() {
        presentUserProfileModal()
    }
    
    @objc private func accountsButtonTapped() {
        presentAccountsScreen()
    }
    
    private func presentUserProfileModal() {
        let alert = UIAlertController(
            title: "👤 John Appleseed", 
            message: "john.appleseed@example.com", 
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "👤 Profile", style: .default) { _ in
            print("Profile tapped")
        })
        
        alert.addAction(UIAlertAction(title: "⚙️ Settings", style: .default) { [weak self] _ in
            print("Settings tapped")
            self?.presentSettings()
        })
        
        alert.addAction(UIAlertAction(title: "🤝 Refer a Friend", style: .default) { _ in
            print("Refer a friend tapped")
        })
        
        alert.addAction(UIAlertAction(title: "🏆 Rewards", style: .default) { _ in
            print("Rewards tapped")
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.leftBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    private func presentAccountsScreen() {
        let accountsVC = AllAccountsViewController()
        let navController = UINavigationController(rootViewController: accountsVC)
        present(navController, animated: true)
    }
    
    private func createEmbeddedPaymentsView() -> UIView {
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
    
    private func fetchAccountStatus(accountId: String, completion: @escaping @Sendable (String) -> Void) {
        guard let url = URL(string: "\(backendBaseURL)/api/accounts/\(accountId)/status") else {
            completion("Unknown")
            return
        }
        
        URLSession.shared.dataTask(with: url) { @Sendable data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accountStatus = json["account_status"] as? [String: Any],
                  let status = accountStatus["status"] as? String else {
                completion("Unknown")
                return
            }
            
            completion(status)
        }.resume()
    }
    
    private func getStatusColor(for status: String) -> UIColor {
        switch status.lowercased() {
        case "enabled":
            return BankConfiguration.current.successColor
        case "pending":
            return BankConfiguration.current.warningColor
        case "restricted", "restricted soon":
            return BankConfiguration.current.errorColor
        case "rejected":
            return BankConfiguration.current.errorColor
        default:
            return .systemGray
        }
    }
}

// MARK: - All Accounts View Controller
class AllAccountsViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "All Accounts"
        view.backgroundColor = .systemGroupedBackground
        
        // Add close button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = BankConfiguration.current.primaryColor
        
        setupAccountsList()
    }
    
    private func setupAccountsList() {
        let scrollView = UIScrollView()
        let contentView = UIView()
        let stackView = UIStackView()
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        stackView.axis = .vertical
        stackView.spacing = 12
        
        // Current account
        let currentAccount = createAccountCard(
            name: BankConfiguration.current.currentAccountName,
            balance: "£25,117.27",
            accountNumber: "****6789",
            isPrimary: true
        )
        stackView.addArrangedSubview(currentAccount)
        
        // Savings account
        let savingsAccount = createAccountCard(
            name: BankConfiguration.current.businessSavingsName,
            balance: "£8,450.00",
            accountNumber: "****2341",
            isPrimary: false
        )
        stackView.addArrangedSubview(savingsAccount)
        
        // Credit account
        let creditAccount = createAccountCard(
            name: BankConfiguration.current.businessCreditCardName,
            balance: "£2,150.00 available",
            accountNumber: "****9876",
            isPrimary: false
        )
        stackView.addArrangedSubview(creditAccount)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func createAccountCard(name: String, balance: String, accountNumber: String, isPrimary: Bool) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 1)
        card.layer.shadowOpacity = 0.1
        card.layer.shadowRadius = 3
        card.translatesAutoresizingMaskIntoConstraints = false
        
        // Primary indicator
        if isPrimary {
            let primaryBadge = UILabel()
            primaryBadge.text = "PRIMARY"
            primaryBadge.font = .systemFont(ofSize: 10, weight: .bold)
            primaryBadge.textColor = BankConfiguration.current.primaryColor
            primaryBadge.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(primaryBadge)
            
            NSLayoutConstraint.activate([
                primaryBadge.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
                primaryBadge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
            ])
        }
        
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let balanceLabel = UILabel()
        balanceLabel.text = balance
        balanceLabel.font = .systemFont(ofSize: 20, weight: .bold)
        balanceLabel.textColor = BankConfiguration.current.primaryColor
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let accountNumberLabel = UILabel()
        accountNumberLabel.text = accountNumber
        accountNumberLabel.font = .systemFont(ofSize: 14)
        accountNumberLabel.textColor = .secondaryLabel
        accountNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(nameLabel)
        card.addSubview(balanceLabel)
        card.addSubview(accountNumberLabel)
        
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: isPrimary ? 32 : 16),
            nameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            
            balanceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            balanceLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            balanceLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            
            accountNumberLabel.topAnchor.constraint(equalTo: balanceLabel.bottomAnchor, constant: 4),
            accountNumberLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            accountNumberLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            accountNumberLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            
            card.heightAnchor.constraint(equalToConstant: isPrimary ? 120 : 100)
        ])
        
        return card
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
}

// MARK: - Enhanced Transactions View Controller
class EnhancedTransactionsViewController: UIViewController {
    
    enum TransactionFilter {
        case all
        case incoming
        case outgoing
        case thisMonth
        case custom(startDate: Date, endDate: Date)
    }
    
    private var currentFilter: TransactionFilter = .all
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var stackView: UIStackView!
    
    // Sample transaction data with proper dates
    private let allTransactions: [(title: String, subtitle: String, amount: String, date: Date, type: String)] = [
        ("\(BankConfiguration.current.bankDisplayName) Payout", "Settlement", "+£127.35", Calendar.current.date(byAdding: .day, value: 0, to: Date())!, BankConfiguration.current.bankName.lowercased()),
        ("STARBUCKS", "Card payment", "-£4.75", Calendar.current.date(byAdding: .day, value: 0, to: Date())!, "starbucks"),
        ("TESCO", "Contactless payment", "-£23.40", Calendar.current.date(byAdding: .day, value: 0, to: Date())!, "tesco"),
        ("\(BankConfiguration.current.bankDisplayName) Payout", "Settlement", "+£89.20", Calendar.current.date(byAdding: .day, value: -1, to: Date())!, BankConfiguration.current.bankName.lowercased()),
        ("AMAZON", "Online purchase", "-£29.99", Calendar.current.date(byAdding: .day, value: -1, to: Date())!, "amazon"),
        ("UBER", "Transportation", "-£12.50", Calendar.current.date(byAdding: .day, value: -1, to: Date())!, "uber"),
        ("DELIVEROO", "Food delivery", "-£18.75", Calendar.current.date(byAdding: .day, value: -2, to: Date())!, "deliveroo"),
        ("\(BankConfiguration.current.bankDisplayName) Payout", "Settlement", "+£203.60", Calendar.current.date(byAdding: .day, value: -2, to: Date())!, BankConfiguration.current.bankName.lowercased()),
        ("SAINSBURYS", "Grocery shopping", "-£45.80", Calendar.current.date(byAdding: .day, value: -2, to: Date())!, "sainsburys"),
        ("SPOTIFY", "Monthly subscription", "-£9.99", Calendar.current.date(byAdding: .day, value: -3, to: Date())!, "spotify"),
        ("SHELL", "Fuel payment", "-£52.30", Calendar.current.date(byAdding: .day, value: -3, to: Date())!, "fuel"),
        ("\(BankConfiguration.current.bankDisplayName) Payout", "Settlement", "+£76.45", Calendar.current.date(byAdding: .day, value: -3, to: Date())!, BankConfiguration.current.bankName.lowercased()),
        ("MCDONALD'S", "Fast food", "-£8.60", Calendar.current.date(byAdding: .day, value: -4, to: Date())!, "mcdonalds"),
        ("NETFLIX", "Monthly subscription", "-£12.99", Calendar.current.date(byAdding: .day, value: -4, to: Date())!, "netflix"),
        ("JOHN LEWIS", "Shopping", "-£78.50", Calendar.current.date(byAdding: .day, value: -5, to: Date())!, "shopping"),
        ("\(BankConfiguration.current.bankDisplayName) Payout", "Settlement", "+£156.78", Calendar.current.date(byAdding: .day, value: -5, to: Date())!, BankConfiguration.current.bankName.lowercased()),
        ("COSTA COFFEE", "Coffee", "-£3.20", Calendar.current.date(byAdding: .day, value: -6, to: Date())!, "coffee"),
        ("PAYPAL", "Online payment", "-£42.00", Calendar.current.date(byAdding: .day, value: -7, to: Date())!, "paypal")
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Transactions"
        view.backgroundColor = .systemGroupedBackground
        
        setupNavigationBar()
        setupUI()
        refreshTransactions()
    }
    
    private func setupNavigationBar() {
        // Close button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(dismissTransactions)
        )
        navigationItem.leftBarButtonItem?.tintColor = BankConfiguration.current.primaryColor
        
        // Filter button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            style: .plain,
            target: self,
            action: #selector(showFilterOptions)
        )
        navigationItem.rightBarButtonItem?.tintColor = BankConfiguration.current.primaryColor
    }
    
    private func setupUI() {
        // Balance summary card
        let balanceCard = createBalanceSummaryCard()
        
        // Filter chips
        let filterChips = createFilterChips()
        
        // Scroll view for transactions
        scrollView = UIScrollView()
        contentView = UIView()
        stackView = UIStackView()
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(balanceCard)
        view.addSubview(filterChips)
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        stackView.axis = .vertical
        stackView.spacing = 0
        
        NSLayoutConstraint.activate([
            // Balance card - let it size itself based on content
            balanceCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            balanceCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            balanceCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Filter chips
            filterChips.topAnchor.constraint(equalTo: balanceCard.bottomAnchor, constant: 16),
            filterChips.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            filterChips.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            filterChips.heightAnchor.constraint(equalToConstant: 40),
            
            // Scroll view for transactions
            scrollView.topAnchor.constraint(equalTo: filterChips.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    private func createBalanceSummaryCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 1)
        card.layer.shadowOpacity = 0.1
        card.layer.shadowRadius = 3
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Current Balance"
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let balanceLabel = UILabel()
        balanceLabel.text = "£25,117.27"
        balanceLabel.font = .systemFont(ofSize: 24, weight: .bold)
        balanceLabel.textColor = .label
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let summaryLabel = UILabel()
        summaryLabel.text = "18 transactions this month"
        summaryLabel.font = .systemFont(ofSize: 12, weight: .regular)
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(titleLabel)
        card.addSubview(balanceLabel)
        card.addSubview(summaryLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            
            balanceLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            balanceLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            
            summaryLabel.topAnchor.constraint(equalTo: balanceLabel.bottomAnchor, constant: 4),
            summaryLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            summaryLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
        
        return card
    }
    
    private func createFilterChips() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let filters = [
            ("All", TransactionFilter.all),
            ("Incoming", TransactionFilter.incoming),
            ("Outgoing", TransactionFilter.outgoing)
        ]
        
        for (title, filter) in filters {
            let chip = createFilterChip(title: title, filter: filter)
            stackView.addArrangedSubview(chip)
        }
        
        container.addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        return container
    }
    
    private func createFilterChip(title: String, filter: TransactionFilter) -> UIButton {
        let chip = UIButton(type: .system)
        chip.setTitle(title, for: .normal)
        chip.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        chip.layer.cornerRadius = 16
        chip.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        chip.translatesAutoresizingMaskIntoConstraints = false
        
        let isSelected = isFilterSelected(filter)
        chip.backgroundColor = isSelected ? BankConfiguration.current.primaryColor : .systemGray6
        chip.setTitleColor(isSelected ? .white : .label, for: .normal)
        
        chip.addTarget(self, action: #selector(filterChipTapped(_:)), for: .touchUpInside)
        chip.tag = getFilterTag(filter)
        
        return chip
    }
    
    private func isFilterSelected(_ filter: TransactionFilter) -> Bool {
        switch (currentFilter, filter) {
        case (.all, .all), (.incoming, .incoming), (.outgoing, .outgoing), (.thisMonth, .thisMonth):
            return true
        default:
            return false
        }
    }
    
    private func getFilterTag(_ filter: TransactionFilter) -> Int {
        switch filter {
        case .all: return 0
        case .incoming: return 1
        case .outgoing: return 2
        case .thisMonth: return 3
        case .custom: return 4
        }
    }
    
    @objc private func filterChipTapped(_ sender: UIButton) {
        switch sender.tag {
        case 0: currentFilter = .all
        case 1: currentFilter = .incoming
        case 2: currentFilter = .outgoing
        case 3: currentFilter = .thisMonth
        default: break
        }
        
        refreshTransactions()
        updateFilterChips()
    }
    
    private func updateFilterChips() {
        // Find and update all filter chip buttons
        if let container = view.subviews.first(where: { $0.subviews.first is UIScrollView }),
           let scrollView = container.subviews.first as? UIScrollView,
           let stackView = scrollView.subviews.first as? UIStackView {
            
            for (index, subview) in stackView.arrangedSubviews.enumerated() {
                if let chip = subview as? UIButton {
                    let isSelected = chip.tag == getFilterTag(currentFilter)
                    chip.backgroundColor = isSelected ? BankConfiguration.current.primaryColor : .systemGray6
                    chip.setTitleColor(isSelected ? .white : .label, for: .normal)
                }
            }
        }
    }
    
    private func refreshTransactions() {
        // Clear existing transaction views
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Filter transactions
        let filteredTransactions = getFilteredTransactions()
        
        // Group by date
        let groupedTransactions = Dictionary(grouping: filteredTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
        
        // Sort dates in descending order
        let sortedDates = groupedTransactions.keys.sorted(by: >)
        
        for date in sortedDates {
            let transactionsForDate = groupedTransactions[date]!.sorted { $0.date > $1.date }
            
            // Add date header
            let dateHeader = createDateHeader(for: date)
            stackView.addArrangedSubview(dateHeader)
            
            // Add transactions for this date
            for (index, transaction) in transactionsForDate.enumerated() {
                let row = createTransactionRow(
                    title: transaction.title,
                    subtitle: transaction.subtitle,
                    amount: transaction.amount,
                    date: transaction.date,
                    type: transaction.type
                )
                stackView.addArrangedSubview(row)
                
                // Add separator except for last transaction of the date
                if index < transactionsForDate.count - 1 {
                    let separator = UIView()
                    separator.backgroundColor = .separator
                    separator.translatesAutoresizingMaskIntoConstraints = false
                    separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                    stackView.addArrangedSubview(separator)
                }
            }
            
            // Add space between date groups
            if date != sortedDates.last {
                let spacer = UIView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
                stackView.addArrangedSubview(spacer)
            }
        }
    }
    
    private func getFilteredTransactions() -> [(title: String, subtitle: String, amount: String, date: Date, type: String)] {
        switch currentFilter {
        case .all:
            return allTransactions
        case .incoming:
            return allTransactions.filter { $0.amount.hasPrefix("+") }
        case .outgoing:
            return allTransactions.filter { $0.amount.hasPrefix("-") }
        case .thisMonth:
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return allTransactions.filter { $0.date >= startOfMonth }
        case .custom(let startDate, let endDate):
            return allTransactions.filter { $0.date >= startDate && $0.date <= endDate }
        }
    }
    
    private func createDateHeader(for date: Date) -> UIView {
        let header = UIView()
        header.backgroundColor = .systemGroupedBackground
        header.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            label.text = "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            label.text = "Yesterday"
        } else {
            formatter.dateFormat = "EEEE, d MMMM"
            label.text = formatter.string(from: date)
        }
        
        header.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: header.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8),
            header.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return header
    }
    
    private func createTransactionRow(title: String, subtitle: String, amount: String, date: Date, type: String) -> UIView {
        let row = UIView()
        row.backgroundColor = .systemBackground
        row.translatesAutoresizingMaskIntoConstraints = false
        
        // Icon based on transaction type
        let iconView = UIView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.backgroundColor = getTransactionIconColor(for: type)
        iconView.layer.cornerRadius = 20
        
        let iconLabel = UILabel()
        iconLabel.text = getTransactionIcon(for: type)
        iconLabel.textColor = .white
        iconLabel.font = .systemFont(ofSize: 14, weight: .bold)
        iconLabel.textAlignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        
        iconView.addSubview(iconLabel)
        
        // Transaction details
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Amount and time
        let amountLabel = UILabel()
        amountLabel.text = amount
        amountLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        amountLabel.textColor = amount.hasPrefix("+") ? .systemGreen : .label
        amountLabel.textAlignment = .right
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeLabel = UILabel()
        timeLabel.text = timeFormatter.string(from: date)
        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.textColor = .secondaryLabel
        timeLabel.textAlignment = .right
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        row.addSubview(iconView)
        row.addSubview(titleLabel)
        row.addSubview(subtitleLabel)
        row.addSubview(amountLabel)
        row.addSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            // Icon
            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            
            iconLabel.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            
            // Transaction details
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -8),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),
            subtitleLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -16),
            
            // Amount and time
            amountLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            amountLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),
            
            timeLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            timeLabel.topAnchor.constraint(equalTo: amountLabel.bottomAnchor, constant: 2),
            timeLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -16)
        ])
        
        return row
    }
    
    private func getTransactionIcon(for type: String) -> String {
        switch type {
        case BankConfiguration.current.bankName.lowercased(): return String(BankConfiguration.current.bankDisplayName.prefix(1))
        case "starbucks": return "S"
        case "amazon": return "A"
        case "tesco": return "T"
        case "uber": return "U"
        case "deliveroo": return "D"
        case "sainsburys": return "S"
        case "spotify": return "S"
        case "shell": return "S"
        case "mcdonalds": return "M"
        case "netflix": return "N"
        case "shopping": return "J"
        case "coffee": return "C"
        case "paypal": return "P"
        case "fuel": return "S"
        default: return "T"
        }
    }
    
    private func getTransactionIconColor(for type: String) -> UIColor {
        switch type {
        case BankConfiguration.current.bankName.lowercased(): return BankConfiguration.current.primaryColor
        case "starbucks": return UIColor(red: 0/255, green: 112/255, blue: 74/255, alpha: 1.0)
        case "amazon": return UIColor(red: 255/255, green: 153/255, blue: 0/255, alpha: 1.0)
        case "tesco": return UIColor(red: 0/255, green: 83/255, blue: 159/255, alpha: 1.0)
        case "uber": return UIColor.black
        case "deliveroo": return UIColor(red: 0/255, green: 204/255, blue: 204/255, alpha: 1.0)
        case "sainsburys": return UIColor(red: 244/255, green: 119/255, blue: 53/255, alpha: 1.0)
        case "spotify": return UIColor(red: 30/255, green: 215/255, blue: 96/255, alpha: 1.0)
        case "shell": return UIColor(red: 255/255, green: 206/255, blue: 0/255, alpha: 1.0)
        case "mcdonalds": return UIColor(red: 255/255, green: 188/255, blue: 0/255, alpha: 1.0)
        case "netflix": return UIColor(red: 229/255, green: 9/255, blue: 20/255, alpha: 1.0)
        case "shopping": return UIColor(red: 0/255, green: 146/255, blue: 69/255, alpha: 1.0)
        case "coffee": return UIColor(red: 139/255, green: 69/255, blue: 19/255, alpha: 1.0)
        case "paypal": return UIColor(red: 0/255, green: 48/255, blue: 135/255, alpha: 1.0)
        default: return .systemGray
        }
    }
    
    @objc private func dismissTransactions() {
        dismiss(animated: true)
    }
    
    @objc private func showFilterOptions() {
        let alert = UIAlertController(title: "Filter Options", message: "Select date range", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Last 7 days", style: .default) { [weak self] _ in
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            self?.currentFilter = .custom(startDate: startDate, endDate: Date())
            self?.refreshTransactions()
            self?.updateFilterChips()
        })
        
        alert.addAction(UIAlertAction(title: "Last 30 days", style: .default) { [weak self] _ in
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            self?.currentFilter = .custom(startDate: startDate, endDate: Date())
            self?.refreshTransactions()
            self?.updateFilterChips()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
}

// MARK: - AccountDetailsViewController
class AccountDetailsViewController: UIViewController {
    
    private let businessAccount = BusinessAccount(
        name: "Business Account",
        balance: 25117.27,
        available: 3517.27,
        sortCode: "77-61-27",
        accountNumber: "004923476"
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = BankConfiguration.current.currentAccountName
        
        // Add close button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Edit",
            style: .plain,
            target: self,
            action: #selector(editButtonTapped)
        )
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        
        setupUI()
    }
    
    private func setupUI() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Balance info
        let balanceLabel = UILabel()
        balanceLabel.text = "£\(String(format: "%.2f", businessAccount.available)) available"
        balanceLabel.font = .systemFont(ofSize: 16)
        balanceLabel.textColor = .secondaryLabel
        balanceLabel.textAlignment = .center
        
        // Account details section
        let detailsSection = createAccountDetailsSection()
        
        // Account info section
        let accountInfoSection = createAccountInfoSection()
        
        stackView.addArrangedSubview(balanceLabel)
        stackView.addArrangedSubview(detailsSection)
        stackView.addArrangedSubview(accountInfoSection)
        
        contentView.addSubview(stackView)
        scrollView.addSubview(contentView)
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func createAccountDetailsSection() -> UIView {
        let section = UIView()
        section.backgroundColor = .systemBackground
        section.layer.cornerRadius = 12
        
        let titleLabel = UILabel()
        titleLabel.text = "Account details"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create detail rows
        let rows: [(String, String, Selector?)] = [
            ("Cards", "rectangle.on.rectangle", nil),
            ("Statements and documents", "doc.text", nil),
            ("Limits", "lock", nil)
        ]
        
        for (index, row) in rows.enumerated() {
            let rowView = createDetailRow(title: row.0, icon: row.1, action: row.2)
            stackView.addArrangedSubview(rowView)
            
            if index < rows.count - 1 {
                let separator = UIView()
                separator.backgroundColor = .systemGray5
                separator.translatesAutoresizingMaskIntoConstraints = false
                separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
                stackView.addArrangedSubview(separator)
            }
        }
        
        section.addSubview(titleLabel)
        section.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: section.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -16),
            
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: section.bottomAnchor)
        ])
        
        return section
    }
    
    private func createAccountInfoSection() -> UIView {
        let section = UIView()
        section.backgroundColor = .systemBackground
        section.layer.cornerRadius = 12
        
        // Tab selector
        let tabContainer = UIView()
        tabContainer.backgroundColor = .systemGray6
        tabContainer.layer.cornerRadius = 8
        tabContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let ukTab = createTabButton(title: "UK", isSelected: true)
        let swiftTab = createTabButton(title: "SWIFT", isSelected: false)
        let sepaTab = createTabButton(title: "SEPA", isSelected: false)
        
        let tabStack = UIStackView(arrangedSubviews: [ukTab, swiftTab, sepaTab])
        tabStack.axis = .horizontal
        tabStack.distribution = .fillEqually
        tabStack.translatesAutoresizingMaskIntoConstraints = false
        
        tabContainer.addSubview(tabStack)
        
        // Description
        let descLabel = UILabel()
        descLabel.text = "These details are for receiving GBP payments from other UK accounts"
        descLabel.font = .systemFont(ofSize: 14)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 0
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Share button
        let shareButton = UIButton(type: .system)
        shareButton.setTitle("Share", for: .normal)
        shareButton.backgroundColor = .systemBlue
        shareButton.setTitleColor(.white, for: .normal)
        shareButton.layer.cornerRadius = 8
        shareButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Account details
        let detailsStack = UIStackView()
        detailsStack.axis = .vertical
        detailsStack.spacing = 20
        detailsStack.translatesAutoresizingMaskIntoConstraints = false
        
        let accountNumberRow = createInfoRow(title: "Account number", value: businessAccount.accountNumber)
        let sortCodeRow = createInfoRow(title: "Sort code", value: businessAccount.sortCode)
        let bankAddressRow = createInfoRow(title: "Bank address", value: "4th Floor, The Featherstone Building, 66 City Road\nLondon\nEC1Y 2AL")
        
        detailsStack.addArrangedSubview(accountNumberRow)
        detailsStack.addArrangedSubview(sortCodeRow)
        detailsStack.addArrangedSubview(bankAddressRow)
        
        section.addSubview(tabContainer)
        section.addSubview(descLabel)
        section.addSubview(shareButton)
        section.addSubview(detailsStack)
        
        NSLayoutConstraint.activate([
            tabStack.topAnchor.constraint(equalTo: tabContainer.topAnchor, constant: 4),
            tabStack.leadingAnchor.constraint(equalTo: tabContainer.leadingAnchor, constant: 4),
            tabStack.trailingAnchor.constraint(equalTo: tabContainer.trailingAnchor, constant: -4),
            tabStack.bottomAnchor.constraint(equalTo: tabContainer.bottomAnchor, constant: -4),
            
            tabContainer.topAnchor.constraint(equalTo: section.topAnchor, constant: 20),
            tabContainer.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 16),
            tabContainer.heightAnchor.constraint(equalToConstant: 40),
            
            shareButton.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -16),
            shareButton.centerYAnchor.constraint(equalTo: descLabel.centerYAnchor),
            shareButton.widthAnchor.constraint(equalToConstant: 80),
            shareButton.heightAnchor.constraint(equalToConstant: 36),
            
            descLabel.topAnchor.constraint(equalTo: tabContainer.bottomAnchor, constant: 16),
            descLabel.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 16),
            descLabel.trailingAnchor.constraint(equalTo: shareButton.leadingAnchor, constant: -16),
            
            detailsStack.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 20),
            detailsStack.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 16),
            detailsStack.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -16),
            detailsStack.bottomAnchor.constraint(equalTo: section.bottomAnchor, constant: -20)
        ])
        
        return section
    }
    
    private func createDetailRow(title: String, icon: String, action: Selector?) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1.0)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .systemGray3
        chevron.translatesAutoresizingMaskIntoConstraints = false
        
        row.addSubview(iconView)
        row.addSubview(titleLabel)
        row.addSubview(chevron)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            
            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 8),
            chevron.heightAnchor.constraint(equalToConstant: 12),
            
            row.heightAnchor.constraint(equalToConstant: 56)
        ])
        
        return row
    }
    
    private func createTabButton(title: String, isSelected: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = isSelected ? .systemBackground : .clear
        button.layer.cornerRadius = 6
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.setTitleColor(isSelected ? .label : .secondaryLabel, for: .normal)
        return button
    }
    
    private func createInfoRow(title: String, value: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 16)
        valueLabel.textColor = .secondaryLabel
        valueLabel.numberOfLines = 0
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let copyButton = UIButton(type: .system)
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.tintColor = .systemGray
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        container.addSubview(copyButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            valueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: copyButton.leadingAnchor, constant: -12),
            valueLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            copyButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            copyButton.centerYAnchor.constraint(equalTo: valueLabel.centerYAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: 24),
            copyButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return container
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func editButtonTapped() {
        // Handle edit action
        let alert = UIAlertController(title: "Edit Account", message: "Edit functionality coming soon", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - PaymentCollectionDelegate
extension MainViewController {
    nonisolated func didCompletePayment(_ paymentIntent: PaymentIntent) {
        print("🎉 Payment completed successfully from collection screen - PaymentIntent: \(paymentIntent.stripeId)")
        
        // Immediate refresh since user stayed on TTP screen until ready
        DispatchQueue.main.async { [weak self] in
            print("🔄 Refreshing dashboard after payment completion")
            self?.loadBusinessBankingInterface()
            
            // Post notification to refresh other views including embedded payments components
            NotificationCenter.default.post(name: NSNotification.Name("PaymentCompleted"), object: paymentIntent)
            
            // Small delay for embedded payments components refresh
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🔄 Posting refresh notification for embedded components")
                NotificationCenter.default.post(name: NSNotification.Name("RefreshEmbeddedComponents"), object: nil)
            }
        }
    }
    
    nonisolated func didCancelPayment() {
        print("INFO: Payment collection cancelled by user")
    }
    
    private func presentSettings() {
        // Get current app info for settings
        Task {
            let result = await API.appInfo()
            let appInfo = try? result.get()
            
            await MainActor.run {
                let settingsView = AppSettingsView(appInfo: appInfo)
                let hostingController = UIHostingController(rootView: settingsView)
                hostingController.modalPresentationStyle = .pageSheet
                self.present(hostingController, animated: true)
            }
        }
    }
    
    private func updateLogoImage(_ logoImageView: UIImageView) {
        // Use the bank configuration logo
        logoImageView.image = UIImage(named: BankConfiguration.current.logoImageName)
    }
    
    @objc private func logoUpdated() {
        // Find all logo image views and update them
        // This is a simple approach - in production you might want to keep references
        DispatchQueue.main.async { [weak self] in
            self?.view.subviews.forEach { view in
                self?.updateLogoImageViewsRecursively(in: view)
            }
        }
    }
    
    private func updateLogoImageViewsRecursively(in view: UIView) {
        if let logoImageView = view as? UIImageView,
           let currentImage = logoImageView.image,
           currentImage == UIImage(named: BankConfiguration.current.logoImageName) {
            // This looks like a bank logo image view, update it
            updateLogoImage(logoImageView)
        }
        
        // Recursively check subviews
        view.subviews.forEach { subview in
            updateLogoImageViewsRecursively(in: subview)
        }
    }
}

// MARK: - Business Account Model

struct BusinessAccount {
    let name: String
    let balance: Double
    let available: Double
    let sortCode: String
    let accountNumber: String
}
