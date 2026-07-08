import Relux
import SwiftUI

extension Relux.Navigation.ProjectingRouter {
    public enum ProjectedPage: Equatable {
        case known(Page)
        case external
    }
}

extension Relux.Navigation {

    /// A router class that manages navigation state and exposes a readable projection of a `NavigationPath`.
    ///
    /// `ProjectingRouter` is designed to handle complex navigation scenarios, including programmatic navigation updates for other modules.
    ///
    /// - Type Parameters:
    ///   - Page: A type that conforms to both `PathComponent` and `Sendable`, representing the pages in the navigation stack.
    @MainActor
    @available(iOS 16, macOS 13, watchOS 9, tvOS 16, macCatalyst 16, *)
    public final class ProjectingRouter<Page>: Relux.Navigation.RouterProtocol, ObservableObject
    where Page: PathComponent {

        /// The current navigation path.
        ///
        /// This property represents the actual navigation stack and is compatible with SwiftUI's navigation APIs.
        @Published public var path: NavigationPath

        /// A compatibility projection of the current path, including both known and external pages.
        ///
        /// This property provides a more detailed view of the navigation stack, including pages that may have been
        /// added through external means (e.g., system back button). It is derived from the actual `path` contents.
        public var pathProjection: [ProjectedPage] {
            NavigationPathProjector.values(in: path).map { value in
                if let page = value as? Page {
                    .known(page)
                } else {
                    .external
                }
            }
        }

        /// Readable projection of the actual `NavigationPath` contents.
        ///
        /// The projection is built from each path element's concrete dynamic type and mirrored payload. It does not
        /// require `Codable` and does not replace the concrete page types used by SwiftUI destination handlers.
        public var projectedPath: [Relux.Navigation.PathProjection] {
            NavigationPathProjector.projections(
                in: path,
                knownPageType: Page.self
            )
        }

        public var projectedPathStrings: [String] {
            projectedPath.map(\.description)
        }

        /// Initializes a new instance of `ProjectingRouter`.
        ///
        /// This initializer seeds the native path and immediately derives its projections.
        public init(pages: [Page] = []) {
            self.path = .init(pages)
            let pageTypeName = _typeName(Page.self, qualified: true)
            debugPrint("[Relux] [Navigation] [ProjectingRouter] ProjectingRouter   inited with page type: \(pageTypeName)")
        }

        deinit {
            let pageTypeName = _typeName(Page.self, qualified: true)
            debugPrint("[Relux] [Navigation] [ProjectingRouter] ProjectingRouter deinited with page type: \(pageTypeName)")
        }

        /// Resets the router to its initial state.
        ///
        /// This method clears the native path; projections are refreshed from the empty path.
        public func cleanup() async {
            path = .init()
        }

        /// Handles incoming Relux actions to modify the navigation state.
        ///
        /// This method processes navigation actions and updates the router's state accordingly.
        /// It only responds to actions of type `Relux.Navigation.ProjectingRouter<Page>.Action`.
        ///
        /// - Parameter action: The Relux action to be processed.
        public func reduce(with action: any Relux.Action) async {
            switch action {
            case let action as Relux.Navigation.ProjectingRouter<Page>.Action:
                internalReduce(with: action)
            case let action as Relux.Navigation.ProjectingRouterAction:
                internalReduce(with: action)
            default:
                break
            }
        }
    }
}

@available(iOS 16, macOS 13, watchOS 9, tvOS 16, macCatalyst 16, *)
extension Relux.Navigation.ProjectingRouter {

    /// Internal method to handle navigation actions and update the router's state accordingly.
    /// This method is responsible for maintaining consistency between `pathProjection` and `path`.
    ///
    /// - Parameter action: The navigation action to be processed.
    @MainActor
    func internalReduce(with action: Relux.Navigation.ProjectingRouter<Page>.Action) {
        switch action {
            case let .push(page, allowingDuplicates):

                // Handle pushing a new page onto the navigation stack
                switch allowingDuplicates {
                    case true:
                        self.path.append(page)
                        debugPrint(">>> router route path push \(page)")

                    case false:
                        if self.contains(page) {
                            return
                        }
                        self.path.append(page)
                        debugPrint(">>> router route path push \(page)")
                    }

            case let .set(pages):
                // Handle setting an entirely new navigation stack
                // Convert the new pages to known projected pages

                let newPathProjection = pages.map {
                    Self.projectedPathComponent(for: $0)
                }
                guard self.projectedPath != newPathProjection else {
                    return
                }

                // Set the actual navigation path to the new pages
                self.path = .init(pages)
                debugPrint(">>> router route path set \(pages)")

            case let .removeLast(count):
                // Handle removing pages from the end of the navigation stack
                // Calculate the actual number of items to remove, ensuring we don't remove more than exist
                let itemsCountToRemove = min(max(count, 0), path.count)
                self.path.removeLast(itemsCountToRemove)
                debugPrint(">>> router route path remove \(count)")
        }
    }

    @MainActor
    func internalReduce(with action: Relux.Navigation.ProjectingRouterAction) {
        switch action {
        case let .push(value, allowingDuplicates):
            if allowingDuplicates == false,
               projectedPath.contains(where: { $0.hasSameRouteIdentity(as: value.projection) }) {
                return
            }

            value.append(to: &path)
            debugPrint(">>> router route path push \(value)")
        }
    }
}

@available(iOS 16, macOS 13, watchOS 9, tvOS 16, macCatalyst 16, *)
extension Relux.Navigation.ProjectingRouter {
    public static func projectedPathComponent<Value>(
        for value: Value
    ) -> Relux.Navigation.PathProjection {
        NavigationPathProjector.projection(of: value, knownPageType: Page.self)
    }

    public static func projectedPathString<Value>(
        for value: Value
    ) -> String {
        projectedPathComponent(for: value).description
    }

    public func contains(_ page: Page) -> Bool {
        containsProjection(of: page)
    }

    public func containsProjection<Value>(of value: Value) -> Bool {
        let projection = Self.projectedPathComponent(for: value)
        return projectedPath.contains(projection)
    }

}
