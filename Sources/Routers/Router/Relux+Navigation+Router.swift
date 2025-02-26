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
		public var path: NavigationPath
        
        /// The UserDefaults key used for storing and retrieving the navigation path.
        private(set) var userDefaultsKey: String?
        
        /// Initializes a new instance of `Router`.
        ///
        /// - Parameter userDefaultsKey: An optional key for storing/retrieving the navigation path in UserDefaults.
        ///   If provided, the router will attempt to restore a previously saved path during initialization.
        ///   If the key is nil or no saved path is found, a new empty path will be created.
        public init(userDefaultsKey: String?) {
            let pageTypeName = _typeName(Page.self, qualified: true)
            self.userDefaultsKey = userDefaultsKey
            
            // Start with default empty path
            self.path = .init()
            
            // Log initialization start
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Initializing")
            
            // Handle UserDefaults restoration if key is provided
            switch userDefaultsKey {
            case .none:
                debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] No UserDefaults key provided, using empty path")
                
            case .some(let key):
                debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] UserDefaults key provided: \(key)")
                
                // Try to load data from UserDefaults
                if let data = Self.loadDataFromUserDefaults(forKey: key) {
                    debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Found saved data for key: \(key)")
                    
                    // Try to decode the data into a NavigationPath
                    if let savedPath = Self.decodePath(from: data) {
                        self.path = savedPath
                        debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Successfully restored path with \(savedPath.count) items")
                    } else {
                        debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Failed to decode saved data, using empty path")
                    }
                } else {
                    debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] No saved data found for key: \(key), using empty path")
                }
            }
            
            // Log initialization completion
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Initialization complete with path count: \(self.path.count)")
        }
        
        deinit {
            let pageTypeName = _typeName(Page.self, qualified: true)
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Router deinited with page type: \(pageTypeName)")
        }
		
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

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, macCatalyst 17, *)
extension Relux.Navigation.Router {
    /// Encodes a navigation path to a serializable format
    ///
    /// This pure function returns a Data object containing the encoded navigation path, which
    /// can be used for state persistence or deep linking.
    ///
    /// - Parameters:
    ///   - path: The NavigationPath to encode
    ///   - prettyPrint: Whether to format the JSON with indentation for readability (default: false)
    ///   - pageTypeName: The name of the page type for logging purposes
    /// - Returns: A Data object containing the encoded path, or nil if any element in the path
    ///   doesn't conform to Codable or if encoding fails
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
            
            // Print the encoded path as a JSON string for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                let shortJson = jsonString.count > 500
                ? "\(jsonString.prefix(500))... (truncated, \(jsonString.count) chars total)"
                : jsonString
                debugPrint("[Relux] [Navigation] [Router]\(typeInfo) Encoded navigation path with \(path.count) items: \(shortJson)")
            }
            
            return data
        } catch {
            debugPrint("[Relux] [Navigation] [Router]\(typeInfo) Failed to encode navigation path: \(error)")
            return nil
        }
    }
    
    /// Decodes a navigation path from a serializable format
    ///
    /// This pure function attempts to decode a NavigationPath from the provided Data object.
    ///
    /// - Parameters:
    ///   - data: A Data object containing an encoded navigation path
    ///   - pageTypeName: The name of the page type for logging purposes
    /// - Returns: A decoded NavigationPath if successful, nil otherwise
    public static func decodePath(from data: Data, pageTypeName: String = "") -> NavigationPath? {
        let typeInfo = pageTypeName.isEmpty ? "" : " [\(pageTypeName)]"
        
        // Print the input data as a JSON string for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            let shortJson = jsonString.count > 500
            ? "\(jsonString.prefix(500))... (truncated, \(jsonString.count) chars total)"
            : jsonString
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
    
    /// Loads data from UserDefaults
    ///
    /// This pure function attempts to load data from UserDefaults using the provided key.
    ///
    /// - Parameters:
    ///   - key: The key used when the data was stored in UserDefaults
    ///   - pageTypeName: The name of the page type for logging purposes
    /// - Returns: The Data object if found, nil otherwise
    public static func loadDataFromUserDefaults(forKey key: String, pageTypeName: String = "") -> Data? {
        let typeInfo = pageTypeName.isEmpty ? "" : " [\(pageTypeName)]"
        
        guard let data = UserDefaults.standard.data(forKey: key) else {
            debugPrint("[Relux] [Navigation] [Router]\(typeInfo) No saved data found for key: \(key)")
            return nil
        }
        
        debugPrint("[Relux] [Navigation] [Router]\(pageTypeName) Successfully loaded data from UserDefaults with key: \(key) (size: \(data.count) bytes)")
        return data
    }
    
    /// Saves data to UserDefaults
    ///
    /// This pure function saves the provided data to UserDefaults using the specified key.
    ///
    /// - Parameters:
    ///   - data: The Data object to save
    ///   - key: The key to use when storing the data in UserDefaults
    ///   - pageTypeName: The name of the page type for logging purposes
    /// - Returns: A boolean indicating whether the operation was successful
    @discardableResult
    public static func saveDataToUserDefaults(_ data: Data, forKey key: String, pageTypeName: String = "") -> Bool {
        let typeInfo = pageTypeName.isEmpty ? "" : " [\(pageTypeName)]"
        
        UserDefaults.standard.set(data, forKey: key)
        debugPrint("[Relux] [Navigation] [Router]\(typeInfo) Successfully saved data to UserDefaults with key: \(key) (size: \(data.count) bytes)")
        return true
    }
    
    /// Encodes the current navigation path to a serializable format
    ///
    /// This method uses the pure function `encodePath` to encode the current navigation path.
    ///
    /// - Parameter prettyPrint: Whether to format the JSON with indentation for readability (default: false)
    /// - Returns: A Data object containing the encoded path, or nil if any element in the path
    ///   doesn't conform to Codable or if encoding fails
    public func encodeNavigationPath(prettyPrint: Bool = false) -> Data? {
        let pageTypeName = _typeName(Page.self, qualified: true)
        return Self.encodePath(path, prettyPrint: prettyPrint, pageTypeName: pageTypeName)
    }
    
    /// Decodes and sets the navigation path from a serializable format
    ///
    /// This method uses the pure function `decodePath` to decode a navigation path,
    /// then updates the router's path if decoding is successful.
    ///
    /// - Parameter data: A Data object containing an encoded navigation path
    /// - Returns: A boolean indicating whether the decoding was successful
    @discardableResult
    public func decodeNavigationPath(from data: Data) -> Bool {
        let pageTypeName = _typeName(Page.self, qualified: true)
        guard let decodedPath = Self.decodePath(from: data, pageTypeName: pageTypeName) else {
            return false
        }
        
        self.path = decodedPath
        return true
    }
    
    /// Saves the current navigation path state to UserDefaults
    ///
    /// This method uses pure functions to encode the path and save it to UserDefaults.
    ///
    /// - Parameters:
    ///   - key: The key to use when storing the navigation path in UserDefaults
    ///   - prettyPrint: Whether to format the JSON with indentation for debugging (default: false)
    /// - Returns: A boolean indicating whether the operation was successful
    @discardableResult
    public func saveNavigationPathToUserDefaults(forKey key: String, prettyPrint: Bool = false) -> Bool {
        let pageTypeName = _typeName(Page.self, qualified: true)
        debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Saving navigation path to UserDefaults with key: \(key)")
        
        guard let data = Self.encodePath(path, prettyPrint: prettyPrint, pageTypeName: pageTypeName) else {
            debugPrint("[Relux] [Navigation] [Router] [\(pageTypeName)] Failed to encode navigation path for saving to UserDefaults")
            return false
        }
        
        return Self.saveDataToUserDefaults(data, forKey: key, pageTypeName: pageTypeName)
    }
    
    /// Restores the navigation path state from UserDefaults
    ///
    /// This method uses pure functions to load data from UserDefaults and decode it into a navigation path.
    ///
    /// - Parameter key: The key used when the navigation path was stored in UserDefaults
    /// - Returns: A boolean indicating whether the operation was successful
    @discardableResult
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
