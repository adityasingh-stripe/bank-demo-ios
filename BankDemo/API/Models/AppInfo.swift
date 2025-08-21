import Foundation

struct AppInfo: Codable {
    let publishableKey: String
    let logoUrl: String?
    let iconUrl: String?
    let primaryColor: String?
    let secondaryColor: String?
    
    // No custom CodingKeys needed - backend now returns camelCase field names
    // that match Swift property names exactly
}
