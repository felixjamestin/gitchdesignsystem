import XCTest
@testable import GlitchDesignSystem

final class GlitchTokenTests: XCTestCase {
    func testLayoutSpacingSitsOnTheEightPointGrid() {
        XCTAssertEqual(GlitchSpace.layoutSteps, [0, 8, 16, 24, 32, 40, 48, 64, 80])
        XCTAssertEqual([GlitchInset.panel, GlitchInset.card, GlitchInset.dialog], [16, 24, 32])
        XCTAssertEqual([GlitchGap.stack, GlitchGap.group, GlitchGap.section], [8, 16, 24])
    }

    func testStylesDrawInTheInstalledFacesAndSystemStylesIgnoreThem() {
        let families = GlitchFontFamilies(sans: "IBM Plex Sans", mono: "IBM Plex Mono")
        XCTAssertEqual(GlitchTextStyle.body.face(in: families), "IBM Plex Sans")
        XCTAssertEqual(GlitchTextStyle.button.face(in: families), "IBM Plex Mono")
        XCTAssertEqual(GlitchTextStyle.hero.face(in: families), "IBM Plex Sans")
        XCTAssertNil(GlitchTextStyle.body.family(.system).face(in: families))
        XCTAssertNil(GlitchTextStyle.micro.face(in: families))
        XCTAssertNil(GlitchTextStyle.body.face(in: .system))
    }

    func testTheScaleGrowsWithEveryStep() {
        let sizes = GlitchTextStyle.scale.map(\.size)
        XCTAssertEqual(sizes, [8, 9, 10, 11, 12, 13, 14, 15, 18, 22, 28, 36, 76])
    }
}
