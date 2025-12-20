import UIKit

extension UIApplication {
    static var safesnapKeyWindow: UIWindow? {
        UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

extension UIViewController {
    var topMostViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.topMostViewController
        }

        if let navigation = self as? UINavigationController,
           let visible = navigation.visibleViewController {
            return visible.topMostViewController
        }

        if let tab = self as? UITabBarController,
           let selected = tab.selectedViewController {
            return selected.topMostViewController
        }

        return self
    }
}
