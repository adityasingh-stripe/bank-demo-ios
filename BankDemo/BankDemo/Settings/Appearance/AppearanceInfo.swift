import Foundation
import StripeConnect

struct AppearanceInfo: Identifiable {
    var id: String {
        return displayName
    }
    let displayName: String
    var appearance: EmbeddedComponentManager.Appearance
}
