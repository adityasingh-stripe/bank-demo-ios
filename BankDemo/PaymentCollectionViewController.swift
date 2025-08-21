import UIKit
import StripeTerminal
import CoreImage.CIFilterBuiltins

// MARK: - Payment Collection Delegate

protocol PaymentCollectionDelegate: AnyObject {
    func didCompletePayment(_ paymentIntent: PaymentIntent)
    func didCancelPayment()
}

class PaymentCollectionViewController: UIViewController {
    weak var delegate: PaymentCollectionDelegate?
    
    private let amount: Double
    private let terminalManager: TerminalManager
    
    // UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    private let amountTextField = UITextField()
    private let customerSelectionView = UIView()
    private let customerLabel = UILabel()
    private let customerButton = UIButton()
    private let descriptionTextView = UITextView()
    private let collectPaymentButton = UIButton()
    
    private var selectedCustomer: Customer?
    
    // Customers fetched from backend
    private var customers: [Customer] = []
    
    private let backendBaseURL = AppSettings.shared.selectedServerBaseURL
    
    init(amount: Double, terminalManager: TerminalManager) {
        self.amount = amount
        self.terminalManager = terminalManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("INFO: Payment collection view loaded for amount: \(amount)")
        setupUI()
        setupConstraints()
        fetchCustomers()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = "Collect Payment"
        
        // Navigation items
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        
        // Scroll view setup
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.distribution = .fill
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        // Amount section
        let amountSection = createAmountSection()
        stackView.addArrangedSubview(amountSection)
        
        // Customer selection section
        let customerSection = createCustomerSection()
        stackView.addArrangedSubview(customerSection)
        
        // Description section
        let descriptionSection = createDescriptionSection()
        stackView.addArrangedSubview(descriptionSection)
        
        // Collect payment button
        setupCollectPaymentButton()
        stackView.addArrangedSubview(collectPaymentButton)
    }
    
    private func createAmountSection() -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = "Payment Amount"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = UIColor.label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Currency symbol
        let currencyLabel = UILabel()
        currencyLabel.text = "£"
        currencyLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        currencyLabel.textColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1)
        currencyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Editable amount field
        amountTextField.text = String(format: "%.2f", amount)
        amountTextField.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        amountTextField.textColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1)
        amountTextField.textAlignment = .left
        amountTextField.keyboardType = .decimalPad
        amountTextField.borderStyle = .none
        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Add a subtle border to indicate it's editable
        amountTextField.layer.borderWidth = 1
        amountTextField.layer.borderColor = UIColor.systemGray4.cgColor
        amountTextField.layer.cornerRadius = 8
        amountTextField.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.3)
        
        // Add padding to text field
        amountTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        amountTextField.leftViewMode = .always
        amountTextField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        amountTextField.rightViewMode = .always
        
        container.addSubview(titleLabel)
        container.addSubview(currencyLabel)
        container.addSubview(amountTextField)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            currencyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            currencyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            currencyLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            amountTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            amountTextField.leadingAnchor.constraint(equalTo: currencyLabel.trailingAnchor, constant: 8),
            amountTextField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            amountTextField.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            amountTextField.heightAnchor.constraint(equalToConstant: 48)
        ])
        
        return container
    }
    
    private func createCustomerSection() -> UIView {
        let container = UIView()
        
        customerLabel.text = "Customer (Optional)"
        customerLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        customerLabel.textColor = UIColor.label
        customerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let optionalLabel = UILabel()
        optionalLabel.text = "Leave blank for anonymous payment"
        optionalLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        optionalLabel.textColor = UIColor.secondaryLabel
        optionalLabel.translatesAutoresizingMaskIntoConstraints = false
        
        customerButton.setTitle("  Tap to select or add customer", for: .normal)
        customerButton.setTitle("  Tap to select or add customer", for: .highlighted)
        customerButton.backgroundColor = UIColor.systemGray6
        customerButton.setTitleColor(UIColor.secondaryLabel, for: .normal)
        customerButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        customerButton.layer.cornerRadius = 8
        customerButton.layer.borderWidth = 1
        customerButton.layer.borderColor = UIColor.systemGray4.cgColor
        customerButton.contentHorizontalAlignment = .left
        if #available(iOS 15.0, *) {
            customerButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        } else {
            customerButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        }
        customerButton.translatesAutoresizingMaskIntoConstraints = false
        customerButton.addTarget(self, action: #selector(selectCustomerTapped), for: .touchUpInside)
        
        container.addSubview(optionalLabel)
        
        container.addSubview(customerLabel)
        container.addSubview(customerButton)
        
        NSLayoutConstraint.activate([
            customerLabel.topAnchor.constraint(equalTo: container.topAnchor),
            customerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            optionalLabel.topAnchor.constraint(equalTo: customerLabel.bottomAnchor, constant: 2),
            optionalLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            customerButton.topAnchor.constraint(equalTo: optionalLabel.bottomAnchor, constant: 8),
            customerButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            customerButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            customerButton.heightAnchor.constraint(equalToConstant: 48),
            customerButton.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createDescriptionSection() -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = "Description (Optional)"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = UIColor.label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        descriptionTextView.font = UIFont.systemFont(ofSize: 16)
        descriptionTextView.backgroundColor = UIColor.systemGray6
        descriptionTextView.layer.cornerRadius = 8
        descriptionTextView.layer.borderWidth = 1
        descriptionTextView.layer.borderColor = UIColor.systemGray4.cgColor
        descriptionTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        descriptionTextView.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(descriptionTextView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            descriptionTextView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionTextView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            descriptionTextView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            descriptionTextView.heightAnchor.constraint(equalToConstant: 80),
            descriptionTextView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func setupCollectPaymentButton() {
        collectPaymentButton.setTitle("Collect Payment", for: .normal)
        collectPaymentButton.backgroundColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1)
        collectPaymentButton.setTitleColor(.white, for: .normal)
        collectPaymentButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        collectPaymentButton.layer.cornerRadius = 12
        collectPaymentButton.translatesAutoresizingMaskIntoConstraints = false
        collectPaymentButton.addTarget(self, action: #selector(collectPaymentTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            collectPaymentButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Stack view
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
        delegate?.didCancelPayment()
    }
    
    @objc private func selectCustomerTapped() {
        let alert = UIAlertController(title: "Customer", message: "Select an existing customer or add a new one", preferredStyle: .actionSheet)
        
        // Add existing customers
        if !customers.isEmpty {
            for customer in customers {
                let displayText = "\(customer.name) • \(customer.email)"
                alert.addAction(UIAlertAction(title: displayText, style: .default) { [weak self] _ in
                    self?.selectedCustomer = customer
                    self?.customerButton.setTitle("  \(customer.name)", for: .normal) // Added proper spacing
                    self?.customerButton.setTitleColor(UIColor.label, for: .normal)
                })
            }
        }
        
        // Add new customer option
        alert.addAction(UIAlertAction(title: "➕ Add New Customer", style: .default) { [weak self] _ in
            self?.showAddNewCustomerBottomSheet()
        })
        
        // Add clear option if customer is selected
        if selectedCustomer != nil {
            alert.addAction(UIAlertAction(title: "Clear Selection", style: .destructive) { [weak self] _ in
                self?.selectedCustomer = nil
                self?.customerButton.setTitle("  Tap to select or add customer", for: .normal)
                self?.customerButton.setTitleColor(UIColor.secondaryLabel, for: .normal)
            })
        }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            // For iPad
            if let popover = alert.popoverPresentationController {
                popover.sourceView = customerButton
                popover.sourceRect = customerButton.bounds
            }
            
            present(alert, animated: true)
    }
    
    @objc private func collectPaymentTapped() {
        print("INFO: Collect payment button tapped")
        
        // Validate amount from text field with better error handling
        guard let amountText = amountTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !amountText.isEmpty else {
            print("Empty amount field")
            showError("Please enter a valid amount")
            return
        }
        
        guard let amountValue = validateAmount(amountText) else {
            print("Invalid amount format: \(amountText)")
            showError("Please enter a valid amount (e.g., 10.50)")
            return
        }
        
        // Disable button and show loading
        collectPaymentButton.isEnabled = false
        collectPaymentButton.setTitle("Processing...", for: .normal)
        collectPaymentButton.backgroundColor = UIColor.systemGray
        
        // Convert amount to pence
        let amountInPence = UInt((amountValue * 100).rounded())
        
        print("INFO: Starting payment collection for \(amountValue) gbp")
        
        // Initialize Terminal connection if needed
        if !terminalManager.isConnectedToReader {
            connectToSimulatedReader { [weak self] success in
                Task { @MainActor in
                    if success {
                        self?.processPayment(amount: amountInPence)
                    } else {
                        self?.resetCollectPaymentButton()
                    }
                }
            }
        } else {
            processPayment(amount: amountInPence)
        }
    }
    
    private func connectToSimulatedReader(completion: @escaping @Sendable (Bool) -> Void) {
        // Store completion for when connection actually completes
        terminalManager.onConnectionComplete = completion
        
        let safeCompletion = completion
        terminalManager.discoverSimulatedReaders { result in
            Task { @MainActor [safeCompletion] in
                switch result {
                case .success:
                    // Discovery successful - connection will happen in delegate callback
                    print("INFO: Terminal reader discovered")
                case .failure(let error):
                    print("ERROR: Failed to connect to simulated reader: \(error.localizedDescription)")
                    safeCompletion(false)
                }
            }
        }
    }
    
    private func processPayment(amount: UInt) {
        terminalManager.collectPayment(amount: amount, currency: "gbp", customer: selectedCustomer) { (result: Result<PaymentIntent, Error>) in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch result {
                case .success(let paymentIntent):
                    self.handlePaymentSuccess(paymentIntent: paymentIntent)
                case .failure(let error):
                    self.handlePaymentError(error)
                }
            }
        }
    }
    
    /// Validates amount input with proper error handling
    private func validateAmount(_ amountText: String) -> Double? {
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
        guard doubleValue > 0 && doubleValue <= 10000.0 && doubleValue.isFinite else {
            return nil
        }
        
        return doubleValue
    }
    
    /// Reset the collect payment button to original state
    private func resetCollectPaymentButton() {
        collectPaymentButton.isEnabled = true
        collectPaymentButton.setTitle("Collect Payment", for: .normal)
        collectPaymentButton.backgroundColor = BankConfiguration.current.primaryColor
    }

    private func handlePaymentSuccess(paymentIntent: PaymentIntent) {
        print("🎉 Terminal SDK: Payment completed successfully: \(paymentIntent.stripeId ?? "unknown")")
        
        // Get the actual charged amount from the payment intent
        let chargedAmount = Double(paymentIntent.amount) / 100.0
        
        // Keep user on TTP screen and show success notification
        let alert = UIAlertController(
            title: "Payment Successful! 🎉",
            message: String(format: "Payment of £%.2f completed successfully.", chargedAmount),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Back to Dashboard", style: .default) { [weak self] _ in
            // Now dismiss and notify delegate
            self?.dismiss(animated: true)
            self?.delegate?.didCompletePayment(paymentIntent)
        })
        
        present(alert, animated: true)
    }
    
    private func handlePaymentError(_ error: Error) {
        print("❌ Terminal SDK: Payment failed - \(error.localizedDescription)")
        resetCollectPaymentButton()
        
        // Show the payment failure screen instead of simple alert
        showPaymentFailureScreen(amount: amount, error: error)
    }
    
    private func fetchCustomers() {
        guard let currentAccountId = AppDataManager.shared.currentAccountId else {
            print("ERROR: No account ID available")
            return
        }
        
        guard let url = URL(string: "\(backendBaseURL)/api/customers?account_id=\(currentAccountId)") else {
            print("ERROR: Invalid URL")
            return
        }
        
        print("INFO: Fetching customers for account: \(currentAccountId)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("ERROR: Failed to fetch customers: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("ERROR: No data received")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let customersData = json["customers"] as? [[String: Any]] {
                        
                        self?.customers = customersData.compactMap { customerDict in
                            guard let id = customerDict["id"] as? String,
                                  let name = customerDict["name"] as? String,
                                  let email = customerDict["email"] as? String else {
                                return nil
                            }
                            return Customer(id: id, name: name, email: email)
                        }
                        
                        print("INFO: Loaded \(self?.customers.count ?? 0) customers")
                    } else {
                        print("ERROR: Invalid response format")
                    }
                } catch {
                    print("ERROR: Failed to parse customers response: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    private func showAddNewCustomerBottomSheet() {
        let bottomSheetVC = CustomerCreationBottomSheetViewController()
        bottomSheetVC.delegate = self
        bottomSheetVC.modalPresentationStyle = .pageSheet
        
        if let sheet = bottomSheetVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(bottomSheetVC, animated: true)
    }
    
    private func showAddNewCustomerDialog() {
        // Keep old method for fallback but prefer bottom sheet
        showAddNewCustomerBottomSheet()
    }
    
    // Removed broken methods - functionality moved to CustomerCreationBottomSheetViewController
    
    private func createCustomer(name: String, email: String) {
        guard let currentAccountId = AppDataManager.shared.currentAccountId else {
            showError("No account ID available")
            return
        }
        
        guard let url = URL(string: "\(backendBaseURL)/api/customers") else {
            showError("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "account_id": currentAccountId,
            "name": name,
            "email": email
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            showError("Failed to create request")
            return
        }
        
        print("INFO: Creating customer '\(name)' for account: \(currentAccountId)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showError("Failed to create customer: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self?.showError("No data received")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let customerData = json["customer"] as? [String: Any],
                       let id = customerData["id"] as? String,
                       let name = customerData["name"] as? String,
                       let email = customerData["email"] as? String {
                        
                        let newCustomer = Customer(id: id, name: name, email: email)
                        self?.selectedCustomer = newCustomer
                        self?.customers.append(newCustomer) // Add to list for future use
                        self?.customerButton.setTitle("  \(name)", for: .normal)
                        self?.customerButton.setTitleColor(UIColor.label, for: .normal)
                        
                        print("INFO: Created customer: \(name) (\(id))")
                    } else {
                        self?.showError("Invalid response format")
                    }
                } catch {
                    self?.showError("Failed to parse response: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
} 

// MARK: - Customer Creation Bottom Sheet

protocol CustomerCreationDelegate: AnyObject {
    func didCreateCustomer(name: String, email: String)
}

class CustomerCreationBottomSheetViewController: UIViewController {
    weak var delegate: CustomerCreationDelegate?
    
    private let titleLabel = UILabel()
    private let nameTextField = UITextField()
    private let emailTextField = UITextField()
    private let addButton = UIButton()
    private let cancelButton = UIButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Title
        titleLabel.text = "Add New Customer"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Name field
        nameTextField.placeholder = "Customer name"
        nameTextField.autocapitalizationType = .words
        nameTextField.borderStyle = .roundedRect
        nameTextField.font = UIFont.systemFont(ofSize: 18)
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Email field  
        emailTextField.placeholder = "Email address"
        emailTextField.keyboardType = .emailAddress
        emailTextField.autocapitalizationType = .none
        emailTextField.borderStyle = .roundedRect
        emailTextField.font = UIFont.systemFont(ofSize: 18)
        emailTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Add button
        addButton.setTitle("Add Customer", for: .normal)
        addButton.backgroundColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1)
        addButton.setTitleColor(.white, for: .normal)
        addButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        addButton.layer.cornerRadius = 12
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.addTarget(self, action: #selector(addCustomerTapped), for: .touchUpInside)
        
        // Cancel button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor.label, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        view.addSubview(titleLabel)
        view.addSubview(nameTextField)
        view.addSubview(emailTextField)
        view.addSubview(addButton)
        view.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            nameTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nameTextField.heightAnchor.constraint(equalToConstant: 50),
            
            emailTextField.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 16),
            emailTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            emailTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            emailTextField.heightAnchor.constraint(equalToConstant: 50),
            
            addButton.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 30),
            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            addButton.heightAnchor.constraint(equalToConstant: 50),
            
            cancelButton.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cancelButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func addCustomerTapped() {
        guard let name = nameTextField.text, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let email = emailTextField.text, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("Please enter both name and email")
            return
        }
        
        delegate?.didCreateCustomer(name: name, email: email)
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - CustomerCreationDelegate
extension PaymentCollectionViewController: CustomerCreationDelegate {
    func didCreateCustomer(name: String, email: String) {
        createCustomer(name: name, email: email)
    }
    
    private func showPaymentFailureScreen(amount: Double, error: Error) {
        let failureVC = PaymentFailureViewController(amount: amount, error: error)
        failureVC.delegate = self
        let navController = UINavigationController(rootViewController: failureVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
}

// MARK: - Payment Failure Delegate
extension PaymentCollectionViewController: PaymentFailureDelegate {
    func didSelectDigitalWallet() {
        print("📱 Digital wallet option selected (not implemented)")
        // Could implement Apple Pay or other digital wallet flows here
        dismiss(animated: true)
    }
    
    func didSelectDifferentCard() {
        print("💳 Different card option selected (not implemented)")
        // Could restart the payment flow or show card selection
        dismiss(animated: true)
    }
    
    func didSelectCheckout() {
        print("🛒 Checkout option selected - creating checkout session")
        // Dismiss the failure screen first, then create checkout session
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            let checkoutVC = CheckoutSessionViewController(amount: self.amount, customer: self.selectedCustomer)
            let navController = UINavigationController(rootViewController: checkoutVC)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: true)
        }
    }
    
    func didSelectPaymentLink() {
        print("🔗 Payment link option selected - creating payment link")
        // Dismiss the failure screen first, then create payment link
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            let paymentLinkVC = PaymentLinkViewController(amount: self.amount, customer: self.selectedCustomer)
            let navController = UINavigationController(rootViewController: paymentLinkVC)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: true)
        }
    }
    
    func didCancelTransaction() {
        print("❌ Transaction cancelled by user")
        dismiss(animated: true) { [weak self] in
            // Return to dashboard
            self?.navigationController?.popToRootViewController(animated: true)
        }
    }
}
