import Combine
import Relux
import SwiftUI
import NavigationStackBackport

extension Relux.Navigation.ProjectingRouterBackport {
    public enum ProjectedPage: Equatable {
        case known(Page)
        case external
    }
}

extension Relux.Navigation {
    
    /// A router class that manages navigation state and synchronizes between a `NavigationStackBackport.NavigationPath` and a projected path.
    ///
    /// `ProjectingRouter` is designed to handle complex navigation scenarios, including programmatic navigation updates for other modules.
    ///
    /// - Type Parameters:
    ///   - Page: A type that conforms to both `PathComponent` and `Sendable`, representing the pages in the navigation stack.
    @MainActor
    @available(iOS 16, macOS 13, watchOS 9, tvOS 16, macCatalyst 16, *)
    public final class ProjectingRouterBackport<Page>: Relux.Navigation.RouterProtocol, ObservableObject
    where Page: PathComponent {
        
        private var pipelines: Set<AnyCancellable> = []
        
        /// The current navigation path.
        ///
        /// This property represents the actual navigation stack and is compatible with SwiftUI's navigation APIs.
        /// It is automatically updated when the projected path changes and vice versa.
        @Published public var path: NavigationStackBackport.NavigationPath
        
        /// A projection of the current path, including both known and external pages.
        ///
        /// This property provides a more detailed view of the navigation stack, including pages that may have been
        /// added through external means (e.g., system back button). It is automatically synchronized with `path`.
        public private(set) var pathProjection: [ProjectedPage] = []
        
        /// Initializes a new instance of `ProjectingRouter`.
        ///
        /// This initializer sets up the necessary pipelines to keep `path` and `pathProjection` synchronized.
        public init(pages: [Page] = []) {
            self.path = .init()
            if pages.isEmpty {
                internalReduce(with: .set(pages))
            }
            
            initPipelines()
            let pageTypeName = _typeName(Page.self, qualified: true)
            debugPrint("[Relux] [Navigation] [ProjectingRouter] ProjectingRouter   inited with page type: \(pageTypeName)")
        }
        
        deinit {
            let pageTypeName = _typeName(Page.self, qualified: true)
            debugPrint("[Relux] [Navigation] [ProjectingRouter] ProjectingRouter deinited with page type: \(pageTypeName)")
        }
        
        /// Resets the router to its initial state.
        ///
        /// This method clears both the `path` and `pathProjection`, effectively resetting the navigation stack.
        public func cleanup() async {
            pathProjection = []
            path = .init()
        }
        
        /// Handles incoming Relux actions to modify the navigation state.
        ///
        /// This method processes navigation actions and updates the router's state accordingly.
        /// It only responds to actions of type `Relux.Navigation.ProjectingRouter<Page>.Action`.
        ///
        /// - Parameter action: The Relux action to be processed.
        public func reduce(with action: any Relux.Action) async {
            switch action as? Relux.Navigation.ProjectingRouter<Page>.Action {
            case .none: break
            case let .some(action):
                internalReduce(with: action)
            }
        }
    }
}

@available(iOS 16, macOS 13, watchOS 9, tvOS 16, macCatalyst 16, *)
extension Relux.Navigation.ProjectingRouterBackport {
    
    @MainActor
    private func initPipelines() {
        setupPathToProjectionPipeline()
    }
    
    /// Sets up a Combine pipeline to synchronize the `path` with the `pathProjection`.
    ///
    /// This pipeline observes changes in the `path` and updates the `pathProjection` accordingly:
    /// - If the path grows, it adds `.external` pages to the projection.
    /// - If the path shrinks, it removes pages from the end of the projection.
    ///
    /// This ensures that the `pathProjection` always reflects the current state of the `path`,
    /// even when external navigation occurs (e.g., when a user taps the back button).
    private func setupPathToProjectionPipeline() {
        $path
        // .debounce(for: 0.1, scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] path in
                guard let self else { return }
                let pagesDiff = path.count - self.pathProjection.count
                
                switch pagesDiff {
                case 0:
                    // No change in path length, no action needed
                    break
                    
                case ..<0:
                    // Path has shrunk, remove pages from the end of the projection
                    self.pathProjection.removeLast(abs(pagesDiff))
                    
                default:
                    // Path has grown, add external pages to the projection
                    let newExternalPages = [ProjectedPage](repeating: .external, count: pagesDiff)
                    self.pathProjection.append(contentsOf: newExternalPages)
                }
            }
            .store(in: &pipelines)
    }
}

@available(iOS 16, macOS 13, watchOS 9, tvOS 16, macCatalyst 16, *)
extension Relux.Navigation.ProjectingRouterBackport {
    
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
                // If duplicates are allowed, simply append the new page to the projection
                self.pathProjection.append(.known(page))
                self.path.append(page)
                debugPrint(">>> router route path push \(page)")
                
            case false:
                // If duplicates are not allowed, check if the page already exists in the projection
                // And act accordingly
                if self.pathProjection.contains(.known(page)) {
                    return
                }
                self.pathProjection.append(.known(page))
                self.path.append(page)
                debugPrint(">>> router route path push \(page)")
            }
            
        case let .set(pages):
            // Handle setting an entirely new navigation stack
            // Convert the new pages to known projected pages
            
            let newPathProjection: [ProjectedPage] = pages.map { .known($0) }
            guard self.pathProjection != newPathProjection else {
                return
            }
            
            // Set the actual navigation path to the new pages
            self.pathProjection = pages.map { .known($0) }
            self.path = .init(pages)
            debugPrint(">>> router route path set \(pages)")
            
        case let .removeLast(count):
            // Handle removing pages from the end of the navigation stack
            // Calculate the actual number of items to remove, ensuring we don't remove more than exist
            let itemsCountToRemove = min(count, pathProjection.count)
            // Remove the calculated number of items from the projection
            self.pathProjection.removeLast(itemsCountToRemove)
            self.path.removeLast(itemsCountToRemove)
            debugPrint(">>> router route path remove \(count)")
        }
    }
}
