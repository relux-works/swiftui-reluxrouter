import Relux
import SwiftUI

extension Relux.Navigation {
    public protocol ModalComponent: PathComponent, Identifiable, Sendable {}
}

extension Relux.Navigation.ModalComponent {
    public var id: Int { self.hashValue }
}

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, macCatalyst 17, *)
extension Relux.Navigation {
        /// A router dedicated to managing modal pages with a configurable maximum stack size.
    @Observable @MainActor
    public final class ModalRouter<Page>: Relux.Navigation.RouterProtocol, Observable
    where Page: ModalComponent {

            // MARK: - Configuration

            /// The maximum number of pages allowed in the stack at once
        public let maxDepth: Int

            // MARK: - Internal State

            /// The current modal pages, limited by maxPages.
        internal var modalPage: [Page] = []

            /// Stores the top page that was replaced when pushing beyond max pages.
        private var previouslyReplacedPage: Page?

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

            /// Creates a new instance of `ModalRouter` with configurable maximum stack size.
            ///
            /// The router manages a stack of modal pages with special handling when exceeding the maximum:
            /// - When pushing a page that would exceed limit:
            ///   1. The current top page is stored in memory
            ///   2. The new page takes its place
            ///   3. When this new page is removed, the stored page is automatically restored as top modal page
            ///
            /// - Parameter maxPages: The maximum number of simultaneously visible pages allowed in the stack.
            ///   Must be greater than 0. When this limit is exceeded, the top page is stored
            ///   and automatically restored when the exceeding page is removed.
        public init(maxPages: Int = 2) {
            precondition(maxPages > 0, "In Relux.Navigation.ModalRouter maxPages must be greater than 0")
            self.maxDepth = maxPages
            let pageTypeName = _typeName(Page.self, qualified: true)
            debugPrint("[Relux] [Navigation] [ModalRouter] ModalRouter   inited with page type: \(pageTypeName)")
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
                        // In Task to workaround a bug which prevents the push of new page
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
}
