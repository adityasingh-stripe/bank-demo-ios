import UIKit
import CoreImage.CIFilterBuiltins

class CheckoutSessionViewController: UIViewController {
    private let amount: Double
    private let customer: Customer?
    private var checkoutSessionURL: String?
    private var checkoutSessionError: String?
    private let paymentDescription: String
    
    // Theme reference
    private let theme = BankConfiguration.current
    
    init(amount: Double, customer: Customer?) {
        self.amount = amount
        self.customer = customer
        self.paymentDescription = customer?.name ?? "Payment"
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        createCheckoutSession()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Navigation bar setup
        navigationItem.title = "Online Payment"
        
        // Add back button (left side)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )
        
        // Add cancel button (right side)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        
        // Clear all existing subviews
        view.subviews.forEach { $0.removeFromSuperview() }
        
        // Main container
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        if checkoutSessionURL != nil {
            setupSuccessUI(in: contentView)
        } else if checkoutSessionError != nil {
            setupErrorUI(in: contentView)
        } else {
            setupLoadingUI(in: contentView)
        }
        
        // Constraints
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
    }
    
    private func setupLoadingUI(in contentView: UIView) {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = theme.defaultSpacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        // Professional loading indicator
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = theme.primaryColor
        activityIndicator.startAnimating()
        stackView.addArrangedSubview(activityIndicator)
        
        // Title
        let titleLabel = theme.headlineLabel(text: "Preparing Payment Session")
        stackView.addArrangedSubview(titleLabel)
        
        // Amount
        let amountLabel = theme.amountLabel(amount: amount)
        stackView.addArrangedSubview(amountLabel)
        
        // Loading message
        let messageLabel = theme.bodyLabel(text: "Setting up your secure payment session...")
        stackView.addArrangedSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -40)
        ])
    }
    
    private func setupSuccessUI(in contentView: UIView) {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = theme.largeSpacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        // Success checkmark using SF Symbol
        let checkmarkImageView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkmarkImageView.tintColor = theme.successColor
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(checkmarkImageView)
        
        // Title
        let titleLabel = theme.headlineLabel(text: theme.paymentSessionTitle)
        stackView.addArrangedSubview(titleLabel)
        
        // Amount
        let amountLabel = theme.amountLabel(amount: amount)
        amountLabel.textColor = theme.successColor
        stackView.addArrangedSubview(amountLabel)
        
        // Customer info (if available)
        if let customer = customer {
            let customerView = theme.cardView()
            customerView.backgroundColor = .systemGray6
            
            let customerLabel = UILabel()
            customerLabel.text = "Customer: \(customer.name)"
            customerLabel.font = UIFont.systemFont(ofSize: theme.bodyFontSize, weight: .medium)
            customerLabel.textColor = .label
            customerLabel.textAlignment = .center
            customerLabel.translatesAutoresizingMaskIntoConstraints = false
            customerView.addSubview(customerLabel)
            
            NSLayoutConstraint.activate([
                customerLabel.topAnchor.constraint(equalTo: customerView.topAnchor, constant: theme.smallSpacing + 4),
                customerLabel.leadingAnchor.constraint(equalTo: customerView.leadingAnchor, constant: theme.defaultSpacing),
                customerLabel.trailingAnchor.constraint(equalTo: customerView.trailingAnchor, constant: -theme.defaultSpacing),
                customerLabel.bottomAnchor.constraint(equalTo: customerView.bottomAnchor, constant: -(theme.smallSpacing + 4))
            ])
            
            stackView.addArrangedSubview(customerView)
        }
        
        // Action buttons
        let buttonStackView = UIStackView()
        buttonStackView.axis = .vertical
        buttonStackView.spacing = theme.defaultSpacing
        buttonStackView.distribution = .fillEqually
        
        // Share button
        let shareButton = createStyledButton(
            title: "Share Checkout Link",
            systemIcon: "square.and.arrow.up",
            style: .primary,
            action: #selector(shareTapped)
        )
        buttonStackView.addArrangedSubview(shareButton)
        
        // Copy button
        let copyButton = createStyledButton(
            title: "Copy Checkout Link",
            systemIcon: "doc.on.doc",
            style: .secondary,
            action: #selector(copyTapped)
        )
        buttonStackView.addArrangedSubview(copyButton)
        
        // QR Code button
        let qrButton = createStyledButton(
            title: "Generate QR Code",
            systemIcon: "qrcode",
            style: .primary,
            action: #selector(qrTapped)
        )
        qrButton.backgroundColor = .systemIndigo
        buttonStackView.addArrangedSubview(qrButton)
        
        stackView.addArrangedSubview(buttonStackView)
        
        NSLayoutConstraint.activate([
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 64),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 64),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 60),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -40),
            
            buttonStackView.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        ])
    }
    
    private func setupErrorUI(in contentView: UIView) {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = theme.defaultSpacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        // Error icon using SF Symbol
        let errorImageView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        errorImageView.tintColor = theme.warningColor
        errorImageView.contentMode = .scaleAspectFit
        errorImageView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(errorImageView)
        
        // Title
        let titleLabel = theme.headlineLabel(text: "Payment Session Failed")
        titleLabel.textColor = theme.errorColor
        stackView.addArrangedSubview(titleLabel)
        
        // Error message
        let errorLabel = theme.bodyLabel(text: checkoutSessionError ?? "Unable to create payment session")
        stackView.addArrangedSubview(errorLabel)
        
        // Retry button
        let retryButton = theme.styledButton(title: "Try Again", style: .primary)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        
        // Add icon to retry button
        if let iconImage = UIImage(systemName: "arrow.clockwise") {
            retryButton.setImage(iconImage, for: .normal)
            retryButton.tintColor = .white
            retryButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
        }
        
        stackView.addArrangedSubview(retryButton)
        
        NSLayoutConstraint.activate([
            errorImageView.widthAnchor.constraint(equalToConstant: 48),
            errorImageView.heightAnchor.constraint(equalToConstant: 48),
            
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -40),
            retryButton.widthAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    private func createStyledButton(title: String, systemIcon: String, style: BankConfiguration.ButtonStyle, action: Selector) -> UIButton {
        let button = theme.styledButton(title: title, style: style)
        button.addTarget(self, action: action, for: .touchUpInside)
        
        // Add system icon
        if let iconImage = UIImage(systemName: systemIcon) {
            button.setImage(iconImage, for: .normal)
            button.tintColor = .white
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
        }
        
        return button
    }
    
    private func createCheckoutSession() {
        let market = BankConfiguration.current.activeMarket
        print("🛒 Creating checkout session for amount: \(market.format(amount))")
        
        let backendBaseURL = AppSettings.shared.selectedServerBaseURL
        guard let url = URL(string: "\(backendBaseURL)/api/create_checkout_session") else {
            print("❌ Invalid backend URL")
            showCheckoutSessionError("Configuration error: Invalid backend URL")
            return
        }
        
        guard let currentAccountId = AppDataManager.shared.currentAccountId else {
            print("❌ No account ID available")
            showCheckoutSessionError("Account error: No account ID available")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "amount": Int(amount * 100), // Convert to cents
            "currency": market.currencyCode.lowercased(),
            "account_id": currentAccountId,
            "customer": customer.map { ["id": $0.id, "name": $0.name] } ?? NSNull(),
            "description": paymentDescription
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("🛒 Checkout session request: \(requestBody)")
        } catch {
            print("❌ Failed to serialize checkout session request: \(error)")
            showCheckoutSessionError("Request error: Failed to create checkout request")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Checkout session creation failed: \(error.localizedDescription)")
                    self?.showCheckoutSessionError("Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received from checkout session API")
                    self?.showCheckoutSessionError("Server error: No response received")
                    return
                }
                
                // Check HTTP status code
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    print("❌ HTTP error: \(httpResponse.statusCode)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Error response: \(responseString)")
                    }
                    self?.showCheckoutSessionError("Server error: HTTP \(httpResponse.statusCode)")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let url = json["url"] as? String {
                            print("✅ Checkout session created: \(url)")
                            self?.checkoutSessionURL = url
                            print("🛒 Checkout session URL: \(url)")
                            self?.checkoutSessionCreationSuccess()
                        } else if let error = json["error"] as? String {
                            print("❌ Backend error creating checkout session: \(error)")
                            self?.showCheckoutSessionError("Checkout session creation failed: \(error)")
                        } else {
                            print("❌ Invalid checkout session response format: \(json)")
                            self?.showCheckoutSessionError("Server error: Invalid response format")
                        }
                    } else {
                        print("❌ Response is not valid JSON")
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("❌ Raw response: \(responseString)")
                        }
                        self?.showCheckoutSessionError("Server error: Invalid JSON response")
                    }
                } catch {
                    print("❌ Failed to parse checkout session response: \(error)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Raw response: \(responseString)")
                    }
                    self?.showCheckoutSessionError("Parsing error: Unable to process server response")
                }
            }
        }.resume()
    }
    
    private func showCheckoutSessionError(_ message: String) {
        checkoutSessionError = message
        setupUI()
    }
    
    private func checkoutSessionCreationSuccess() {
        print("✅ Checkout session creation successful, updating UI")
        setupUI()
    }
    
    @objc private func shareTapped() {
        print("📤 Share button tapped")
        guard let checkoutURL = checkoutSessionURL else {
            print("❌ No checkout URL available for sharing")
            return
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [checkoutURL],
            applicationActivities: nil
        )
        
        // For iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
    
    @objc private func copyTapped() {
        print("📋 Copy button tapped")
        guard let checkoutURL = checkoutSessionURL else {
            print("❌ No checkout URL available for copying")
            return
        }
        
        UIPasteboard.general.string = checkoutURL
        
        // Show confirmation
        let alert = UIAlertController(
            title: "Copied",
            message: "Checkout link has been copied to your clipboard.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func qrTapped() {
        print("🔲 QR Code button tapped")
        guard let checkoutURL = checkoutSessionURL else {
            print("❌ No checkout URL available for QR code")
            return
        }
        
        let qrVC = QRCodeViewController(
            checkoutURL: checkoutURL,
            amount: amount,
            paymentDescription: paymentDescription
        )
        let navController = UINavigationController(rootViewController: qrVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    @objc private func retryTapped() {
        print("🔄 Retry button tapped")
        checkoutSessionError = nil
        checkoutSessionURL = nil
        setupUI()
        createCheckoutSession()
    }
    
    @objc private func backTapped() {
        print("⬅️ Back button tapped in checkout session")
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        print("❌ Cancel checkout session")
        dismiss(animated: true)
    }
}
