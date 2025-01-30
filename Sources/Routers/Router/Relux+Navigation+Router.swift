import Combine
import Relux
import SwiftUI


extension Relux.Navigation {
	/// A lightweight, observable router class for managing navigation state in SwiftUI applications.
	///
	/// `Router` is designed to work with SwiftUI's navigation APIs and integrates with the Relux architecture.
	/// It provides a simple interface for managing navigation paths and handling navigation actions. For more complex scenarios
	/// that require observing the inner state of the path, consider using the ProjectingRouter.
	///
	/// - Type Parameters:
	///   - Page: A type that conforms to both `PathComponent` and `Sendable`, representing the pages in the navigation stack.
	@Observable @MainActor
	@available(iOS 17, macOS 14, watchOS 10, tvOS 17, macCatalyst 17, *)
    public final class Router<Page>: Relux.Navigation.RouterProtocol, Relux.TemporalState, Observable where Page: PathComponent, Page: Sendable {

		/// The current navigation path.
		///
		/// This property represents the actual navigation stack and is compatible with SwiftUI's navigation APIs.
		public var path: NavigationPath = .init()
		
		/// Initializes a new instance of `Router`.
		public init() { }
		
		/// Resets the router to its initial state.
		///
		/// This method clears the `path`, effectively resetting the navigation stack.
		/// - Note: This is an asynchronous operation.
		public func restore() async {
			path = .init()
		}
        
        public func cleanup() async {
            path = .init()
        }
	}
}

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, macCatalyst 17, *)
extension Relux.Navigation.Router {
	/// Handles incoming Relux actions to modify the navigation state.
	///
	/// This method processes navigation actions and updates the router's state accordingly.
	/// It only responds to actions of type `Relux.Navigation.Router<Page>.Action`.
	///
	/// - Parameter action: The Relux action to be processed.
	public func reduce(with action: any Relux.Action) async {
		switch action as? Relux.Navigation.Router<Page>.Action {
			case .none: break
			case let .some(action):
				internalReduce(with: action)
		}
	}
}
