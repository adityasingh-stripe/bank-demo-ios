import SafariServices
import UIKit

private struct TerminalReadersResponse: Decodable {
    let readers: [TerminalReaderSummary]
}

private struct TerminalLocationsResponse: Decodable {
    let locations: [TerminalLocationSummary]
}

private struct EnsureTerminalLocationResponse: Decodable {
    let location: TerminalLocationSummary
}

private struct RegisterTerminalReaderResponse: Decodable {
    let reader: TerminalReaderSummary
}

private struct TerminalReaderSummary: Decodable {
    let id: String
    let label: String
    let status: String
    let deviceType: String
    let serialNumber: String?
    let lastSeenAt: Int64?
    let location: TerminalLocationSummary?
}

private struct TerminalLocationSummary: Decodable {
    let id: String
    let displayName: String
}

private struct TerminalAPIErrorBody: Decodable {
    let error: String
}

private enum TerminalAPIError: LocalizedError {
    case invalidURL
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The backend URL is invalid."
        case .server(let message): return message
        case .invalidResponse: return "The server returned an invalid response."
        }
    }
}

private enum TerminalAPI {
    private static func url(path: String, query: [URLQueryItem] = []) async throws -> URL {
        let baseURL = await AppSettings.shared.selectedServerBaseURL
        guard let base = URL(string: baseURL) else { throw TerminalAPIError.invalidURL }
        let endpoint = base.appendingPathComponent(path)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw TerminalAPIError.invalidURL
        }
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw TerminalAPIError.invalidURL }
        return url
    }

    private static func decode<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TerminalAPIError.invalidResponse
        }
        let decoder = JSONDecoder()
        if !(200..<300).contains(httpResponse.statusCode) {
            let message = (try? decoder.decode(TerminalAPIErrorBody.self, from: data).error)
                ?? "Request failed (HTTP \(httpResponse.statusCode))."
            throw TerminalAPIError.server(message)
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw TerminalAPIError.invalidResponse
        }
    }

    static func readers(accountId: String) async throws -> [TerminalReaderSummary] {
        let endpoint = try await url(
            path: "api/terminal/readers",
            query: [URLQueryItem(name: "account_id", value: accountId)]
        )
        let response: TerminalReadersResponse = try await decode(URLRequest(url: endpoint))
        return response.readers
    }

    static func locations(accountId: String) async throws -> [TerminalLocationSummary] {
        let endpoint = try await url(
            path: "api/terminal/locations",
            query: [URLQueryItem(name: "account_id", value: accountId)]
        )
        let response: TerminalLocationsResponse = try await decode(URLRequest(url: endpoint))
        return response.locations
    }

    static func ensureLocation(accountId: String) async throws -> TerminalLocationSummary {
        let endpoint = try await url(path: "api/terminal/locations/ensure")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["account_id": accountId])
        let response: EnsureTerminalLocationResponse = try await decode(request)
        return response.location
    }

    static func register(
        accountId: String,
        locationId: String,
        label: String,
        registrationCode: String
    ) async throws -> TerminalReaderSummary {
        let endpoint = try await url(path: "api/terminal/readers/register")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "account_id": accountId,
            "location_id": locationId,
            "label": label,
            "registration_code": registrationCode,
        ])
        let response: RegisterTerminalReaderResponse = try await decode(request)
        return response.reader
    }

    static func accountStatus(accountId: String) async -> String? {
        guard let endpoint = try? await url(path: "api/accounts/\(accountId)/status") else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(from: endpoint),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accountStatus = json["account_status"] as? [String: Any]
        else { return nil }
        return accountStatus["status"] as? String
    }

    static func hardwarePortalURL(accountId: String) async throws -> URL {
        try await url(
            path: "terminal-hardware",
            query: [URLQueryItem(name: "account_id", value: accountId)]
        )
    }
}

@MainActor
final class TerminalViewController: UIViewController {
    private struct ReaderGroup {
        let location: TerminalLocationSummary
        let readers: [TerminalReaderSummary]
    }

    private var groups: [ReaderGroup] = []
    private var accountId: String? { AppDataManager.shared.currentAccountId }

    private let warningLabel = UILabel()
    private let readerCard = UIView()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let stateLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let orderButton = UIButton(type: .system)
    private let registerButton = UIButton(type: .system)
    private let refreshControl = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Terminal"
        view.backgroundColor = .systemGroupedBackground
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    private func setupUI() {
        navigationController?.navigationBar.tintColor = BankConfiguration.current.primaryColor

        warningLabel.font = .systemFont(ofSize: 14)
        warningLabel.textColor = BankConfiguration.current.warningColor
        warningLabel.backgroundColor = BankConfiguration.current.warningColor.withAlphaComponent(0.1)
        warningLabel.layer.cornerRadius = 10
        warningLabel.layer.masksToBounds = true
        warningLabel.numberOfLines = 0
        warningLabel.textAlignment = .center
        warningLabel.isHidden = true
        warningLabel.translatesAutoresizingMaskIntoConstraints = false

        readerCard.backgroundColor = .systemBackground
        readerCard.layer.cornerRadius = 14
        readerCard.layer.borderWidth = 1
        readerCard.layer.borderColor = UIColor.separator.cgColor
        readerCard.translatesAutoresizingMaskIntoConstraints = false

        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.refreshControl = refreshControl
        tableView.translatesAutoresizingMaskIntoConstraints = false
        refreshControl.addTarget(self, action: #selector(refreshRequested), for: .valueChanged)

        stateLabel.textAlignment = .center
        stateLabel.textColor = .secondaryLabel
        stateLabel.font = .systemFont(ofSize: 17)
        stateLabel.numberOfLines = 0
        stateLabel.translatesAutoresizingMaskIntoConstraints = false

        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        configureButton(orderButton, title: "Order Devices", action: #selector(orderDevicesTapped))
        configureButton(registerButton, title: "Register Device", action: #selector(registerDeviceTapped))

        let buttonStack = UIStackView(arrangedSubviews: [orderButton, registerButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(warningLabel)
        view.addSubview(readerCard)
        readerCard.addSubview(tableView)
        readerCard.addSubview(stateLabel)
        readerCard.addSubview(activityIndicator)
        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            warningLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            warningLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            warningLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            readerCard.topAnchor.constraint(equalTo: warningLabel.bottomAnchor, constant: 12),
            readerCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            readerCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: readerCard.topAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: readerCard.leadingAnchor, constant: 4),
            tableView.trailingAnchor.constraint(equalTo: readerCard.trailingAnchor, constant: -4),
            tableView.bottomAnchor.constraint(equalTo: readerCard.bottomAnchor, constant: -4),

            stateLabel.centerXAnchor.constraint(equalTo: readerCard.centerXAnchor),
            stateLabel.centerYAnchor.constraint(equalTo: readerCard.centerYAnchor),
            stateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: readerCard.leadingAnchor, constant: 24),
            stateLabel.trailingAnchor.constraint(lessThanOrEqualTo: readerCard.trailingAnchor, constant: -24),

            activityIndicator.centerXAnchor.constraint(equalTo: readerCard.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: readerCard.centerYAnchor),

            buttonStack.topAnchor.constraint(equalTo: readerCard.bottomAnchor, constant: 20),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    private func configureButton(_ button: UIButton, title: String, action: Selector) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = BankConfiguration.current.primaryColor.withAlphaComponent(0.14)
        configuration.baseForegroundColor = BankConfiguration.current.primaryColor
        configuration.cornerStyle = .medium
        button.configuration = configuration
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.heightAnchor.constraint(equalToConstant: 54).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    @objc private func refreshRequested() {
        loadData()
    }

    private func loadData() {
        guard let accountId else {
            groups = []
            tableView.reloadData()
            setState("Select or create an account to manage Terminal devices.", loading: false)
            orderButton.isEnabled = false
            registerButton.isEnabled = false
            warningLabel.isHidden = true
            refreshControl.endRefreshing()
            return
        }

        setState(nil, loading: !refreshControl.isRefreshing)
        orderButton.isEnabled = true
        registerButton.isEnabled = true

        Task {
            async let readerRequest = TerminalAPI.readers(accountId: accountId)
            async let statusRequest = TerminalAPI.accountStatus(accountId: accountId)
            do {
                let (readers, status) = try await (readerRequest, statusRequest)
                groups = Dictionary(grouping: readers) { reader in
                    reader.location?.id ?? "unassigned"
                }
                .map { _, readers in
                    ReaderGroup(
                        location: readers.first?.location
                            ?? TerminalLocationSummary(id: "unassigned", displayName: "Unassigned"),
                        readers: readers.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
                    )
                }
                .sorted { $0.location.displayName.localizedCaseInsensitiveCompare($1.location.displayName) == .orderedAscending }
                tableView.reloadData()
                setState(groups.isEmpty ? "No registered Terminal devices" : nil, loading: false)
                updateStatusWarning(status)
            } catch {
                groups = []
                tableView.reloadData()
                setState("Unable to load readers.\n\(error.localizedDescription)\nPull down to retry.", loading: false)
            }
            refreshControl.endRefreshing()
        }
    }

    private func setState(_ message: String?, loading: Bool) {
        stateLabel.text = message
        stateLabel.isHidden = message == nil
        tableView.isHidden = message != nil || loading
        loading ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
    }

    private func updateStatusWarning(_ status: String?) {
        guard let status, status != "Enabled" else {
            warningLabel.isHidden = true
            return
        }
        warningLabel.text = "  Card payments are currently \(status.lowercased()). You can manage devices, but they cannot take payments until card payments are active.  "
        warningLabel.isHidden = false
    }

    @objc private func orderDevicesTapped() {
        guard let accountId else { return }
        Task {
            do {
                let url = try await TerminalAPI.hardwarePortalURL(accountId: accountId)
                present(SFSafariViewController(url: url), animated: true)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    @objc private func registerDeviceTapped() {
        guard let accountId else { return }
        registerButton.isEnabled = false
        Task {
            defer { registerButton.isEnabled = true }
            do {
                var locations = try await TerminalAPI.locations(accountId: accountId)
                if locations.isEmpty {
                    locations = [try await TerminalAPI.ensureLocation(accountId: accountId)]
                }
                chooseLocation(locations, accountId: accountId)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private func chooseLocation(_ locations: [TerminalLocationSummary], accountId: String) {
        guard locations.count > 1 else {
            if let location = locations.first { showRegistrationForm(location: location, accountId: accountId) }
            return
        }
        let sheet = UIAlertController(title: "Choose location", message: nil, preferredStyle: .actionSheet)
        locations.forEach { location in
            sheet.addAction(UIAlertAction(title: location.displayName, style: .default) { [weak self] _ in
                self?.showRegistrationForm(location: location, accountId: accountId)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = registerButton
            popover.sourceRect = registerButton.bounds
        }
        present(sheet, animated: true)
    }

    private func showRegistrationForm(location: TerminalLocationSummary, accountId: String) {
        let alert = UIAlertController(
            title: "Register Device",
            message: "Location: \(location.displayName)\nEnter the device label and three-word pairing code shown on the reader.",
            preferredStyle: .alert
        )
        alert.addTextField {
            $0.placeholder = "Device label"
            $0.autocapitalizationType = .words
        }
        alert.addTextField {
            $0.placeholder = "word-word-word or simulated-s700"
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Register", style: .default) { [weak self, weak alert] _ in
            guard let label = alert?.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let code = alert?.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !label.isEmpty, !code.isEmpty
            else {
                self?.showError("Enter both a device label and pairing code.")
                return
            }
            self?.register(accountId: accountId, location: location, label: label, code: code)
        })
        present(alert, animated: true)
    }

    private func register(
        accountId: String,
        location: TerminalLocationSummary,
        label: String,
        code: String
    ) {
        Task {
            do {
                _ = try await TerminalAPI.register(
                    accountId: accountId,
                    locationId: location.id,
                    label: label,
                    registrationCode: code
                )
                let alert = UIAlertController(
                    title: "Device Registered",
                    message: "The reader may restart while it applies its settings.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in self?.loadData() })
                present(alert, animated: true)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Terminal Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension TerminalViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { groups.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groups[section].readers.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        groups[section].location.displayName
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "TerminalReaderCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: identifier)
        let reader = groups[indexPath.section].readers[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = reader.label
        let model = reader.deviceType.replacingOccurrences(of: "_", with: " ").capitalized
        content.secondaryText = [model, reader.serialNumber].compactMap { $0 }.joined(separator: " • ")
        content.image = UIImage(systemName: "circle.fill")
        content.imageProperties.tintColor = reader.status == "online" ? .systemGreen : .systemGray
        content.imageProperties.maximumSize = CGSize(width: 12, height: 12)
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        return cell
    }
}
