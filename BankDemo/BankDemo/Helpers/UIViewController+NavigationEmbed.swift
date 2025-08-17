import UIKit

extension UIViewController {
    func embedInNavigationController() -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: self)
        self.navigationItem.largeTitleDisplayMode = .never
        return navigationController
    }
}
