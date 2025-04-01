import Relux
import SwiftUI

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, macCatalyst 17, *)
extension Relux.Navigation {
    /// A router dedicated to managing modal pages with a configurable maximum stack size.
    @Observable @MainActor
    public final class ModalRouter<Page>: Relux.Navigation.RouterProtocol, Observable
    where Page: ModalCodableComponent {
        
        // MARK: - Configuration
        
        /// The maximum number of pages allowed in the stack at once
        public let maxDepth: Int
        
        /// Optional key for UserDefaults-based state restoration
        private let userDefaultsKey: String?
        
        // MARK: - Internal State
        
        /// The current modal pages, limited by maxPages.
        /// The current modal pages, limited by `maxDepth`.
        public var modalPage: [Page] = [] {
            didSet {
                // Whenever our modal page stack changes, we save to UserDefaults (if a key is set).
                if let key = userDefaultsKey {
                    saveModalStateToUserDefaults(forKey: key)
                }
            }
        }
        
        /// Stores the top page that was replaced when pushing beyond max pages.
        private var previouslyReplacedPage: Page? {
            didSet {
                // Persist whenever previouslyReplacedPage changes, too.
                if let key = userDefaultsKey {
                    saveModalStateToUserDefaults(forKey: key)
                }
            }
        }
        
        // MARK: - Subscript for SwiftUI Bindings
        
        /// A  subscript to bind a `Page?` by index in SwiftUI.
        ///
        /// If you dismiss via the Binding (i.e. with a gesture), it removes the page at that index and pages after it.
        public subscript(page index: Int) -> Binding<Page?> {
            Binding(
                get: { [weak self] in
                    self?.modalPage[safe: index]
                },
                set: { [weak self] _, _ in
                    self?.internalReduce(with: .removePages(fromIndex: index))
                }
            )
        }
        
        // MARK: - Initialization
        
        /// Creates a new instance of `ModalRouter` with configurable maximum stack size,
        /// and optional state restoration using `UserDefaults`.
        ///
        /// - Parameters:
        ///   - maxPages: The maximum number of simultaneously visible pages allowed in the stack.
        ///     Must be greater than 0. When this limit is exceeded, the top page is stored
        ///     and automatically restored when the exceeding page is removed.
        ///   - userDefaultsKey: An optional key in `UserDefaults` to use for persisting/restoring router state.
        ///     If omitted, state is not persisted.
        public init(maxPages: Int = 2, userDefaultsKey: String? = nil) {
            precondition(maxPages > 0, "In Relux.Navigation.ModalRouter maxPages must be greater than 0")
            self.maxDepth = maxPages
            self.userDefaultsKey = userDefaultsKey
            
            let pageTypeName = _typeName(Page.self, qualified: true)
            debugPrint("[Relux] [Navigation] [ModalRouter] ModalRouter   inited with page type: \(pageTypeName)")
            
            // Attempt to restore state from UserDefaults if a key is provided
            if let key = userDefaultsKey {
                debugPrint("[Relux] [Navigation] [ModalRouter] [\(pageTypeName)] Attempting to restore from UserDefaults key: \(key)")
                if restoreModalStateFromUserDefaults(forKey: key) {
                    debugPrint("[Relux] [Navigation] [ModalRouter] [\(pageTypeName)] Successfully restored modal state.")
                } else {
                    debugPrint("[Relux] [Navigation] [ModalRouter] [\(pageTypeName)] No saved state or failed decoding for key: \(key)")
                }
            }
        }
        
        deinit {
            let pageTypeName = _typeName(Page.self, qualified: true)
            debugPrint("[Relux] [Navigation] [ModalRouter] ModalRouter deinited with page type: \(pageTypeName)")
        }
        
        // MARK: - Relux.Navigation.RouterProtocol
        
        /// Restores (resets) the router to its initial state.
        /// Clears all modal pages and any remembered page.
        public func cleanup() async {
            modalPage = []
            previouslyReplacedPage = nil
        }
        
        /// Processes incoming Relux actions if they match this router's action type.
        /// - Parameter action: The Relux action to process.
        public func reduce(with action: any Relux.Action) async {
            guard let modalAction = action as? Action else { return }
            internalReduce(with: modalAction)
        }
    }
}

// MARK: - Actions

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, macCatalyst 17, *)
extension Relux.Navigation.ModalRouter {
    
    /// Actions that can manipulate the modal stack.
    public enum Action: Relux.Action {
        /// Pushes (appends) a new modal page. If already at max pages,
        /// we "swap out" the top one for the new page (and remember the old top).
        case pushModal(page: Page)
        
        /// Pops the top modal page (if any).
        case popModal
        
        /// Removes all modal pages starting from the provided index (inclusive).
        case removePages(fromIndex: Int)
        
        /// Dismisses *all* modal pages, but if there was a remembered page,
        /// we re-insert it after the dismissal.
        case dismissModal
    }
}
// MARK: - Internal Reduction

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, macCatalyst 17, *)
extension Relux.Navigation.ModalRouter {
    
    // MARK: - Internal Reduction
    
    /// Internal method that applies the given action to the router's state.
    @MainActor
    func internalReduce(with action: Relux.Navigation.ModalRouter<Page>.Action) {
        switch action {
            
        case let .pushModal(newPage):
            // If we're at max pages, we "swap out" the top page
            if modalPage.count >= maxDepth {
                // Remember the top page
                previouslyReplacedPage = modalPage.removeLast()
                
                // Push the new page with animation delay
                Task {
                    await MainActor.run {
                        modalPage.append(newPage)
                    }
                }
            } else {
                // Normal push within limits
                modalPage.append(newPage)
            }
            
        case .popModal:
            _ = modalPage.popLast()
            
        case let .removePages(fromIndex):
            guard fromIndex >= 0, fromIndex < modalPage.count else { return }
            modalPage.removeSubrange(fromIndex...)
            
            // Restore previously remembered page if any
            if let previouslyReplacedPage {
                modalPage.append(previouslyReplacedPage)
                self.previouslyReplacedPage = nil
            }
            
            // Clear previouslyReplacedPage if we're removing everything
            if fromIndex == 0 {
                previouslyReplacedPage = nil
            }
            
        case .dismissModal:
            // Dismiss everything
            modalPage = []
            
            // If there's a remembered page, bring it back
            if let oldPage = previouslyReplacedPage {
                modalPage.append(oldPage)
                previouslyReplacedPage = nil
            }
        }
    }
    
    // MARK: - State Restoration
    
    /// An internal struct holding our full state: the current modal stack and any replaced page.
    /// If you don’t need to restore `previouslyReplacedPage`, you can omit it.
    private struct ModalRouterState: Codable {
        let modalStack: [Page]
        let replacedPage: Page?
    }
    
    /// Saves the modal router state to `UserDefaults` for the specified key.
    @discardableResult
    private func saveModalStateToUserDefaults(forKey key: String) -> Bool {
        let state = ModalRouterState(modalStack: modalPage, replacedPage: previouslyReplacedPage)
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: key)
            debugPrint("[Relux] [Navigation] [ModalRouter] Saved modal state to UserDefaults with key: \(key)")
            return true
        } catch {
            debugPrint("[Relux] [Navigation] [ModalRouter] Failed to encode modal state: \(error)")
            return false
        }
    }
    
    /// Restores the modal router state from `UserDefaults` for the specified key.
    ///
    /// - Returns: `true` if restoration was successful, `false` otherwise.
    @discardableResult
    private func restoreModalStateFromUserDefaults(forKey key: String) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            debugPrint("[Relux] [Navigation] [ModalRouter] No data found in UserDefaults for key: \(key)")
            return false
        }
        do {
            let state = try JSONDecoder().decode(ModalRouterState.self, from: data)
            modalPage = state.modalStack
            previouslyReplacedPage = state.replacedPage
            debugPrint("[Relux] [Navigation] [ModalRouter] Restored modal state from UserDefaults with key: \(key). Stack size: \(modalPage.count)")
            return true
        } catch {
            debugPrint("[Relux] [Navigation] [ModalRouter] Failed to decode modal state: \(error)")
            return false
        }
    }
}
