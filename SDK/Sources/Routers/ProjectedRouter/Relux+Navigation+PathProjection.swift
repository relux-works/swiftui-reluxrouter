import Relux
import SwiftUI

extension Relux.Navigation {
    /// Optional override for values stored in a `NavigationPath`.
    ///
    /// This protocol is intentionally not a navigation destination type. It is
    /// used only by the projection layer to build readable fingerprints while
    /// keeping SwiftUI route handling bound to each module's concrete page type.
    public protocol PathProjectionRepresentable {
        var navigationPathProjectionDescription: String { get }
    }

    /// Read-only fingerprint for one concrete value inside a `NavigationPath`.
    ///
    /// Do not use this as a SwiftUI `navigationDestination` type. It exists only
    /// for inspection, duplicate checks, and tests.
    public struct PathProjection: Equatable, Hashable, Sendable, CustomStringConvertible {
        public let typeName: String
        public let valueDescription: String
        public let isKnownPageType: Bool

        public var description: String {
            "\(typeName)(\(valueDescription))"
        }

        public init(
            typeName: String,
            valueDescription: String,
            isKnownPageType: Bool
        ) {
            self.typeName = typeName
            self.valueDescription = valueDescription
            self.isKnownPageType = isKnownPageType
        }

        public func hasSameRouteIdentity(as other: Self) -> Bool {
            typeName == other.typeName && valueDescription == other.valueDescription
        }
    }
}

@available(iOS 16, macOS 13, watchOS 9, tvOS 16, macCatalyst 16, *)
extension Relux.Navigation {
    public struct AnyPathValue: @unchecked Sendable, CustomStringConvertible {
        public let projection: Relux.Navigation.PathProjection
        private let appendToPath: @MainActor @Sendable (inout NavigationPath) -> Void

        public var description: String {
            projection.description
        }

        public init<Value>(_ value: Value) where Value: Hashable, Value: Sendable {
            self.projection = NavigationPathProjector.projection(of: value, knownPageType: Never.self)
            self.appendToPath = { path in
                path.append(value)
            }
        }

        @MainActor
        func append(to path: inout NavigationPath) {
            appendToPath(&path)
        }
    }

    public enum ProjectingRouterAction: Relux.Action {
        case push(AnyPathValue, allowingDuplicates: Bool = false)
    }
}

@available(iOS 16, macOS 13, watchOS 9, tvOS 16, macCatalyst 16, *)
enum NavigationPathProjector {
    static func projections<Page>(
        in path: NavigationPath,
        knownPageType: Page.Type
    ) -> [Relux.Navigation.PathProjection] {
        values(in: path).map { value in
            projection(of: value, knownPageType: knownPageType)
        }
    }

    static func projection<Page>(
        of value: Any,
        knownPageType: Page.Type
    ) -> Relux.Navigation.PathProjection {
        let typeName = String(reflecting: Swift.type(of: value))
        let valueDescription: String

        if let projected = value as? any Relux.Navigation.PathProjectionRepresentable {
            valueDescription = projected.navigationPathProjectionDescription
        } else {
            var renderer = MirrorProjectionRenderer()
            valueDescription = renderer.render(value)
        }

        return .init(
            typeName: typeName,
            valueDescription: valueDescription,
            isKnownPageType: value is Page
        )
    }

    static func values(in path: NavigationPath) -> [Any] {
        var values: [Any] = []
        collectNavigationPathValues(from: path, into: &values)
        return values
    }

    private static func collectNavigationPathValues(from value: Any, into values: inout [Any]) {
        let mirror = Mirror(reflecting: value)
        let subjectType = String(reflecting: mirror.subjectType)

        if subjectType.contains("ItemBox<"),
           let base = mirror.children.first(where: { $0.label == "base" }) {
            values.append(base.value)
            return
        }

        for child in mirror.children {
            collectNavigationPathValues(from: child.value, into: &values)
        }
    }
}

private struct MirrorProjectionRenderer {
    private var visitedObjects: Set<ObjectIdentifier> = []

    mutating func render(_ value: Any) -> String {
        render(value, depth: 0, includeType: false)
    }

    private mutating func render(_ value: Any, depth: Int, includeType: Bool = true) -> String {
        guard depth < 16 else { return "<max-depth>" }

        let mirror = Mirror(reflecting: value)
        switch mirror.displayStyle {
        case .optional:
            guard let child = mirror.children.first else { return "nil" }
            return render(child.value, depth: depth + 1)

        case .enum:
            return renderEnum(value, mirror: mirror, depth: depth, includeType: includeType)

        case .struct:
            return renderStruct(value, mirror: mirror, depth: depth, includeType: includeType)

        case .tuple:
            return renderTuple(mirror, depth: depth)

        case .collection, .set:
            return "[" + mirror.children.map { render($0.value, depth: depth + 1) }.joined(separator: ", ") + "]"

        case .dictionary:
            return "[" + mirror.children.map { render($0.value, depth: depth + 1) }.joined(separator: ", ") + "]"

        case .class:
            return renderClass(value, mirror: mirror, depth: depth, includeType: includeType)

        default:
            return leafDescription(value)
        }
    }

    private mutating func renderEnum(_ value: Any, mirror: Mirror, depth: Int, includeType: Bool) -> String {
        let typeName = String(reflecting: Swift.type(of: value))
        let prefix = includeType ? "\(typeName)" : ""
        guard let child = mirror.children.first else {
            let reflected = String(reflecting: value)
            let qualifiedPrefix = "\(typeName)."
            if !includeType, reflected.hasPrefix(qualifiedPrefix) {
                return ".\(reflected.dropFirst(qualifiedPrefix.count))"
            }
            return reflected
        }

        let payload = render(child.value, depth: depth + 1)
        if payload.hasPrefix("("), payload.hasSuffix(")") {
            return "\(prefix).\(child.label ?? "_")\(payload)"
        }
        return "\(prefix).\(child.label ?? "_")(\(payload))"
    }

    private mutating func renderStruct(_ value: Any, mirror: Mirror, depth: Int, includeType: Bool) -> String {
        guard !mirror.children.isEmpty else {
            return leafDescription(value)
        }

        let typeName = String(reflecting: Swift.type(of: value))
        let fields = mirror.children.map { child in
            let label = child.label.map { "\($0): " } ?? ""
            return "\(label)\(render(child.value, depth: depth + 1))"
        }
        let payload = "(\(fields.joined(separator: ", ")))"
        return includeType ? "\(typeName)\(payload)" : payload
    }

    private mutating func renderTuple(_ mirror: Mirror, depth: Int) -> String {
        let values = mirror.children.map { child in
            let label = child.label.map { "\($0): " } ?? ""
            return "\(label)\(render(child.value, depth: depth + 1))"
        }
        return "(\(values.joined(separator: ", ")))"
    }

    private mutating func renderClass(_ value: Any, mirror: Mirror, depth: Int, includeType: Bool) -> String {
        let object = value as AnyObject
        let id = ObjectIdentifier(object)
        guard visitedObjects.insert(id).inserted else {
            return "<cycle:\(String(reflecting: mirror.subjectType))>"
        }
        defer { visitedObjects.remove(id) }

        guard !mirror.children.isEmpty else {
            return String(reflecting: mirror.subjectType)
        }

        let fields = mirror.children.map { child in
            let label = child.label.map { "\($0): " } ?? ""
            return "\(label)\(render(child.value, depth: depth + 1))"
        }
        let payload = "(\(fields.joined(separator: ", ")))"
        return includeType ? "\(String(reflecting: mirror.subjectType))\(payload)" : payload
    }

    private func leafDescription(_ value: Any) -> String {
        switch value {
        case let string as String:
            return String(reflecting: string)
        case let character as Character:
            return String(reflecting: character)
        default:
            return String(reflecting: value)
        }
    }
}
