//
//  TerminalManager.swift
//  BankConfiguration.current.errorDomain
//
//  Created by Claude on Terminal Integration.
//  Copyright © 2024 Stripe. All rights reserved.
//

import Foundation
import StripeTerminal

// MARK: - UnsafeSendable wrapper for non-sendable types
struct UnsafeSendable<T>: @unchecked Sendable {
    let value: T
    
    init(_ value: T) {
        self.value = value
    }
}

// MARK: - Customer Model
struct Customer {
    let id: String
    let name: String
    let email: String
}
import UIKit

// MARK: - Connection Token Provider
class BankConnectionTokenProvider: NSObject, ConnectionTokenProvider {
    func fetchConnectionToken(_ completion: @escaping ConnectionTokenCompletionBlock) {
        let safeCompletion = UnsafeSendable(completion)
        Task { @MainActor in
            // Get the backend URL from centralized app settings
            guard let backendURL = URL(string: AppSettings.shared.selectedServerBaseURL) else {
                safeCompletion.value(nil, NSError(domain: BankConfiguration.current.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid backend URL"]))
                return
            }
            
            // Get current account ID from AppDataManager
            guard let accountId = AppDataManager.shared.getCurrentAccountId() else {
                safeCompletion.value(nil, NSError(domain: BankConfiguration.current.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "No account ID available"]))
                return
            }
        
            let url = backendURL.appendingPathComponent("api/connection_token")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body = ["account_id": accountId]
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                safeCompletion.value(nil, error)
                return
            }
            
            let sessionCompletion = safeCompletion
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    sessionCompletion.value(nil, error)
                    return
                }
                
                guard let data = data else {
                    sessionCompletion.value(nil, NSError(domain: BankConfiguration.current.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let secret = json["secret"] as? String {
                        sessionCompletion.value(secret, nil)
                    } else {
                        sessionCompletion.value(nil, NSError(domain: BankConfiguration.current.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"]))
                    }
                } catch {
                    sessionCompletion.value(nil, error)
                }
            }.resume()
        }
    }
}

// MARK: - Terminal Manager
class TerminalManager: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = TerminalManager()
    
    @Published var isConnectedToReader = false
    @Published var currentReader: Reader?
    @Published var connectionStatus: ConnectionStatus = .notConnected
    
    private let connectionTokenProvider = BankConnectionTokenProvider()
    private var discoveryCancelable: Cancelable?
    private var paymentCancelable: Cancelable?
    
    // Completion handler for connection events
    var onConnectionComplete: ((Bool) -> Void)?
    
    // Auto-reconnection state
    private var isReconnecting = false
    private var pendingPaymentCompletion: ((Result<PaymentIntent, Error>) -> Void)?
    
    // Timeout management
    private var paymentTimeoutTimer: Timer?
    private var reconnectionTimeoutTimer: Timer?
    private let paymentTimeout: TimeInterval = 60.0 // 60 seconds
    private let reconnectionTimeout: TimeInterval = 30.0 // 30 seconds
    
    override init() {
        super.init()
        setupTerminal()
    }
    
    private func setupTerminal() {
        // Initialize Terminal with the connection token provider
        Terminal.setTokenProvider(connectionTokenProvider)
    }
    
    // MARK: - Reader Discovery and Connection
    
    func discoverSimulatedReaders(completion: @escaping @Sendable (Result<[Reader], Error>) -> Void) {
        // Discover simulated Tap to Pay readers
        let config: DiscoveryConfiguration
        do {
            config = try TapToPayDiscoveryConfigurationBuilder()
                .setSimulated(true)
                .build()
        } catch {
            completion(.failure(error))
            return
        }
        
        discoveryCancelable = Terminal.shared.discoverReaders(config, delegate: self) { error in
            if let error = error {
                completion(.failure(error))
            }
            // Results will be delivered via delegate methods
        }
    }
    
    func connectToSimulatedReader(_ reader: Reader, completion: @escaping @Sendable (Result<Reader, Error>) -> Void) {
        // For Tap to Pay readers - get location from connected account
        let sendableCompletion = completion
        fetchAccountLocation { [weak self] result in
            switch result {
            case .success(let locationId):
                self?.connectWithLocation(reader: reader, locationId: locationId, completion: sendableCompletion)
            case .failure(let error):
                sendableCompletion(.failure(error))
            }
        }
    }
    
    private func fetchAccountLocation(completion: @escaping (Result<String, Error>) -> Void) {
        let safeCompletion = UnsafeSendable(completion)
        Task { @MainActor in
                        guard let accountId = AppDataManager.shared.getCurrentAccountId() else {
                safeCompletion.value(.failure(NSError(domain: BankConfiguration.current.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "No account ID available"])))
                return
            }
            let baseURL = AppSettings.shared.selectedServerBaseURL
            guard let url = URL(string: "\(baseURL)/api/locations?account_id=\(accountId)") else {
                safeCompletion.value(.failure(NSError(domain: BankConfiguration.current.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }
            
            let urlCompletion = safeCompletion
            URLSession.shared.dataTask(with: URLRequest(url: url)) { data, response, error in
            if let error = error {
                urlCompletion.value(.failure(error))
                return
            }
            
            guard let data = data else {
                urlCompletion.value(.failure(NSError(domain: BankConfiguration.current.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let locations = json["locations"] as? [[String: Any]],
                   let firstLocation = locations.first,
                   let locationId = firstLocation["id"] as? String {
                    urlCompletion.value(.success(locationId))
                } else {
                    urlCompletion.value(.failure(NSError(domain: BankConfiguration.current.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "No locations found for account"])))
                }
            } catch {
                urlCompletion.value(.failure(error))
            }
        }.resume()
        }
    }
    
    nonisolated private func connectWithLocation(reader: Reader, locationId: String, completion: @escaping @Sendable (Result<Reader, Error>) -> Void) {
        let connectionConfig: ConnectionConfiguration
        do {
            connectionConfig = try TapToPayConnectionConfigurationBuilder(
                delegate: self,
                locationId: locationId
            )
            .setAutoReconnectOnUnexpectedDisconnect(true)
            .build()
        } catch {
            completion(.failure(error))
            return
        }
        
        let safeCompletion = UnsafeSendable(completion)
        Terminal.shared.connectReader(reader, connectionConfig: connectionConfig) { connectedReader, error in
            Task { @MainActor [weak self, safeCompletion] in
                if let connectedReader = connectedReader {
                    self?.currentReader = connectedReader
                    self?.isConnectedToReader = true
                    safeCompletion.value(.success(connectedReader))
                } else if let error = error {
                    safeCompletion.value(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Payment Processing
    
    func collectPayment(amount: UInt, currency: String = "gbp", customer: Customer? = nil, completion: @escaping @Sendable (Result<PaymentIntent, Error>) -> Void) {
        // Clear any existing timeout timers
        clearTimeoutTimers()
        
        // Start payment timeout timer
        startPaymentTimeout(completion: completion)
        
        // Check if we're connected to a reader
        guard isConnectedToReader else {
            // Auto-reconnect and retry payment
            reconnectAndRetryPayment(amount: amount, currency: currency, customer: customer, completion: completion)
            return
        }
        
        // Step 1: Create PaymentIntent using Terminal SDK
        createPaymentIntent(amount: amount, currency: currency, customer: customer) { [weak self] (result: Result<PaymentIntent, Error>) in
            switch result {
            case .success(let paymentIntent):
                // Step 2: Collect payment method
                self?.collectPaymentMethod(paymentIntent: paymentIntent, completion: completion)
            case .failure(let error):
                // Check if error is due to connection issues
                if self?.isConnectionError(error) == true {
                    print("WARN: Connection error detected, attempting reconnection...")
                    self?.reconnectAndRetryPayment(amount: amount, currency: currency, customer: customer, completion: completion)
                } else {
                    self?.clearTimeoutTimers()
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func reconnectAndRetryPayment(amount: UInt, currency: String, customer: Customer? = nil, completion: @escaping @Sendable (Result<PaymentIntent, Error>) -> Void) {
        guard !isReconnecting else {
            completion(.failure(NSError(domain: BankConfiguration.current.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Already reconnecting..."])))
            return
        }
        
        isReconnecting = true
        pendingPaymentCompletion = completion
        
        // Start reconnection timeout
        startReconnectionTimeout(completion: completion)
        
        print("INFO: Reconnecting to reader for payment retry...")
        
        // Discover and connect to reader
        discoverSimulatedReaders { [weak self] result in
            self?.isReconnecting = false
            
            switch result {
            case .success:
                // Clear reconnection timeout since we succeeded
                self?.reconnectionTimeoutTimer?.invalidate()
                self?.reconnectionTimeoutTimer = nil
                
                // Connection successful, retry payment
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.collectPayment(amount: amount, currency: currency, customer: customer, completion: completion)
                }
            case .failure(let error):
                self?.clearTimeoutTimers()
                completion(.failure(error))
            }
            
            self?.pendingPaymentCompletion = nil
        }
    }
    
    private func isConnectionError(_ error: Error) -> Bool {
        let errorString = error.localizedDescription.lowercased()
        return errorString.contains("expired api key") || 
               errorString.contains("connection") ||
               errorString.contains("reader") ||
               errorString.contains("pss_test")
    }
    
    nonisolated private func createPaymentIntent(amount: UInt, currency: String, customer: Customer? = nil, completion: @escaping @Sendable (Result<PaymentIntent, Error>) -> Void) {
        // Create PaymentIntent via backend
        // then retrieve it using Terminal SDK
        Task { @MainActor in
            guard let url = URL(string: "\(AppSettings.shared.selectedServerBaseURL)/api/create_payment_intent") else {
                completion(.failure(NSError(domain: BankConfiguration.current.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }
        
        // Get current account ID from AppDataManager
        guard let accountId = AppDataManager.shared.getCurrentAccountId() else {
            completion(.failure(NSError(domain: BankConfiguration.current.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "No account ID available"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "amount": amount,
            "currency": currency,
            "capture_method": "automatic",
            "account_id": accountId
        ]
        
        // Add customer information if provided
        if let customer = customer {
            body["customer"] = [
                "id": customer.id,
                "name": customer.name,
                "email": customer.email
            ]
        }
        
        print("INFO: Creating payment intent with body: \(body)")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("ERROR: Failed to encode payment intent request: \(error)")
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("ERROR: Payment intent creation network error: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("ERROR: Invalid HTTP response for payment intent creation")
                completion(.failure(NSError(domain: BankConfiguration.current.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])))
                return
            }
            
            print("INFO: Payment intent creation response status: \(httpResponse.statusCode)")
            
            guard let data = data else {
                print("ERROR: No data received from payment intent creation")
                completion(.failure(NSError(domain: BankConfiguration.current.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("INFO: Payment intent creation response body: \(responseString)")
            }
            
            guard httpResponse.statusCode == 200 else {
                print("ERROR: Payment intent creation failed with status \(httpResponse.statusCode)")
                completion(.failure(NSError(domain: BankConfiguration.current.errorDomain, code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let clientSecret = json["clientSecret"] as? String {
                    
                    // Log customer information if present
                    if let customerData = json["customer"] as? [String: Any],
                       let customerId = customerData["id"] as? String,
                       let customerName = customerData["name"] as? String {
                        print("INFO: Payment Intent created with customer: \(customerName) (\(customerId))")
                    } else {
                        print("INFO: Payment Intent created without customer")
                    }
                    
                    // Now retrieve the PaymentIntent using Terminal SDK
                    let retrieveCompletion = UnsafeSendable(completion)
                    Terminal.shared.retrievePaymentIntent(clientSecret: clientSecret) { paymentIntent, error in
                        Task { @MainActor [retrieveCompletion] in
                            if let paymentIntent = paymentIntent {
                                print("INFO: Retrieved PaymentIntent \(paymentIntent.stripeId) for £\(Double(paymentIntent.amount)/100.0)")
                                retrieveCompletion.value(.success(paymentIntent))
                            } else if let error = error {
                                retrieveCompletion.value(.failure(error))
                            }
                        }
                    }
                } else {
                    completion(.failure(NSError(domain: BankConfiguration.current.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
        }
    }
    
    private func collectPaymentMethod(paymentIntent: PaymentIntent, completion: @escaping @Sendable (Result<PaymentIntent, Error>) -> Void) {
        print("INFO: Collecting payment for \(paymentIntent.stripeId)")
        
        // Use default collect config for Tap to Pay
        paymentCancelable = Terminal.shared.collectPaymentMethod(paymentIntent) { [weak self] paymentIntentWithPaymentMethod, error in
            if let paymentIntentWithPaymentMethod = paymentIntentWithPaymentMethod {
                // Step 3: Confirm payment
                self?.confirmPayment(paymentIntent: paymentIntentWithPaymentMethod, completion: completion)
            } else if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    nonisolated private func confirmPayment(paymentIntent: PaymentIntent, completion: @escaping @Sendable (Result<PaymentIntent, Error>) -> Void) {
        // Use default confirm config for Tap to Pay
        let safeCompletion = UnsafeSendable(completion)
        Terminal.shared.confirmPaymentIntent(paymentIntent) { confirmedIntent, error in
            Task { @MainActor [weak self, safeCompletion] in
                if let confirmedIntent = confirmedIntent {
                    self?.clearTimeoutTimers()
                    safeCompletion.value(.success(confirmedIntent))
                } else if let error = error {
                    self?.clearTimeoutTimers()
                    safeCompletion.value(.failure(error))
                }
            }
        }
    }
    
    func cancelPayment() {
        paymentCancelable?.cancel { error in
            if let error = error {
                print("Error canceling payment: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Terminal Delegate
extension TerminalManager: TerminalDelegate {
    func terminal(_ terminal: Terminal, didChangeConnectionStatus status: ConnectionStatus) {
        DispatchQueue.main.async {
            self.connectionStatus = status
            self.isConnectedToReader = (status == .connected)
            
            if status == .connected {
                print("INFO: Terminal connection established")
            } else if status == .notConnected {
                print("INFO: Terminal disconnected")
            }
        }
    }
    
    func terminal(_ terminal: Terminal, didReportUnexpectedReaderDisconnect reader: Reader) {
        print("WARN: Unexpected reader disconnect: \(reader.label ?? "Unknown")")
        DispatchQueue.main.async {
            self.currentReader = nil
            self.isConnectedToReader = false
        }
    }
}

// MARK: - Discovery Delegate
extension TerminalManager: DiscoveryDelegate {
    func terminal(_ terminal: Terminal, didUpdateDiscoveredReaders readers: [Reader]) {
        // Auto-connect to the first simulated reader found
        if let simulatedReader = readers.first {
                                connectToSimulatedReader(simulatedReader) { [weak self] result in
                        switch result {
                        case .success(let reader):
                            print("INFO: Connected to simulated reader: \(reader.label ?? "Unknown")")
                            // Notify that connection is complete
                            DispatchQueue.main.async {
                                self?.onConnectionComplete?(true)
                                self?.onConnectionComplete = nil // Clear the callback
                            }
                        case .failure(let error):
                            print("ERROR: Failed to connect to simulated reader: \(error.localizedDescription)")
                            // Notify that connection failed
                            DispatchQueue.main.async {
                                self?.onConnectionComplete?(false)
                                self?.onConnectionComplete = nil // Clear the callback
                            }
                        }
                    }
        }
    }
}

// MARK: - Reader Delegates
extension TerminalManager: ReaderDelegate {
    func reader(_ reader: Reader, didDisconnect reason: DisconnectReason) {
        DispatchQueue.main.async {
            self.currentReader = nil
            self.isConnectedToReader = false
        }
        print("INFO: Reader disconnected: \(reason)")
    }
}

// MARK: - TapToPayReaderDelegate
extension TerminalManager: TapToPayReaderDelegate {
    func tapToPayReader(_ reader: Reader, didStartInstallingUpdate update: ReaderSoftwareUpdate, cancelable: Cancelable?) {
        print("INFO: Tap to Pay reader started installing update")
    }
    
    func tapToPayReader(_ reader: Reader, didReportReaderSoftwareUpdateProgress progress: Float) {
        
    }
    
    func tapToPayReader(_ reader: Reader, didFinishInstallingUpdate update: ReaderSoftwareUpdate?, error: Error?) {
        if let error = error {
            print("ERROR: Tap to Pay reader update failed: \(error.localizedDescription)")
        } else {
            print("INFO: Tap to Pay reader update completed")
        }
    }
    
    func tapToPayReaderDidAcceptTermsOfService(_ reader: Reader) {
        print("INFO: Tap to Pay reader accepted terms of service")
    }
    
    func tapToPayReader(_ reader: Reader, didRequestReaderInput inputOptions: ReaderInputOptions) {

    }
    
    func tapToPayReader(_ reader: Reader, didRequestReaderDisplayMessage displayMessage: ReaderDisplayMessage) {

    }
    
    // MARK: - Timeout Management
    
    private func startPaymentTimeout(completion: @escaping @Sendable (Result<PaymentIntent, Error>) -> Void) {
        let sendableCompletion = completion
        paymentTimeoutTimer = Timer.scheduledTimer(withTimeInterval: paymentTimeout, repeats: false) { [weak self] _ in
            print("ERROR: Payment timeout after \(self?.paymentTimeout ?? 0) seconds")
            self?.cancelCurrentPayment()
            self?.clearTimeoutTimers()
            completion(.failure(NSError(
                domain: BankConfiguration.current.errorDomain,
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Payment timeout - please try again"]
            )))
        }
    }
    
    private func startReconnectionTimeout(completion: @escaping @Sendable (Result<PaymentIntent, Error>) -> Void) {
        let sendableCompletion = completion
        reconnectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: reconnectionTimeout, repeats: false) { [weak self] _ in
            print("ERROR: Reconnection timeout after \(self?.reconnectionTimeout ?? 0) seconds")
            self?.isReconnecting = false
            self?.pendingPaymentCompletion = nil
            self?.clearTimeoutTimers()
            sendableCompletion(.failure(NSError(
                domain: BankConfiguration.current.errorDomain,
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Connection timeout - please try again"]
            )))
        }
    }
    
    private func clearTimeoutTimers() {
        paymentTimeoutTimer?.invalidate()
        paymentTimeoutTimer = nil
        reconnectionTimeoutTimer?.invalidate()
        reconnectionTimeoutTimer = nil
    }
    
    private func cancelCurrentPayment() {
        // Cancel any ongoing payment collection
        paymentCancelable?.cancel { error in
            if let error = error {
                print("WARN: Error canceling payment: \(error.localizedDescription)")
            }
        }
        paymentCancelable = nil
        
        // Reset reconnection state
        isReconnecting = false
        pendingPaymentCompletion = nil
    }
} 