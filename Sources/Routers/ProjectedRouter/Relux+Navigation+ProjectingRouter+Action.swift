import Relux

@available(iOS 16, macOS 13, watchOS 9, tvOS 16, macCatalyst 16, *)
extension Relux.Navigation.ProjectingRouter {
    /// Represents actions that can be performed on the navigation stack.
    public enum Action: Relux.Action {
        /// Pushes a single page onto the navigation stack.
        ///
        /// - Parameters:
        ///   - Page: The page to be pushed onto the stack.
        ///   - allowingDuplicates: A boolean flag indicating whether duplicate pages are allowed in the stack.
        ///     If `false`, the page won't be pushed if it already exists in the stack.
        case push(page: Page, allowingDuplicates: Bool = false)

        /// Sets the entire navigation stack to a new array of pages.
        ///
        /// - Parameter [Page]: The new array of pages that will replace the current navigation stack.
        case set([Page])

        /// Removes a specified number of pages from the end of the navigation stack.
        ///
        /// - Parameter Int: The number of pages to remove from the end of the stack.
        ///   If this number is greater than the current stack size, it will remove all pages without causing an error.
        case removeLast(Int = 1)
    }
}
