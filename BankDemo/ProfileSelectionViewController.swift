import UIKit

struct Profile {
    let id: String
    let type: String
    let name: String
    let businessName: String?
    let email: String
    let phone: String
    let address: [String: Any]
    let profileData: [String: Any]
}

struct ProfileResponse {
    let individual: Profile
    let company: Profile
}

class ProfileSelectionViewController: UIViewController {
    private let bankPrimary = BankConfiguration.current.primaryColor

    private var profiles: ProfileResponse?
    private var selectedProfile: Profile?
    private var accounts: [ConnectedAccountSummary] = []
    private var selectedAccount: ConnectedAccountSummary?
    private var hasLoadedAccounts = false
    private var isLoadingAccounts = false

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let modeControl = UISegmentedControl(items: ["Create new", "Use existing"])

    private let createStack = UIStackView()
    private let profileTypeControl = UISegmentedControl(items: ["Individual", "Company"])
    private let profileDetailsContainer = UIView()
    private let profileDetailsLabel = UILabel()

    private let existingStack = UIStackView()
    private let accountStateLabel = UILabel()
    private let accountActivityIndicator = UIActivityIndicatorView(style: .medium)
    private let retryButton = UIButton(type: .system)
    private let accountSelectorButton = UIButton(type: .system)
    private let accountTableView = UITableView(frame: .zero, style: .plain)
    private var accountTableHeightConstraint: NSLayoutConstraint!

    private let continueButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchProfiles()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        titleLabel.text = "Choose how to continue"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = bankPrimary
        titleLabel.textAlignment = .center

        subtitleLabel.text = BankConfiguration.current.onboardingSubtitle
        subtitleLabel.font = .systemFont(ofSize: 16)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        modeControl.selectedSegmentIndex = 0
        modeControl.selectedSegmentTintColor = bankPrimary
        modeControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)

        setupCreateUI()
        setupExistingUI()

        continueButton.setTitle("Continue", for: .normal)
        continueButton.backgroundColor = bankPrimary
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.setTitleColor(.white.withAlphaComponent(0.7), for: .disabled)
        continueButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        continueButton.layer.cornerRadius = 8
        continueButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)

        [titleLabel, subtitleLabel, modeControl, createStack, existingStack, continueButton]
            .forEach { contentStack.addArrangedSubview($0) }
        contentStack.setCustomSpacing(32, after: subtitleLabel)
        contentStack.setCustomSpacing(24, after: modeControl)
        contentStack.setCustomSpacing(32, after: createStack)
        contentStack.setCustomSpacing(32, after: existingStack)

        existingStack.isHidden = true
        refreshContinueState()

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 40),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    private func setupCreateUI() {
        createStack.axis = .vertical
        createStack.spacing = 20

        profileTypeControl.selectedSegmentIndex = 0
        profileTypeControl.selectedSegmentTintColor = bankPrimary
        profileTypeControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        profileTypeControl.addTarget(self, action: #selector(profileTypeChanged), for: .valueChanged)

        profileDetailsContainer.backgroundColor = .secondarySystemBackground
        profileDetailsContainer.layer.cornerRadius = 12
        profileDetailsContainer.layer.borderWidth = 1
        profileDetailsContainer.layer.borderColor = UIColor.separator.cgColor
        profileDetailsContainer.heightAnchor.constraint(equalToConstant: 132).isActive = true

        profileDetailsLabel.text = "Loading profiles…"
        profileDetailsLabel.font = .systemFont(ofSize: 14)
        profileDetailsLabel.textColor = .label
        profileDetailsLabel.numberOfLines = 0
        profileDetailsLabel.textAlignment = .center
        profileDetailsLabel.translatesAutoresizingMaskIntoConstraints = false
        profileDetailsContainer.addSubview(profileDetailsLabel)

        NSLayoutConstraint.activate([
            profileDetailsLabel.topAnchor.constraint(equalTo: profileDetailsContainer.topAnchor, constant: 16),
            profileDetailsLabel.leadingAnchor.constraint(equalTo: profileDetailsContainer.leadingAnchor, constant: 16),
            profileDetailsLabel.trailingAnchor.constraint(equalTo: profileDetailsContainer.trailingAnchor, constant: -16),
            profileDetailsLabel.bottomAnchor.constraint(equalTo: profileDetailsContainer.bottomAnchor, constant: -16),
        ])

        createStack.addArrangedSubview(profileTypeControl)
        createStack.addArrangedSubview(profileDetailsContainer)
    }

    private func setupExistingUI() {
        existingStack.axis = .vertical
        existingStack.spacing = 12

        accountStateLabel.font = .systemFont(ofSize: 15)
        accountStateLabel.textColor = .secondaryLabel
        accountStateLabel.textAlignment = .center
        accountStateLabel.numberOfLines = 0

        accountActivityIndicator.hidesWhenStopped = true

        retryButton.setTitle("Retry", for: .normal)
        retryButton.setTitleColor(bankPrimary, for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        retryButton.addTarget(self, action: #selector(retryAccountsTapped), for: .touchUpInside)
        retryButton.isHidden = true

        var selectorConfiguration = UIButton.Configuration.gray()
        selectorConfiguration.title = "Select an account"
        selectorConfiguration.image = UIImage(systemName: "chevron.down")
        selectorConfiguration.imagePlacement = .trailing
        selectorConfiguration.imagePadding = 8
        selectorConfiguration.baseForegroundColor = .label
        selectorConfiguration.cornerStyle = .medium
        accountSelectorButton.configuration = selectorConfiguration
        accountSelectorButton.contentHorizontalAlignment = .fill
        accountSelectorButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        accountSelectorButton.addTarget(self, action: #selector(toggleAccountDropdown), for: .touchUpInside)
        accountSelectorButton.isHidden = true

        accountTableView.dataSource = self
        accountTableView.delegate = self
        accountTableView.rowHeight = 72
        accountTableView.layer.cornerRadius = 10
        accountTableView.layer.borderWidth = 1
        accountTableView.layer.borderColor = UIColor.separator.cgColor
        accountTableView.tableFooterView = UIView()
        accountTableView.isHidden = true
        accountTableView.translatesAutoresizingMaskIntoConstraints = false
        accountTableHeightConstraint = accountTableView.heightAnchor.constraint(equalToConstant: 0)
        accountTableHeightConstraint.isActive = true

        existingStack.addArrangedSubview(accountStateLabel)
        existingStack.addArrangedSubview(accountActivityIndicator)
        existingStack.addArrangedSubview(retryButton)
        existingStack.addArrangedSubview(accountSelectorButton)
        existingStack.addArrangedSubview(accountTableView)
    }

    @objc private func modeChanged() {
        let usingExisting = modeControl.selectedSegmentIndex == 1
        createStack.isHidden = usingExisting
        existingStack.isHidden = !usingExisting
        collapseAccountDropdown()

        if usingExisting {
            titleLabel.text = "Use an existing account"
            subtitleLabel.text = "Choose a connected account to open its current payments dashboard."
            if !hasLoadedAccounts && !isLoadingAccounts {
                fetchConnectedAccounts()
            }
        } else {
            titleLabel.text = "Choose how to continue"
            subtitleLabel.text = BankConfiguration.current.onboardingSubtitle
        }
        refreshContinueState()
    }

    @objc private func profileTypeChanged() {
        selectProfile(at: profileTypeControl.selectedSegmentIndex)
    }

    private func selectProfile(at index: Int) {
        guard let profiles else {
            selectedProfile = nil
            refreshContinueState()
            return
        }
        selectedProfile = index == 0 ? profiles.individual : profiles.company
        if let selectedProfile {
            updateProfileDetails(with: selectedProfile)
        }
        refreshContinueState()
    }

    private func updateProfileDetails(with profile: Profile) {
        if profile.type == "individual" {
            profileDetailsLabel.text = "\(profile.name)\n\(profile.businessName ?? "")\n\n\(profile.email)\n\(profile.phone)"
        } else {
            profileDetailsLabel.text = "\(profile.name)\n\n\(profile.email)\n\(profile.phone)"
        }
    }

    private func fetchProfiles() {
        let market = BankConfiguration.current.market.code
        guard let url = URL(string: "\(AppSettings.shared.selectedServerBaseURL)/api/profiles?market=\(market)") else {
            profileDetailsLabel.text = "Unable to load profiles."
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    print("ERROR: Failed to fetch profiles: \(error.localizedDescription)")
                    self.profileDetailsLabel.text = "Unable to load profiles."
                    return
                }
                guard let data else {
                    self.profileDetailsLabel.text = "Unable to load profiles."
                    return
                }

                do {
                    guard
                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                        json["success"] as? Bool == true,
                        let profilesData = json["profiles"] as? [String: Any],
                        let individualData = profilesData["individual"] as? [String: Any],
                        let companyData = profilesData["company"] as? [String: Any]
                    else {
                        self.profileDetailsLabel.text = "Unable to load profiles."
                        return
                    }

                    self.profiles = ProfileResponse(
                        individual: self.profile(from: individualData, defaultType: "individual"),
                        company: self.profile(from: companyData, defaultType: "company")
                    )
                    self.selectProfile(at: self.profileTypeControl.selectedSegmentIndex)
                } catch {
                    print("ERROR: Failed to parse profiles: \(error.localizedDescription)")
                    self.profileDetailsLabel.text = "Unable to load profiles."
                }
            }
        }.resume()
    }

    private func profile(from data: [String: Any], defaultType: String) -> Profile {
        Profile(
            id: data["id"] as? String ?? "",
            type: data["type"] as? String ?? defaultType,
            name: data["name"] as? String ?? "",
            businessName: data["businessName"] as? String,
            email: data["email"] as? String ?? "",
            phone: data["phone"] as? String ?? "",
            address: data["address"] as? [String: Any] ?? [:],
            profileData: data["profileData"] as? [String: Any] ?? [:]
        )
    }

    private func fetchConnectedAccounts() {
        isLoadingAccounts = true
        accountStateLabel.text = "Loading connected accounts…"
        accountStateLabel.isHidden = false
        accountActivityIndicator.startAnimating()
        retryButton.isHidden = true
        accountSelectorButton.isHidden = true
        collapseAccountDropdown()

        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await API.connectedAccounts()
            self.isLoadingAccounts = false
            self.accountActivityIndicator.stopAnimating()

            switch result {
            case .success(let response):
                self.hasLoadedAccounts = true
                self.accounts = response.accounts
                self.accountTableView.reloadData()

                guard !response.accounts.isEmpty else {
                    self.accountStateLabel.text = "No existing connected accounts were found. Create a new account instead."
                    self.accountStateLabel.isHidden = false
                    self.accountSelectorButton.isHidden = true
                    self.selectedAccount = nil
                    self.refreshContinueState()
                    return
                }

                self.accountStateLabel.isHidden = true
                self.accountSelectorButton.isHidden = false
                if let persistedId = AppDataManager.shared.currentAccountId,
                   let persistedAccount = response.accounts.first(where: { $0.id == persistedId }) {
                    self.selectAccount(persistedAccount)
                } else {
                    self.selectedAccount = nil
                    self.updateAccountSelectorTitle()
                }
                self.refreshContinueState()

            case .failure(let error):
                self.hasLoadedAccounts = false
                self.accounts = []
                self.selectedAccount = nil
                self.accountStateLabel.text = "Couldn’t load connected accounts. \(error.debugDescription)"
                self.accountStateLabel.isHidden = false
                self.retryButton.isHidden = false
                self.accountSelectorButton.isHidden = true
                self.refreshContinueState()
            }
        }
    }

    @objc private func retryAccountsTapped() {
        fetchConnectedAccounts()
    }

    @objc private func toggleAccountDropdown() {
        if accountTableView.isHidden {
            accountTableView.isHidden = false
            accountTableHeightConstraint.constant = min(CGFloat(accounts.count) * accountTableView.rowHeight, 288)
        } else {
            collapseAccountDropdown()
        }
    }

    private func collapseAccountDropdown() {
        accountTableView.isHidden = true
        accountTableHeightConstraint?.constant = 0
    }

    private func selectAccount(_ account: ConnectedAccountSummary) {
        selectedAccount = account
        updateAccountSelectorTitle()
        collapseAccountDropdown()
        refreshContinueState()
    }

    private func updateAccountSelectorTitle() {
        var configuration = accountSelectorButton.configuration ?? .gray()
        configuration.title = selectedAccount?.displayName ?? "Select an account"
        configuration.image = UIImage(systemName: "chevron.down")
        configuration.imagePlacement = .trailing
        accountSelectorButton.configuration = configuration
        accountSelectorButton.accessibilityLabel = selectedAccount.map {
            "Selected account, \($0.displayName), \(readinessText(for: $0))"
        } ?? "Select an existing connected account"
    }

    private func refreshContinueState() {
        let enabled = modeControl.selectedSegmentIndex == 0
            ? selectedProfile != nil
            : selectedAccount != nil
        continueButton.isEnabled = enabled
        continueButton.backgroundColor = enabled ? bankPrimary : .systemGray3
    }

    @objc private func continueButtonTapped() {
        if modeControl.selectedSegmentIndex == 0 {
            guard let selectedProfile else { return }
            AppDataManager.shared.currentAccountId = nil
            AppDataManager.shared.clearAccountContext()
            showDashboard(profile: selectedProfile)
        } else {
            guard let selectedAccount else { return }
            AppDataManager.shared.currentAccountId = selectedAccount.id
            AppDataManager.shared.setAccountContext(
                country: selectedAccount.country,
                currency: selectedAccount.currency
            )
            showDashboard(profile: nil)
        }
    }

    private func showDashboard(profile: Profile?) {
        let tabBarController = BankTabBarController()
        if let profile,
           let navigationController = tabBarController.viewControllers?.first as? UINavigationController,
           let mainViewController = navigationController.viewControllers.first as? MainViewController {
            mainViewController.selectedProfile = profile
        }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = tabBarController
            window.makeKeyAndVisible()
        }
    }

    private func readinessText(for account: ConnectedAccountSummary) -> String {
        switch account.canTakeCardPayments {
        case .some(true): return "Card payments ready"
        case .some(false): return "Card payments unavailable"
        case .none: return "Card payment status unavailable"
        }
    }

    private func readinessColor(for account: ConnectedAccountSummary) -> UIColor {
        switch account.canTakeCardPayments {
        case .some(true): return .systemGreen
        case .some(false): return .systemRed
        case .none: return .systemGray
        }
    }

    private func formattedDate(_ value: String) -> String {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
        guard let date else { return "Date unavailable" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

extension ProfileSelectionViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        accounts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "ConnectedAccountCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: reuseIdentifier)
        let account = accounts[indexPath.row]
        let idSuffix = String(account.id.suffix(6))

        cell.textLabel?.text = account.displayName
        cell.textLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        cell.detailTextLabel?.text = "\(formattedDate(account.created)) · \(account.currency.uppercased()) · acct_…\(idSuffix) · \(readinessText(for: account))"
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.adjustsFontSizeToFitWidth = true
        cell.imageView?.image = UIImage(systemName: "circle.fill")
        cell.imageView?.tintColor = readinessColor(for: account)
        cell.accessoryType = selectedAccount?.id == account.id ? .checkmark : .none
        cell.accessibilityLabel = "\(account.displayName), created \(formattedDate(account.created)), \(readinessText(for: account))"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectAccount(accounts[indexPath.row])
        tableView.reloadData()
    }
}
