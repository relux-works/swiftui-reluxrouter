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
                    debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] External change: \(changeAmount) items \(changeAmount > 0 ? "popped" : "pushed")")
                    previousPathCount = path.count
                    if let key = userDefaultsKey {
                        saveNavigationPathToUserDefaults(forKey: key)
                    }
                    onSystemNavigationChange?(changeAmount)
                }
            }
        }
        
        @ObservationIgnored /*private*/ var _isInternalChange: Bool = false
        @ObservationIgnored private(set) var previousPathCount: Int = 0
        @ObservationIgnored private var onSystemNavigationChange: ((Int) -> Void)?
        private(set) var userDefaultsKey: String?
        
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
                   let savedPath = Self.decodePath(from: data, pageTypeName: pageTypeName) {
                    self.path = savedPath
                    self.previousPathCount = savedPath.count
                    debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Successfully restored path with \(savedPath.count) items")
                } else {
                    debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] No saved data or failed to decode for key: \(key), using empty path")
                }
            } else {
                debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] No UserDefaults key provided, using empty path")
            }
            
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Initialization complete with path count: \(self.path.count)")
        }
        
        deinit {
            let pageTypeName = _typeName(Page.self, qualified: true)
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Router deinited with page type: \(pageTypeName)")
        }
        
        public func setSystemNavigationHandler(_ callback: @escaping (Int) -> Void) {
            self.onSystemNavigationChange = callback
        }
        
        public func restore() async {
            path = .init()
        }
        
        public func cleanup() async {
            path = .init()
        }
        
        // Encoding and UserDefaults methods remain unchanged
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
