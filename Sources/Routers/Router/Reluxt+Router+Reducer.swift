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
        let pageTypeName = _typeName(Page.self, qualified: true)
        
        switch action {
        case let .push(page, animationDisabled):
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Pushing page to navigation stack")
            
            if animationDisabled {
                var transaction = Transaction(animation: .none)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    self.path.append(page)
                }
            } else {
                // Appends a new page to the navigation path directly to avoid triggering the handler
                self.path.append(page)
            }
            
            // Update the previous count
            self.previousPathCount = self.path.count
            
            // Auto-save to UserDefaults if a key is provided
            if let key = userDefaultsKey {
                let _ = saveNavigationPathToUserDefaults(forKey: key)
            }
            
        case let .set(pages):
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Setting navigation stack to \(pages.count) pages")
            
            // Replaces the entire navigation path with a new set of pages
            self.path = .init(pages)
            
            // Update the previous count
            self.previousPathCount = self.path.count
            
            // Auto-save to UserDefaults if a key is provided
            if let key = userDefaultsKey {
                let _ = saveNavigationPathToUserDefaults(forKey: key)
            }
            
        case let .removeLast(count):
            // Removes a specified number of pages from the end of the navigation path
            let itemsCountToRemove = min(count, self.path.count)
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Removing \(itemsCountToRemove) pages from navigation stack")
            
            self.path.removeLast(itemsCountToRemove)
            
            // Update the previous count
            self.previousPathCount = self.path.count
            
            // Auto-save to UserDefaults if a key is provided
            if let key = userDefaultsKey {
                let _ = saveNavigationPathToUserDefaults(forKey: key)
            }
        }
    }
}
