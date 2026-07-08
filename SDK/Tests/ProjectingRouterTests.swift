import Relux
@testable import ReluxRouter
import SwiftUI
import Testing

@Suite("ProjectingRouter projection")
@MainActor
struct ProjectingRouterTests {
    @Test("initial pages are applied and projected")
    func initialPagesAreAppliedAndProjected() {
        let router = Relux.Navigation.ProjectingRouter<TestPage>(pages: [.details(id: 42)])

        #expect(router.path.count == 1)
        #expect(router.pathProjection == [.known(.details(id: 42))])
        #expect(router.projectedPathStrings.count == 1)
        #expect(router.projectedPathStrings[0].contains("details"))
        #expect(router.projectedPathStrings[0].contains("42"))
    }

    @Test("native same-type pages are projected as known and participate in duplicate checks")
    func nativeSameTypePagesAreProjectedAsKnown() async {
        let router = Relux.Navigation.ProjectingRouter<TestPage>()

        router.path.append(TestPage.details(id: 7))

        #expect(router.pathProjection == [.known(.details(id: 7))])
        #expect(router.contains(.details(id: 7)))

        await router.reduce(with: Relux.Navigation.ProjectingRouter<TestPage>.Action.push(.details(id: 7)))

        #expect(router.path.count == 1)
        #expect(router.pathProjection == [.known(.details(id: 7))])
    }

    @Test("external non-Codable pages keep type and parameters in string projection")
    func externalNonCodablePagesKeepReadableProjection() {
        let router = Relux.Navigation.ProjectingRouter<TestPage>()
        let external = ExternalPage(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            label: "native-link"
        )

        router.path.append(external)

        #expect(router.path.codable == nil)
        #expect(router.pathProjection == [.external])
        #expect(router.containsProjection(of: external))
        #expect(router.projectedPathStrings.count == 1)
        #expect(router.projectedPathStrings[0].contains("ExternalPage"))
        #expect(router.projectedPathStrings[0].contains("native-link"))
        #expect(router.projectedPathStrings[0].contains("11111111-2222-3333-4444-555555555555"))
    }

    @Test("mixed Relux and external pages are projected from actual NavigationPath contents")
    func mixedPagesAreProjectedFromActualPath() async {
        let router = Relux.Navigation.ProjectingRouter<TestPage>()
        let external = ExternalPage(
            id: UUID(uuidString: "22222222-3333-4444-5555-666666666666")!,
            label: "native"
        )

        await router.reduce(with: Relux.Navigation.ProjectingRouter<TestPage>.Action.push(.details(id: 1)))
        router.path.append(external)
        router.path.append(TestPage.profile(name: "external-same-type"))

        #expect(router.path.count == 3)
        #expect(router.pathProjection == [
            .known(.details(id: 1)),
            .external,
            .known(.profile(name: "external-same-type")),
        ])
        #expect(router.projectedPathStrings[0].contains("details"))
        #expect(router.projectedPathStrings[1].contains("ExternalPage"))
        #expect(router.projectedPathStrings[2].contains("external-same-type"))
    }

    @Test("projection updates when native back navigation removes pages")
    func projectionUpdatesWhenPathShrinks() async {
        let router = Relux.Navigation.ProjectingRouter<TestPage>()

        await router.reduce(with: Relux.Navigation.ProjectingRouter<TestPage>.Action.push(.details(id: 1)))
        router.path.append(ExternalPage(
            id: UUID(uuidString: "33333333-4444-5555-6666-777777777777")!,
            label: "native"
        ))
        router.path.append(SecondaryExternalPage(section: "settings", itemID: 9))

        router.path.removeLast()

        #expect(router.path.count == 2)
        #expect(router.pathProjection == [
            .known(.details(id: 1)),
            .external,
        ])
        #expect(router.projectedPathStrings.count == 2)
        #expect(router.projectedPathStrings[0].contains("details"))
        #expect(router.projectedPathStrings[1].contains("native"))
    }

    @Test("different external concrete page types do not need a shared destination wrapper")
    func differentExternalPageTypesDoNotNeedSharedWrapper() {
        let router = Relux.Navigation.ProjectingRouter<TestPage>()

        router.path.append(ExternalPage(
            id: UUID(uuidString: "44444444-5555-6666-7777-888888888888")!,
            label: "module-a"
        ))
        router.path.append(SecondaryExternalPage(section: "module-b", itemID: 11))
        router.path.append(CallbackPage(id: 12, callback: CallbackBox {}))

        #expect(router.path.codable == nil)
        #expect(router.pathProjection == [.external, .external, .external])
        #expect(router.projectedPathStrings[0].contains("ExternalPage"))
        #expect(router.projectedPathStrings[1].contains("SecondaryExternalPage"))
        #expect(router.projectedPathStrings[1].contains("module-b"))
        #expect(router.projectedPathStrings[2].contains("CallbackPage"))
        #expect(router.projectedPathStrings[2].contains("12"))
    }

    @Test("parameters are part of the projection")
    func parametersArePartOfProjection() {
        let first = Relux.Navigation.ProjectingRouter<TestPage>.projectedPathString(for: TestPage.details(id: 1))
        let second = Relux.Navigation.ProjectingRouter<TestPage>.projectedPathString(for: TestPage.details(id: 2))

        #expect(first != second)
        #expect(first.contains("1"))
        #expect(second.contains("2"))
    }

    @Test("custom projection protocol overrides reflected payload only")
    func customProjectionProtocolOverridesPayloadOnly() {
        let router = Relux.Navigation.ProjectingRouter<TestPage>()
        let external = CustomProjectedExternalPage(routeID: "module-a/details/15")

        router.path.append(external)

        #expect(router.projectedPathStrings.count == 1)
        #expect(router.projectedPathStrings[0].contains("CustomProjectedExternalPage"))
        #expect(router.projectedPathStrings[0].contains("module-a/details/15"))
    }
}

private enum TestPage: Relux.Navigation.PathComponent {
    case details(id: Int)
    case profile(name: String)
}

private struct ExternalPage: Hashable {
    let id: UUID
    let label: String
}

private struct SecondaryExternalPage: Hashable {
    let section: String
    let itemID: Int
}

private struct CallbackPage: Hashable {
    let id: Int
    let callback: CallbackBox

    static func == (lhs: CallbackPage, rhs: CallbackPage) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private final class CallbackBox {
    let callback: () -> Void

    init(callback: @escaping () -> Void) {
        self.callback = callback
    }
}

private struct CustomProjectedExternalPage: Hashable, Relux.Navigation.PathProjectionRepresentable {
    let routeID: String

    var navigationPathProjectionDescription: String {
        routeID
    }
}
