import Relux

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, macCatalyst 17, *)
extension Relux.Navigation.RouterBackport {
    /// Represents actions that can be performed on the navigation stack.
    public enum Action: Relux.Action {
        /// Pushes a single page onto the navigation stack.
        ///
        /// - Parameter page: The page to be pushed onto the stack.
        case push(page: Page, disableAnimation: Bool = false)
        
        /// Sets the entire navigation stack to a new array of pages.
        ///
        /// - Parameter pages: The new array of pages that will replace the current navigation stack.
        case set(pages: [Page])
        
        /// Removes a specified number of pages from the end of the navigation stack.
        ///
        /// - Parameter count: The number of pages to remove from the end of the stack.
        ///   If this number is greater than the current stack size, it will remove all pages without causing an error.
        ///   Defaults to 1 if not specified.
        case removeLast(count: Int = 1)
        
        /// Removes the page before the last one in the navigation stack, if it exists.
        case removeBeforeLast
    }
}
