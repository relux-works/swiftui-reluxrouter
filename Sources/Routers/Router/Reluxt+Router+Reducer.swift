import Relux
import SwiftUI

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, macCatalyst 17, *)
extension Relux.Navigation.Router {
    /// Handles internal navigation actions to modify the router's navigation state.
    ///
    /// This method is responsible for updating the `path` property based on the received action.
    ///
    /// - Parameter action: The navigation action to be processed.
    @MainActor
    func internalReduce(with action: Relux.Navigation.Router<Page>.Action) {
        switch action {
        case let .push(page, animationDisabled):
            if animationDisabled {
                var transaction = Transaction(animation: .none)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    path.append(page)
                }
            } else {
                // Appends a new page to the navigation path
                self.path.append(page)
            }
            
            // Auto-save to UserDefaults if a key is provided
            if let key = userDefaultsKey {
                // Save synchronously to avoid capturing self in an async context
                let _ = saveNavigationPathToUserDefaults(forKey: key)
            }
            
        case let .set(pages):
            // Replaces the entire navigation path with a new set of pages
            self.path = .init(pages)
            
            // Auto-save to UserDefaults if a key is provided
            if let key = userDefaultsKey {
                // Save synchronously to avoid capturing self in an async context
                let _ = saveNavigationPathToUserDefaults(forKey: key)
            }
            
        case let .removeLast(count):
            // Removes a specified number of pages from the end of the navigation path
            let itemsCountToRemove = min(count, self.path.count)
            self.path.removeLast(itemsCountToRemove)
            
            // Auto-save to UserDefaults if a key is provided
            if let key = userDefaultsKey {
                // Save synchronously to avoid capturing self in an async context
                let _ = saveNavigationPathToUserDefaults(forKey: key)
            }
        }
    }
}
