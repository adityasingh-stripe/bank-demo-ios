import UIKit
import StripeTerminal

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
        
        customerButton.setTitle("Tap to select or add customer", for: .normal)
        customerButton.setTitle("Tap to select or add customer", for: .highlighted)
        customerButton.backgroundColor = UIColor.systemGray6
        customerButton.setTitleColor(UIColor.secondaryLabel, for: .normal)
        customerButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        customerButton.layer.cornerRadius = 8
        customerButton.layer.borderWidth = 1
        customerButton.layer.borderColor = UIColor.systemGray4.cgColor
        customerButton.contentHorizontalAlignment = .left
        customerButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
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
                    self?.customerButton.setTitle(customer.name, for: .normal)
                    self?.customerButton.setTitleColor(UIColor.label, for: .normal)
                })
            }
        }
        
        // Add new customer option
        alert.addAction(UIAlertAction(title: "➕ Add New Customer", style: .default) { [weak self] _ in
            self?.showAddNewCustomerDialog()
        })
        
        // Add clear option if customer is selected
        if selectedCustomer != nil {
            alert.addAction(UIAlertAction(title: "Clear Selection", style: .destructive) { [weak self] _ in
                self?.selectedCustomer = nil
                self?.customerButton.setTitle("Tap to select or add customer", for: .normal)
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
        // Validate amount from text field
        guard let amountText = amountTextField.text,
              !amountText.isEmpty,
              let amountValue = Double(amountText),
              amountValue > 0 else {
            showError("Please enter a valid amount")
            return
        }
        
        // Disable button and show loading
        collectPaymentButton.isEnabled = false
        collectPaymentButton.setTitle("Processing...", for: .normal)
        collectPaymentButton.backgroundColor = UIColor.systemGray
        
        // Convert amount to pence
        let amountInPence = UInt((amountValue * 100).rounded())
        
        print("INFO: Starting payment collection - £\(amountValue) for \(selectedCustomer?.name ?? "unknown customer")")
        
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
    
    private func handlePaymentSuccess(paymentIntent: PaymentIntent) {
        print("INFO: Payment successful - PaymentIntent: \(paymentIntent.stripeId ?? "unknown")")
        
        // Get the actual charged amount from the payment intent
        let chargedAmount = Double(paymentIntent.amount) / 100.0
        
        // Show success and dismiss
        let alert = UIAlertController(
            title: "Payment Successful!",
            message: String(format: "Payment of £%.2f completed successfully.", chargedAmount),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
            self?.delegate?.didCompletePayment(paymentIntent)
        })
        
        present(alert, animated: true)
    }
    
    private func handlePaymentError(_ error: Error) {
        print("ERROR: Payment failed - \(error.localizedDescription)")
        resetCollectPaymentButton()
        
        let alert = UIAlertController(
            title: "Payment Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Try Again", style: .default))
        present(alert, animated: true)
    }
    
    private func resetCollectPaymentButton() {
        collectPaymentButton.isEnabled = true
        collectPaymentButton.setTitle("Collect Payment", for: .normal)
        collectPaymentButton.backgroundColor = UIColor(red: 201/255, green: 43/255, blue: 35/255, alpha: 1)
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
    
    private func showAddNewCustomerDialog() {
        let alert = UIAlertController(title: "Add New Customer", message: "Enter customer details", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Customer name"
            textField.autocapitalizationType = .words
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Email address"
            textField.keyboardType = .emailAddress
            textField.autocapitalizationType = .none
        }
        
        alert.addAction(UIAlertAction(title: "Add Customer", style: .default) { [weak self] _ in
            guard let nameField = alert.textFields?[0],
                  let emailField = alert.textFields?[1],
                  let name = nameField.text, !name.isEmpty,
                  let email = emailField.text, !email.isEmpty else {
                self?.showError("Please enter both name and email")
                return
            }
            
            self?.createCustomer(name: name, email: email)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
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
                        self?.customerButton.setTitle(name, for: .normal)
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