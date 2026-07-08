import Relux
import SwiftUI

extension Relux {
    /// A SwiftUI control that pushes a `ProjectingRouter` page through Relux actions.
    ///
    /// Specialize this type per module with a typealias when local page types should
    /// stay hidden behind module boundaries:
    ///
    /// ```swift
    /// typealias CatalogNavigationLink<Label: View> =
    ///     Relux.NavigationLink<Catalog.UI.Page, Label>
    /// ```
    @MainActor
    public struct NavigationLink<Page, Label>: View
    where Page: Hashable, Page: Sendable, Label: View {
        private let page: Page
        private let allowingDuplicates: Bool
        private let onNavigated: (@Sendable () async -> Void)?
        @ViewBuilder private let label: () -> Label

        @State private var isNavigating = false

        public init(
            page: Page,
            allowingDuplicates: Bool = false,
            onNavigated: (@Sendable () async -> Void)? = nil,
            @ViewBuilder label: @escaping () -> Label
        ) {
            self.page = page
            self.allowingDuplicates = allowingDuplicates
            self.onNavigated = onNavigated
            self.label = label
        }

        public var body: some View {
            Button(action: navigate) {
                label()
            }
            .disabled(isNavigating)
        }

        private func navigate() {
            guard isNavigating == false else { return }

            isNavigating = true
            let page = page
            let allowingDuplicates = allowingDuplicates
            let onNavigated = onNavigated

            Task { @MainActor in
                await action {
                    Relux.Navigation.ProjectingRouterAction.push(
                        .init(page),
                        allowingDuplicates: allowingDuplicates
                    )
                }
                await onNavigated?()
                isNavigating = false
            }
        }
    }
}
