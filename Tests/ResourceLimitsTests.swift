import XCTest
#if canImport(ThreeMFCore)
    @testable import ThreeMFCore
#endif

final class ResourceLimitsTests: XCTestCase {
    func testQuickLookCapsAreTighterThanCLI() {
        XCTAssertLessThan(ResourceLimits.quickLook.maxVertices, ResourceLimits.cli.maxVertices)
        XCTAssertLessThan(ResourceLimits.quickLook.maxGCodeSegments, ResourceLimits.cli.maxGCodeSegments)
        XCTAssertLessThan(ResourceLimits.quickLook.maxMetadataSidecarBytes, ResourceLimits.cli.maxMetadataSidecarBytes)
    }
}
