import XCTest
import CoreAgent
@testable import UIComponents

final class UIComponentsTests: XCTestCase {
    func testFaceViewInit() {
        XCTAssertNotNil(BMOFaceView(expression: .happy, state: .idle))
        XCTAssertNotNil(BMOFaceView(expression: .excited, state: .speaking))
    }

    func testGlassStyleResolverFallbackAndLiquidModes() {
        XCTAssertEqual(GlassStyleResolver.resolve(osMajorVersion: 26), .liquid)
        XCTAssertEqual(GlassStyleResolver.resolve(osMajorVersion: 25), .materialFallback)
    }
}
