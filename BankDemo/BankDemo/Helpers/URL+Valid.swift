import UIKit

extension URL {
    @MainActor 
    var isValid: Bool {
        UIApplication.shared.canOpenURL(self)
    }
}
