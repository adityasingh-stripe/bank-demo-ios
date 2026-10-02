import Foundation

struct ConnectedAccountsResponse: Codable {
    let success: Bool
    let accounts: [ConnectedAccountSummary]
}

struct ConnectedAccountSummary: Codable, Equatable {
    let id: String
    let displayName: String
    let created: String
    let country: String
    let currency: String
    let cardPaymentsStatus: String
    let canTakeCardPayments: Bool?
}
