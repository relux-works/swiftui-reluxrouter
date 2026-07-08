import Relux
import SwiftUI

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, macCatalyst 17, *)
extension Relux.Navigation.CodableProjectedRouter {
    /// Handles internal navigation actions to modify the router's navigation state.
    ///
    /// This method is responsible for updating the `path` property based on the received action.
    ///
    /// - Parameter action: The navigation action to be processed.
    func internalReduce(with action: Relux.Navigation.CodableProjectedRouter<Page>.Action) {
        let pageTypeName = _typeName(Page.self, qualified: true)
        _isInternalChange = true

        switch action {
        case let .push(page, animationDisabled):
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Pushing page to navigation stack")
            if animationDisabled {
                var transaction = Transaction(animation: .none)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    path.append(page)
                }
            } else {
                path.append(page)
            }

        case let .set(pages):
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Setting navigation stack to \(pages.count) pages")
            path = .init(pages)

        case let .removeLast(count):
            let itemsCountToRemove = min(count, self.path.count)
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Removing \(itemsCountToRemove) pages from navigation stack")
            path.removeLast(itemsCountToRemove)

        case .removeBeforeLast:
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Removing page before last from customPath if exists")
            if customPath.count >= 2 {
                // Remove the second-to-last page from customPath
                customPath.remove(at: customPath.count - 2)

                // Serialize the updated customPath
                let serialized = serializeCustomPath()

                // Reconstruct and assign the native path
                if let newPath = reconstructNavigationPath(from: serialized) {
                    path = newPath
                } else {
                    debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Failed to reconstruct NavigationPath")
                }
            } else {
                debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] No page before last to remove")
            }
        }

        _isInternalChange = false
    }
}
