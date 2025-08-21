import UIKit
import CoreImage.CIFilterBuiltins

class QRCodeViewController: UIViewController {
    private let checkoutURL: String
    private let amount: Double
    private let paymentDescription: String
    
    // Theme reference
    private let theme = BankConfiguration.current
    
    init(checkoutURL: String, amount: Double, paymentDescription: String) {
        self.checkoutURL = checkoutURL
        self.amount = amount
        self.paymentDescription = paymentDescription
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Navigation bar setup
        navigationItem.title = "Payment QR Code"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Back",
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )
        
        // Main container
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Main stack view
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = theme.largeSpacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        // Title section
        let titleLabel = theme.headlineLabel(text: theme.qrCodeTitle)
        stackView.addArrangedSubview(titleLabel)
        
        // Amount display
        let amountLabel = theme.amountLabel(amount: amount)
        stackView.addArrangedSubview(amountLabel)
        
        // Description
        let descriptionLabel = theme.bodyLabel(text: paymentDescription)
        descriptionLabel.font = UIFont.systemFont(ofSize: theme.bodyFontSize, weight: .medium)
        descriptionLabel.textColor = .secondaryLabel
        stackView.addArrangedSubview(descriptionLabel)
        
        // QR Code container
        let qrContainerView = theme.cardView()
        qrContainerView.backgroundColor = .white
        stackView.addArrangedSubview(qrContainerView)
        
        // QR Code image view
        let qrImageView = UIImageView()
        qrImageView.contentMode = .scaleAspectFit
        qrImageView.translatesAutoresizingMaskIntoConstraints = false
        qrContainerView.addSubview(qrImageView)
        
        // Generate and set QR code
        if let qrImage = generateQRCode(from: checkoutURL) {
            qrImageView.image = qrImage
            print("✅ QR Code generated successfully for checkout URL")
        } else {
            // Show error if QR generation fails
            let errorStackView = UIStackView()
            errorStackView.axis = .vertical
            errorStackView.spacing = theme.smallSpacing
            errorStackView.alignment = .center
            errorStackView.translatesAutoresizingMaskIntoConstraints = false
            qrContainerView.addSubview(errorStackView)
            
            let errorImageView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
            errorImageView.tintColor = theme.warningColor
            errorImageView.contentMode = .scaleAspectFit
            errorImageView.translatesAutoresizingMaskIntoConstraints = false
            errorStackView.addArrangedSubview(errorImageView)
            
            let errorLabel = UILabel()
            errorLabel.text = "Unable to generate QR code"
            errorLabel.font = UIFont.systemFont(ofSize: theme.bodyFontSize, weight: .medium)
            errorLabel.textColor = theme.errorColor
            errorLabel.textAlignment = .center
            errorStackView.addArrangedSubview(errorLabel)
            
            NSLayoutConstraint.activate([
                errorImageView.widthAnchor.constraint(equalToConstant: 32),
                errorImageView.heightAnchor.constraint(equalToConstant: 32),
                errorStackView.centerXAnchor.constraint(equalTo: qrContainerView.centerXAnchor),
                errorStackView.centerYAnchor.constraint(equalTo: qrContainerView.centerYAnchor)
            ])
            print("❌ Failed to generate QR code for checkout URL: \(checkoutURL)")
        }
        
        // Instructions
        let instructionsLabel = theme.bodyLabel(text: theme.qrCodeInstructions)
        instructionsLabel.font = UIFont.systemFont(ofSize: theme.captionFontSize, weight: .regular)
        stackView.addArrangedSubview(instructionsLabel)
        
        // Action buttons
        let buttonStackView = UIStackView()
        buttonStackView.axis = .horizontal
        buttonStackView.spacing = theme.defaultSpacing
        buttonStackView.distribution = .fillEqually
        
        // Share button
        let shareButton = createStyledButton(
            title: "Share Link",
            systemIcon: "square.and.arrow.up",
            style: .primary
        )
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        buttonStackView.addArrangedSubview(shareButton)
        
        // Copy button
        let copyButton = createStyledButton(
            title: "Copy Link",
            systemIcon: "doc.on.doc",
            style: .secondary
        )
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        buttonStackView.addArrangedSubview(copyButton)
        
        stackView.addArrangedSubview(buttonStackView)
        
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
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -40),
            
            qrContainerView.widthAnchor.constraint(equalToConstant: 280),
            qrContainerView.heightAnchor.constraint(equalToConstant: 280),
            
            qrImageView.topAnchor.constraint(equalTo: qrContainerView.topAnchor, constant: 20),
            qrImageView.leadingAnchor.constraint(equalTo: qrContainerView.leadingAnchor, constant: 20),
            qrImageView.trailingAnchor.constraint(equalTo: qrContainerView.trailingAnchor, constant: -20),
            qrImageView.bottomAnchor.constraint(equalTo: qrContainerView.bottomAnchor, constant: -20),
            
            buttonStackView.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        ])
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        
        if let outputImage = filter.outputImage {
            // Scale up the QR code for better quality
            let scaleX = 240 / outputImage.extent.size.width
            let scaleY = 240 / outputImage.extent.size.height
            let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            
            if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        print("❌ QR Code generation failed for string: \(string)")
        return nil
    }
    
    private func createStyledButton(title: String, systemIcon: String, style: BankConfiguration.ButtonStyle) -> UIButton {
        let button = theme.styledButton(title: title, style: style)
        
        // Add icon
        if let iconImage = UIImage(systemName: systemIcon) {
            button.setImage(iconImage, for: .normal)
            button.tintColor = style == .secondary ? theme.primaryColor : .white
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
        }
        
        return button
    }
    
    @objc private func shareTapped() {
        print("📤 Share QR code checkout URL")
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
        print("📋 Copy checkout URL to clipboard")
        UIPasteboard.general.string = checkoutURL
        
        // Show confirmation
        let alert = UIAlertController(
            title: "Copied",
            message: "Payment link has been copied to your clipboard.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func backTapped() {
        print("⬅️ Back button tapped")
        dismiss(animated: true)
    }
} 