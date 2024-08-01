import Relux

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
			case let .push(page):
				// Appends a new page to the navigation path
				self.path.append(page)
				
			case let .set(pages):
				// Replaces the entire navigation path with a new set of pages
				self.path = .init(pages)
				
			case let .removeLast(count):
				// Removes a specified number of pages from the end of the navigation path
				let itemsCountToRemove = min(count, self.path.count)
				self.path.removeLast(itemsCountToRemove)
		}
	}
}
