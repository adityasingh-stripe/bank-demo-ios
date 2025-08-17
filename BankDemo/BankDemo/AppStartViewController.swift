//
//  AppStartViewController.swift
//  BankDemo
//
//  Created by Aditya Singh
//

import UIKit
import StripeConnect
import Foundation
import Stripe

// Local definitions until Utils classes are properly included in project
@MainActor
final class LocalBrandingManager: @unchecked Sendable {
    static let shared = LocalBrandingManager()
    private var _primaryColor: UIColor?
    
    private init() {}
    
    var primaryColor: UIColor {
        return _primaryColor ?? UIColor.systemBlue
    }
    
    func configure(with appInfo: AppInfo) {
        if let primaryColorHex = appInfo.primaryColor {
            _primaryColor = UIColor(hex: primaryColorHex)
        }
    }
}

@MainActor  
final class LocalImageLoader: @unchecked Sendable {
    static let shared = LocalImageLoader()
    private let cache = NSCache<NSString, UIImage>()
    private let session = URLSession.shared
    
    private init() {
        cache.countLimit = 100
    }
    
    func loadImage(from urlString: String?) async -> UIImage? {
        guard let urlString = urlString,
              let url = URL(string: urlString) else {
            return nil
        }
        
        if let cachedImage = cache.object(forKey: urlString as NSString) {
            return cachedImage
        }
        
        do {
            let (data, _) = try await session.data(from: url)
            guard let image = UIImage(data: data) else {
                return nil
            }
            
            cache.setObject(image, forKey: urlString as NSString)
            return image
        } catch {
            print("Error loading image from \(urlString): \(error)")
            return nil
        }
    }
}

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
        config.baseBackgroundColor = LocalBrandingManager.shared.primaryColor
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
        view.backgroundColor = .systemBackground
        
        // Logo image view
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.isHidden = true // Initially hidden until loaded
        view.addSubview(logoImageView)
        
        // Activity indicator
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        
        // Message label
        messageLabel.text = "Loading Bank Demo..."
        messageLabel.textAlignment = .center
        messageLabel.font = .systemFont(ofSize: 18, weight: .medium)
        messageLabel.textColor = .label
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
        messageLabel.text = "Loading Bank Demo..."
        
        Task { @MainActor in
            let serverURL = AppSettings.shared.selectedServerBaseURL
            print("INFO: Loading app configuration from backend")
            let result = await API.appInfo()
            
            switch result {
            case .success(let appInfo):
                print("INFO: App configuration loaded successfully")
                
                // Set the publishable key dynamically
                STPAPIClient.shared.publishableKey = appInfo.publishableKey
                
                // Configure branding (colors, logo, etc.)
                LocalBrandingManager.shared.configure(with: appInfo)
                
                // Load and display logo if available
                if let logoUrl = appInfo.logoUrl ?? appInfo.iconUrl {
                    let logoImage = await LocalImageLoader.shared.loadImage(from: logoUrl)
                    if let logoImage = logoImage {
                        logoImageView.image = logoImage
                        logoImageView.isHidden = false
                    }
                }
                
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
                retryButton.backgroundColor = LocalBrandingManager.shared.primaryColor
                retryButton.isHidden = false
            }
        }
    }
}



// MARK: - Notification Names
extension Notification.Name {
    static let brandingLogoUpdated = Notification.Name("brandingLogoUpdated")
}

// MARK: - UIColor Extension for Hex Support
extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        
        if length == 6 {
            self.init(
                red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
                green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
                blue: CGFloat(rgb & 0x0000FF) / 255.0,
                alpha: 1.0
            )
        } else if length == 8 {
            self.init(
                red: CGFloat((rgb & 0xFF000000) >> 24) / 255.0,
                green: CGFloat((rgb & 0x00FF0000) >> 16) / 255.0,
                blue: CGFloat((rgb & 0x0000FF00) >> 8) / 255.0,
                alpha: CGFloat(rgb & 0x000000FF) / 255.0
            )
        } else {
            return nil
        }
    }
}
