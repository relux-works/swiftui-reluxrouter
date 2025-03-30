import Combine
import Relux
import SwiftUI

extension Relux.Navigation {
    public protocol CodablePathComponent: PathComponent, Codable {}
}

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
    public final class CodableProjectedRouter<Page>: Relux.Navigation.RouterProtocol, Observable
    where Page: CodablePathComponent {

        /// The current navigation path.
        public var path: NavigationPath {
            didSet {
                let pageTypeName = _typeName(Page.self, qualified: true)
                if _isInternalChange {
                    debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Internal change: \(previousPathCount) -> \(path.count)")
                    previousPathCount = path.count
                    if let key = userDefaultsKey {
                        saveNavigationPathToUserDefaults(forKey: key)
                    }
                } else if previousPathCount != path.count {
                    let changeAmount = previousPathCount - path.count
                    debugPrint(
                        "[Relux] [Navigation] [Router] [\(pageTypeName)] External change: \(changeAmount) items \(changeAmount > 0 ? "popped" : "pushed")")
                    previousPathCount = path.count
                    if let key = userDefaultsKey {
                        saveNavigationPathToUserDefaults(forKey: key)
                    }
                    onSystemNavigationChange?(changeAmount)
                }
                updateCustomPath()  // Update customPath after any change
            }
        }

        /// The custom path holding the deserialized array of pages.
        public var customPath: [Page] = []

        @ObservationIgnored /*private*/ var _isInternalChange: Bool = false
        @ObservationIgnored private(set) var previousPathCount: Int = 0
        @ObservationIgnored private var onSystemNavigationChange: ((Int) -> Void)?
        private(set) var userDefaultsKey: String?

        // MARK: - Initialization

        public init(
            userDefaultsKey: String? = nil,
            onSystemNavigationChange: ((Int) -> Void)? = nil
        ) {
            let pageTypeName = _typeName(Page.self, qualified: true)
            self.userDefaultsKey = userDefaultsKey
            self.onSystemNavigationChange = onSystemNavigationChange
            self.path = .init()
            self.previousPathCount = 0

            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Initializing")

            if let key = userDefaultsKey {
                debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] UserDefaults key provided: \(key)")
                if let data = Self.loadDataFromUserDefaults(forKey: key, pageTypeName: pageTypeName),
                    let savedPath = Self.decodePath(from: data, pageTypeName: pageTypeName)
                {
                    self.path = savedPath
                    self.previousPathCount = savedPath.count
                    debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Successfully restored path with \(savedPath.count) items")
                } else {
                    debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] No saved data or failed to decode for key: \(key), using empty path")
                }
            } else {
                debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] No UserDefaults key provided, using empty path")
            }

            updateCustomPath()  // Set initial customPath
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Initialization complete with path count: \(self.path.count)")
        }

        deinit {
            let pageTypeName = _typeName(Page.self, qualified: true)
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Router deinited with page type: \(pageTypeName)")
        }

        private func updateCustomPath() {
            let pageTypeName = _typeName(Page.self, qualified: true)
            if let codable = path.codable {
                do {
                    // Encode the codable representation to Data
                    let data = try JSONEncoder().encode(codable)
                    // Decode it as an array of strings
                    let elements = try JSONDecoder().decode([String].self, from: data)

                    // Ensure the array has an even number of elements (type name + JSON string pairs)
                    guard elements.count % 2 == 0 else {
                        throw DecodingError.dataCorrupted(
                            DecodingError.Context(
                                codingPath: [],
                                debugDescription: "Expected even number of elements in path array"
                            ))
                    }

                    var pages: [Page] = []
                    let expectedTypeName = String(reflecting: Page.self)  // e.g., "Module.UI.Dashboard.Navigation.Page"

                    // Process the array in pairs
                    for i in stride(from: 0, to: elements.count, by: 2) {
                        let typeName = elements[i]
                        let jsonString = elements[i + 1]

                        // Verify the type name matches the expected Page type
                        guard typeName == expectedTypeName else {
                            throw DecodingError.typeMismatch(
                                Page.self,
                                DecodingError.Context(
                                    codingPath: [],
                                    debugDescription: "Type mismatch: expected \(expectedTypeName), got \(typeName)"
                                )
                            )
                        }

                        // Convert the JSON string to Data
                        guard let jsonData = jsonString.data(using: .utf8) else {
                            throw DecodingError.dataCorrupted(
                                DecodingError.Context(
                                    codingPath: [],
                                    debugDescription: "Invalid JSON string: \(jsonString)"
                                ))
                        }

                        // Decode the Page object
                        let page = try JSONDecoder().decode(Page.self, from: jsonData)
                        pages.append(page)
                    }

                    // Reverse the pages to match the intended navigation stack order (root to top)
                    customPath = pages.reversed()
                    debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Updated customPath with \(customPath.count) items")
                } catch {
                    debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Failed to decode custom path: \(error)")
                    customPath = []
                }
            } else {
                customPath = []
                debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Path is not codable, set customPath to empty")
            }
        }

        // MARK: - Serialization of Custom Path

        /// Serializes the custom path into the same format as the native NavigationPath's codable representation.
        func serializeCustomPath() -> [String] {
            var serialized: [String] = []
            let typeName = String(reflecting: Page.self)  // Fully qualified type name

            do {
                for page in customPath {
                    let jsonData = try JSONEncoder().encode(page)
                    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                        debugPrint("[Relux] [Navigation] [Router] Failed to convert JSON data to string")
                        return []
                    }
                    serialized.append(typeName)
                    serialized.append(jsonString)
                }
            } catch {
                debugPrint("[Relux] [Navigation] [Router] Failed to serialize customPath: \(error)")
                return []
            }

            return serialized
        }

        /// Reconstructs a NavigationPath from a serialized array of strings.
        func reconstructNavigationPath(from serialized: [String]) -> NavigationPath? {
            let pageTypeName = _typeName(Page.self, qualified: true)

            do {
                debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Starting reconstruction of NavigationPath from serialized array: \(serialized)")

                // Encode the serialized array into Data
                debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Encoding serialized array into Data")
                let data = try JSONEncoder().encode(serialized)
                debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Encoded data: \(String(data: data, encoding: .utf8) ?? "nil")")

                // Decode into NavigationPath.CodableRepresentation
                debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Decoding data into CodableRepresentation")
                let codableRepresentation = try JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: data)
                debugPrint("[Relux] [Navigation] [Router] \(pageTypeName) Decoded CodableRepresentation: \(codableRepresentation)")

                // Create a new NavigationPath
                debugPrint(
                    "[Relux] [Navigation] [Router] [\(pageTypeName)] Successfully created new NavigationPath with \(NavigationPath(codableRepresentation).count) items"
                )
                return NavigationPath(codableRepresentation)
            } catch {
                debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Failed to reconstruct NavigationPath: \(error)")
                return nil
            }
        }

        // MARK: - Applying Custom Path to Native Path

        /// Applies the custom path to the native path.
        public func applyCustomPath() {
            path = NavigationPath.init(customPath)
            debugPrint("[Relux] [Navigation] [Router] Applied customPath to native path")
        }

        public func setSystemNavigationHandler(_ callback: @escaping (Int) -> Void) {
            self.onSystemNavigationChange = callback
        }

        public func cleanup() async {
            path = .init()
        }

        public static func encodePath(_ path: NavigationPath, prettyPrint: Bool = false, pageTypeName: String = "") -> Data? {
            let typeInfo = pageTypeName.isEmpty ? "" : " [\(pageTypeName)]"
            guard let codableRepresentation = path.codable else {
                debugPrint("[Relux] [Navigation] [Router]\(typeInfo) Failed to get codable representation: path contains non-Codable elements")
                return nil
            }
            do {
                let encoder = JSONEncoder()
                if prettyPrint {
                    encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
                }
                let data = try encoder.encode(codableRepresentation)
                if let jsonString = String(data: data, encoding: .utf8) {
                    let shortJson = jsonString.count > 500 ? "\(jsonString.prefix(500))... (truncated, \(jsonString.count) chars total)" : jsonString
                    debugPrint("[Relux] [Navigation] [Router]\(typeInfo) Encoded navigation path with \(path.count) items: \(shortJson)")
                }
                return data
            } catch {
                debugPrint("[Relux] [Navigation] [Router]\(typeInfo) Failed to encode navigation path: \(error)")
                return nil
            }
        }

        public static func decodePath(from data: Data, pageTypeName: String = "") -> NavigationPath? {
            let typeInfo = pageTypeName.isEmpty ? "" : " [\(pageTypeName)]"
            if let jsonString = String(data: data, encoding: .utf8) {
                let shortJson = jsonString.count > 500 ? "\(jsonString.prefix(500))... (truncated, \(jsonString.count) chars total)" : jsonString
                debugPrint("[Relux] [Navigation] [Router]\(typeInfo) Decoding navigation path from: \(shortJson)")
            }
            do {
                let decoder = JSONDecoder()
                let codableRepresentation = try decoder.decode(NavigationPath.CodableRepresentation.self, from: data)
                let decodedPath = NavigationPath(codableRepresentation)
                debugPrint("[Relux] [Navigation] [Router]\(typeInfo) Successfully decoded navigation path with \(decodedPath.count) items")
                return decodedPath
            } catch {
                debugPrint("[Relux] [Navigation] [Router]\(typeInfo) Failed to decode navigation path: \(error)")
                return nil
            }
        }

        public static func loadDataFromUserDefaults(forKey key: String, pageTypeName: String = "") -> Data? {
            let typeInfo = pageTypeName.isEmpty ? "" : " [\(pageTypeName)]"
            guard let data = UserDefaults.standard.data(forKey: key) else {
                debugPrint("[Relux] [Navigation] [Router]\(typeInfo) No saved data found for key: \(key)")
                return nil
            }
            debugPrint("[Relux] [Navigation] [Router]\(pageTypeName) Successfully loaded data from UserDefaults with key: \(key) (size: \(data.count) bytes)")
            return data
        }

        public static func saveDataToUserDefaults(_ data: Data, forKey key: String, pageTypeName: String = "") -> Bool {
            let typeInfo = pageTypeName.isEmpty ? "" : " [\(pageTypeName)]"
            UserDefaults.standard.set(data, forKey: key)
            debugPrint("[Relux] [Navigation] [Router]\(typeInfo) Successfully saved data to UserDefaults with key: \(key) (size: \(data.count) bytes)")
            return true
        }

        public func encodeNavigationPath(prettyPrint: Bool = false) -> Data? {
            let pageTypeName = _typeName(Page.self, qualified: true)
            return Self.encodePath(path, prettyPrint: prettyPrint, pageTypeName: pageTypeName)
        }

        public func decodeNavigationPath(from data: Data) -> Bool {
            let pageTypeName = _typeName(Page.self, qualified: true)
            guard let decodedPath = Self.decodePath(from: data, pageTypeName: pageTypeName) else {
                return false
            }
            self.path = decodedPath
            return true
        }

        public func saveNavigationPathToUserDefaults(forKey key: String, prettyPrint: Bool = false) -> Bool {
            let pageTypeName = _typeName(Page.self, qualified: true)
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Saving navigation path to UserDefaults with key: \(key)")
            guard let data = Self.encodePath(path, prettyPrint: prettyPrint, pageTypeName: pageTypeName) else {
                debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Failed to encode navigation path for saving to UserDefaults")
                return false
            }
            return Self.saveDataToUserDefaults(data, forKey: key, pageTypeName: pageTypeName)
        }

        public func restoreNavigationPathFromUserDefaults(forKey key: String) -> Bool {
            let pageTypeName = _typeName(Page.self, qualified: true)
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Attempting to restore navigation path from UserDefaults with key: \(key)")
            guard let data = Self.loadDataFromUserDefaults(forKey: key, pageTypeName: pageTypeName) else {
                debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] No data found for key: \(key)")
                return false
            }
            guard let decodedPath = Self.decodePath(from: data, pageTypeName: pageTypeName) else {
                debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Failed to decode data from key: \(key)")
                return false
            }
            self.path = decodedPath
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Successfully restored navigation path with \(decodedPath.count) items")
            return true
        }
    }
}

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, macCatalyst 17, *)
extension Relux.Navigation.CodableProjectedRouter {
    /// Handles incoming Relux actions to modify the navigation state.
    ///
    /// This method processes navigation actions and updates the router's state accordingly.
    /// It only responds to actions of type `Relux.Navigation.Router<Page>.Action`.
    ///
    /// - Parameter action: The Relux action to be processed.
    public func reduce(with action: any Relux.Action) async {
        switch action as? Relux.Navigation.CodableProjectedRouter<Page>.Action {
        case .none: break
        case let .some(action):
            internalReduce(with: action)
        }
    }
}
