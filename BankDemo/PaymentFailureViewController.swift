import UIKit

protocol PaymentFailureDelegate: AnyObject {
    func didSelectDigitalWallet()
    func didSelectDifferentCard()
    func didSelectCheckout()
    func didSelectPaymentLink()
    func didCancelTransaction()
}

class PaymentFailureViewController: UIViewController {
    weak var delegate: PaymentFailureDelegate?
    private let amount: Double
    private let error: Error
    
    // Theme reference
    private let theme = BankConfiguration.current
    
    init(amount: Double, error: Error) {
        self.amount = amount
        self.error = error
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
        navigationItem.title = "Payment Failed"
        
        // Add back button (left side)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
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
        
        // Header section
        let headerView = createHeaderView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerView)
        
        // Options list
        let optionsStackView = createOptionsListView()
        optionsStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(optionsStackView)
        
        // Cancel button
        let cancelButton = theme.styledButton(title: "Cancel Transaction", style: .danger)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cancelButton)
        
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
            
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            optionsStackView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 40),
            optionsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            optionsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            cancelButton.topAnchor.constraint(equalTo: optionsStackView.bottomAnchor, constant: 40),
            cancelButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }
    
    private func createHeaderView() -> UIView {
        let headerView = UIView()
        
        // Error icon using SF Symbol
        let errorImageView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        errorImageView.tintColor = theme.warningColor
        errorImageView.contentMode = .scaleAspectFit
        errorImageView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(errorImageView)
        
        // Title
        let titleLabel = theme.titleLabel(text: theme.paymentFailedTitle)
        headerView.addSubview(titleLabel)
        
        // Amount
        let amountLabel = theme.amountLabel(amount: amount)
        amountLabel.textColor = theme.errorColor
        headerView.addSubview(amountLabel)
        
        // Error message
        let errorLabel = theme.bodyLabel(text: error.localizedDescription)
        headerView.addSubview(errorLabel)
        
        NSLayoutConstraint.activate([
            errorImageView.topAnchor.constraint(equalTo: headerView.topAnchor),
            errorImageView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            errorImageView.widthAnchor.constraint(equalToConstant: 48),
            errorImageView.heightAnchor.constraint(equalToConstant: 48),
            
            titleLabel.topAnchor.constraint(equalTo: errorImageView.bottomAnchor, constant: theme.defaultSpacing),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            
            amountLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: theme.smallSpacing),
            amountLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            amountLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            
            errorLabel.topAnchor.constraint(equalTo: amountLabel.bottomAnchor, constant: theme.defaultSpacing),
            errorLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            errorLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
        ])
        
        return headerView
    }
    
    private func createOptionsListView() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 1
        stackView.backgroundColor = .systemGray5
        stackView.layer.cornerRadius = theme.cardCornerRadius
        stackView.clipsToBounds = true
        
        // Option 1: Digital Wallet (just text, not clickable)
        let digitalWalletOption = createOptionRow(
            systemIcon: "wallet.pass",
            title: "Use a digital wallet",
            subtitle: "Apple Pay, Google Pay, etc.",
            isEnabled: false,
            action: nil
        )
        stackView.addArrangedSubview(digitalWalletOption)
        
        // Separator
        let separator1 = createSeparator()
        stackView.addArrangedSubview(separator1)
        
        // Option 2: Different Card (just text, not clickable)
        let differentCardOption = createOptionRow(
            systemIcon: "creditcard",
            title: "Try using a different card",
            subtitle: "Use another payment method",
            isEnabled: false,
            action: nil
        )
        stackView.addArrangedSubview(differentCardOption)
        
        // Separator
        let separator2 = createSeparator()
        stackView.addArrangedSubview(separator2)
        
        // Option 3: Payment Fallback (clickable)
        let fallbackAction: Selector
        switch theme.paymentFallbackType {
        case .checkoutSession:
            fallbackAction = #selector(checkoutTapped)
        case .paymentLink:
            fallbackAction = #selector(paymentLinkTapped)
        }
        
        // Create appropriate title based on fallback type
        let fallbackTitle: String
        switch theme.paymentFallbackType {
        case .checkoutSession:
            fallbackTitle = "Pay using \(theme.paymentFallbackType.displayName.lowercased())"
        case .paymentLink:
            fallbackTitle = "Share a payment link"
        }
        
        let fallbackOption = createOptionRow(
            systemIcon: theme.paymentFallbackType.systemIcon,
            title: fallbackTitle,
            subtitle: theme.paymentFallbackType.subtitle,
            isEnabled: true,
            action: fallbackAction
        )
        stackView.addArrangedSubview(fallbackOption)
        
        return stackView
    }
    
    private func createOptionRow(systemIcon: String, title: String, subtitle: String, isEnabled: Bool, action: Selector?) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = theme.defaultSpacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        // Icon using SF Symbol - all options look normal
        let iconImageView = UIImageView(image: UIImage(systemName: systemIcon))
        iconImageView.tintColor = theme.primaryColor
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(iconImageView)
        
        // Text content - all options look normal
        let textStackView = UIStackView()
        textStackView.axis = .vertical
        textStackView.spacing = 2
        textStackView.alignment = .leading
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: theme.bodyFontSize, weight: .medium)
        titleLabel.textColor = .label  // Always use normal text color
        textStackView.addArrangedSubview(titleLabel)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: theme.captionFontSize, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        textStackView.addArrangedSubview(subtitleLabel)
        
        stackView.addArrangedSubview(textStackView)
        
        // Chevron only for enabled options
        if isEnabled {
            let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.right"))
            chevronImageView.tintColor = .systemGray3
            chevronImageView.contentMode = .scaleAspectFit
            chevronImageView.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(chevronImageView)
            
            NSLayoutConstraint.activate([
                chevronImageView.widthAnchor.constraint(equalToConstant: 12),
                chevronImageView.heightAnchor.constraint(equalToConstant: 12)
            ])
        }
        
        // Add tap gesture only for enabled options
        if isEnabled, let action = action {
            let tapGesture = UITapGestureRecognizer(target: self, action: action)
            containerView.addGestureRecognizer(tapGesture)
            containerView.isUserInteractionEnabled = true
        } else {
            containerView.isUserInteractionEnabled = false
        }
        
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: theme.defaultSpacing),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: theme.defaultSpacing),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -theme.defaultSpacing),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -theme.defaultSpacing)
        ])
        
        return containerView
    }
    
    private func createSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = .systemGray5
        separator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
        
        return separator
    }
    
    @objc private func checkoutTapped() {
        print("🛒 Checkout option selected")
        delegate?.didSelectCheckout()
    }
    
    @objc private func paymentLinkTapped() {
        print("🔗 Payment link option selected")
        delegate?.didSelectPaymentLink()
    }
    
    @objc private func backTapped() {
        print("⬅️ Back button tapped in payment failure")
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        print("⬅️ Cancel button tapped in payment failure")
        delegate?.didCancelTransaction()
    }
} 