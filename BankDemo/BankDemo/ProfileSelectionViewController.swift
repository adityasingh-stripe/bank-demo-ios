import UIKit

// Profile data models
struct Profile {
    let id: String
    let type: String // "individual" or "company"
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
    private var profiles: ProfileResponse?
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tabContainer = UIView()
    private let individualTab = UIView()
    private let companyTab = UIView()
    private let individualTabLabel = UILabel()
    private let companyTabLabel = UILabel()
    private let contentContainer = UIView()
    private let profileDetailsLabel = UILabel()
    private let continueButton = UIButton()
    private var selectedProfile: Profile?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchProfiles()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Bank primary color
        let bankPrimary = BankConfiguration.current.primaryColor
        
        // Title
        titleLabel.text = "Choose Your Profile"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = bankPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Subtitle
        subtitleLabel.text = BankConfiguration.current.onboardingSubtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = UIColor.systemGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)
        
        // Tab container
        tabContainer.backgroundColor = UIColor.systemGray6
        tabContainer.layer.cornerRadius = 8
        tabContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabContainer)
        
        // Individual tab
        individualTab.backgroundColor = bankPrimary
        individualTab.layer.cornerRadius = 6
        individualTab.translatesAutoresizingMaskIntoConstraints = false
        tabContainer.addSubview(individualTab)
        
        individualTabLabel.text = "Individual"
        individualTabLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        individualTabLabel.textColor = UIColor.white
        individualTabLabel.textAlignment = .center
        individualTabLabel.translatesAutoresizingMaskIntoConstraints = false
        individualTab.addSubview(individualTabLabel)
        
        // Company tab
        companyTab.backgroundColor = UIColor.clear
        companyTab.layer.cornerRadius = 6
        companyTab.translatesAutoresizingMaskIntoConstraints = false
        tabContainer.addSubview(companyTab)
        
        companyTabLabel.text = "Company"
        companyTabLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        companyTabLabel.textColor = UIColor.systemGray
        companyTabLabel.textAlignment = .center
        companyTabLabel.translatesAutoresizingMaskIntoConstraints = false
        companyTab.addSubview(companyTabLabel)
        
        // Content container
        contentContainer.backgroundColor = UIColor.systemBackground
        contentContainer.layer.cornerRadius = 12
        contentContainer.layer.borderWidth = 1
        contentContainer.layer.borderColor = UIColor.systemGray4.cgColor
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)
        
        // Profile details
        profileDetailsLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        profileDetailsLabel.textColor = UIColor.label
        profileDetailsLabel.numberOfLines = 0
        profileDetailsLabel.textAlignment = .center
        profileDetailsLabel.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(profileDetailsLabel)
        
        // Continue button
        continueButton.setTitle("Continue", for: .normal)
        continueButton.backgroundColor = bankPrimary
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        continueButton.layer.cornerRadius = 8
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        view.addSubview(continueButton)
        
        // Add tap gestures
        let individualTap = UITapGestureRecognizer(target: self, action: #selector(individualTabTapped))
        individualTab.addGestureRecognizer(individualTap)
        
        let companyTap = UITapGestureRecognizer(target: self, action: #selector(companyTabTapped))
        companyTab.addGestureRecognizer(companyTap)
        
        // Default to individual tab selected
        selectTab(isIndividual: true)
        
        setupConstraints()
    }
    
    private func selectTab(isIndividual: Bool) {
        let bankPrimary = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1)
        
        if isIndividual {
            individualTab.backgroundColor = bankPrimary
            individualTabLabel.textColor = UIColor.white
            companyTab.backgroundColor = UIColor.clear
            companyTabLabel.textColor = UIColor.systemGray
            
            if let profile = profiles?.individual {
                selectedProfile = profile
                updateProfileDetails(with: profile)
            }
        } else {
            companyTab.backgroundColor = bankPrimary
            companyTabLabel.textColor = UIColor.white
            individualTab.backgroundColor = UIColor.clear
            individualTabLabel.textColor = UIColor.systemGray
            
            if let profile = profiles?.company {
                selectedProfile = profile
                updateProfileDetails(with: profile)
            }
        }
    }
    
    private func updateProfileDetails(with profile: Profile) {
        if profile.type == "individual" {
            profileDetailsLabel.text = "\(profile.name)\n\(profile.businessName ?? "")\n\n\(profile.email)\n\(profile.phone)"
        } else {
            profileDetailsLabel.text = "\(profile.name)\n\n\(profile.email)\n\(profile.phone)"
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Tab container
            tabContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            tabContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabContainer.heightAnchor.constraint(equalToConstant: 44),
            
            // Individual tab
            individualTab.topAnchor.constraint(equalTo: tabContainer.topAnchor, constant: 4),
            individualTab.leadingAnchor.constraint(equalTo: tabContainer.leadingAnchor, constant: 4),
            individualTab.bottomAnchor.constraint(equalTo: tabContainer.bottomAnchor, constant: -4),
            individualTab.widthAnchor.constraint(equalTo: tabContainer.widthAnchor, multiplier: 0.5, constant: -6),
            
            // Individual tab label
            individualTabLabel.centerXAnchor.constraint(equalTo: individualTab.centerXAnchor),
            individualTabLabel.centerYAnchor.constraint(equalTo: individualTab.centerYAnchor),
            
            // Company tab
            companyTab.topAnchor.constraint(equalTo: tabContainer.topAnchor, constant: 4),
            companyTab.trailingAnchor.constraint(equalTo: tabContainer.trailingAnchor, constant: -4),
            companyTab.bottomAnchor.constraint(equalTo: tabContainer.bottomAnchor, constant: -4),
            companyTab.widthAnchor.constraint(equalTo: tabContainer.widthAnchor, multiplier: 0.5, constant: -6),
            
            // Company tab label
            companyTabLabel.centerXAnchor.constraint(equalTo: companyTab.centerXAnchor),
            companyTabLabel.centerYAnchor.constraint(equalTo: companyTab.centerYAnchor),
            
            // Content container
            contentContainer.topAnchor.constraint(equalTo: tabContainer.bottomAnchor, constant: 20),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentContainer.heightAnchor.constraint(equalToConstant: 120),
            
            // Profile details
            profileDetailsLabel.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 20),
            profileDetailsLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 20),
            profileDetailsLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -20),
            profileDetailsLabel.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -20),
            
            // Continue button
            continueButton.topAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: 40),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 50),
            continueButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    private func fetchProfiles() {
        guard let url = URL(string: "\(AppSettings.shared.selectedServerBaseURL)/api/profiles") else {
            print("ERROR: Invalid URL")
            return
        }
        
        print("INFO: Loading profiles")
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("ERROR: Failed to fetch profiles: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("ERROR: No data received")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool, success,
                       let profilesData = json["profiles"] as? [String: Any],
                       let individualData = profilesData["individual"] as? [String: Any],
                       let companyData = profilesData["company"] as? [String: Any] {
                        
                        let individual = Profile(
                            id: individualData["id"] as? String ?? "",
                            type: individualData["type"] as? String ?? "individual",
                            name: individualData["name"] as? String ?? "",
                            businessName: individualData["businessName"] as? String,
                            email: individualData["email"] as? String ?? "",
                            phone: individualData["phone"] as? String ?? "",
                            address: individualData["address"] as? [String: Any] ?? [:],
                            profileData: individualData["profileData"] as? [String: Any] ?? [:]
                        )
                        
                        let company = Profile(
                            id: companyData["id"] as? String ?? "",
                            type: companyData["type"] as? String ?? "company",
                            name: companyData["name"] as? String ?? "",
                            businessName: nil,
                            email: companyData["email"] as? String ?? "",
                            phone: companyData["phone"] as? String ?? "",
                            address: companyData["address"] as? [String: Any] ?? [:],
                            profileData: companyData["profileData"] as? [String: Any] ?? [:]
                        )
                        
                        self?.profiles = ProfileResponse(individual: individual, company: company)
                        self?.selectTab(isIndividual: true) // Default to individual
                        print("INFO: Profiles loaded successfully")
                    } else {
                        print("ERROR: Invalid response format")
                    }
                } catch {
                    print("ERROR: Failed to parse profiles response: \(error.localizedDescription)")
                }
            }
        }
        
        task.resume()
    }
    
    @objc private func individualTabTapped() {
        selectTab(isIndividual: true)
    }
    
    @objc private func companyTabTapped() {
        selectTab(isIndividual: false)
    }
    
    @objc private func continueButtonTapped() {
        guard let profile = selectedProfile else {
            print("ERROR: No profile selected")
            return
        }
        
        print("INFO: Continuing with \(profile.type) profile: \(profile.name)")
        navigateToMainDashboard(with: profile)
    }
    
    private func navigateToMainDashboard(with profile: Profile) {
        print("INFO: Selected profile: \(profile.name)")
        
        // Clear any existing account ID when switching profiles (like we do on logout)
        // Clear account ID when switching profiles
        AppDataManager.shared.currentAccountId = nil

        
        // Create tab bar controller with selected profile
        let tabBarController = BankTabBarController()
        
        // Find the MainViewController in the tab bar and set the selected profile
        if let navController = tabBarController.viewControllers?.first as? UINavigationController,
           let mainVC = navController.viewControllers.first as? MainViewController {
            mainVC.selectedProfile = profile
    
        }
        
        // Set as root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = tabBarController
            window.makeKeyAndVisible()
        }
    }
} 