//
//  AppStartViewController.swift
//  BankDemo
//
//  Created by Aditya Singh
//

import UIKit
import StripeConnect
import Stripe

class AppStartViewController: UIViewController {
    
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let messageLabel = UILabel()
    private lazy var retryButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Retry"
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 16, weight: .medium)
            return outgoing
        }
        config.baseBackgroundColor = BankConfiguration.current.primaryColor
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
        
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        return button
    }()
    private let logoImageView = UIImageView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadAppInfo()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(named: "SelectedLaunchBackground")
            ?? BankConfiguration.current.primaryColor
        
        // Logo image view
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.image = UIImage(named: "SelectedLaunchLogo")
        view.addSubview(logoImageView)
        
        // Activity indicator
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .white
        view.addSubview(activityIndicator)
        
        // Message label
        messageLabel.text = "Loading \(BankConfiguration.current.businessBankingName)..."
        messageLabel.textAlignment = .center
        messageLabel.font = .systemFont(ofSize: 18, weight: .medium)
        messageLabel.textColor = .white
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)
        
        // Retry button
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.isHidden = true
        view.addSubview(retryButton)
        
        // Layout
        NSLayoutConstraint.activate([
            // Logo at the top
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            logoImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 200),
            logoImageView.heightAnchor.constraint(lessThanOrEqualToConstant: 80),
            
            // Activity indicator in center
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            
            // Message below activity indicator
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            // Retry button below message
            retryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            retryButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 30),
            retryButton.widthAnchor.constraint(equalToConstant: 120),
            retryButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func retryTapped() {
        loadAppInfo()
    }
    
    private func loadAppInfo() {
        activityIndicator.startAnimating()
        retryButton.isHidden = true
        messageLabel.text = "Loading \(BankConfiguration.current.businessBankingName)..."
        
        Task { @MainActor in
            let _ = AppSettings.shared.selectedServerBaseURL
            print("INFO: Loading app configuration from backend")
            let result = await API.appInfo()
            
            switch result {
            case .success(let appInfo):
                print("INFO: App configuration loaded successfully")
                
                // Set the publishable key dynamically
                STPAPIClient.shared.publishableKey = appInfo.publishableKey
                
                // Always start with profile selection - account creation happens during onboarding

                let rootViewController = UINavigationController(rootViewController: ProfileSelectionViewController())
                
                // Replace the current view controller
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController = rootViewController
                    window.makeKeyAndVisible()
                }
                
            case .failure(let error):
                activityIndicator.stopAnimating()
                print("ERROR: Failed to load app configuration: \(error)")
                
                // More detailed error message
                let errorMessage: String
                switch error {
                case .networkError(let networkError):
                    errorMessage = "Network error: \(networkError.localizedDescription)"
                case .invalidURL:
                    errorMessage = "Invalid server URL"
                case .failedToParse(let parseError):
                    errorMessage = "Failed to parse response: \(parseError.localizedDescription)"
                case .responseError(let response):
                    errorMessage = "Server error: \(response.error)"
                case .unknown(let unknownError):
                    errorMessage = "Unknown error: \(unknownError.localizedDescription)"
                }
                
                messageLabel.text = "Failed to load app configuration.\n\(errorMessage)"
                retryButton.backgroundColor = BankConfiguration.current.primaryColor
                retryButton.isHidden = false
            }
        }
    }
}



// MARK: - Notification Names
extension Notification.Name {
    static let brandingLogoUpdated = Notification.Name("brandingLogoUpdated")
}
