import FirebaseAuth
import UIKit

final class FirebaseAuthUIDelegate: NSObject, AuthUIDelegate {
    func dismiss(animated flag: Bool, completion: (@Sendable () -> Void)? = nil) {
        dismiss(presentedViewController ?? UIViewController(), animated: flag, completion: completion)
    }
    
    private weak var presentingViewController: UIViewController?
    private weak var presentedViewController: UIViewController?

    init(presenting viewController: UIViewController) {
        self.presentingViewController = viewController
        super.init()
    }

    func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)?) {
        Task { @MainActor in
            guard let presenter = presentingViewController?.topMostViewController else {
                completion?()
                return
            }

            presenter.present(viewController, animated: animated) { [weak self] in
                self?.presentedViewController = viewController
                completion?()
            }
        }
    }

    func dismiss(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)?) {
        Task { @MainActor in
            let target = presentedViewController ?? viewController

            if target.presentingViewController != nil {
                target.dismiss(animated: animated) {
                    completion?()
                }
            } else if let presenter = presentingViewController?.topMostViewController,
                      presenter.presentedViewController == target {
                presenter.dismiss(animated: animated, completion: completion)
            } else {
                completion?()
            }

            presentedViewController = nil
        }
    }
}
