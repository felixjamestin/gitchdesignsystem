import Testing
import GlitchMath

@Suite("Number parsing")
struct GlitchNumberParsingTests {

    @Test("parses plain integers and decimals")
    func parsesNumbers() {
        #expect(GlitchNumberParsing.parse("42", fallback: 0) == 42)
        #expect(GlitchNumberParsing.parse("3.5", fallback: 0) == 3.5)
        #expect(GlitchNumberParsing.parse("-7.25", fallback: 0) == -7.25)
    }

    @Test("tolerates surrounding whitespace and a leading plus")
    func tolerantOfNoise() {
        #expect(GlitchNumberParsing.parse("  12  ", fallback: 0) == 12)
        #expect(GlitchNumberParsing.parse("+9", fallback: 0) == 9)
    }

    @Test("takes the leading number when a unit is typed")
    func stripsTrailingUnits() {
        #expect(GlitchNumberParsing.parse("12px", fallback: 0) == 12)
        #expect(GlitchNumberParsing.parse("45 deg", fallback: 0) == 45)
    }

    @Test("falls back when there is no number to find")
    func fallsBack() {
        #expect(GlitchNumberParsing.parse("", fallback: 5) == 5)
        #expect(GlitchNumberParsing.parse("   ", fallback: 5) == 5)
        #expect(GlitchNumberParsing.parse("banana", fallback: 5) == 5)
        #expect(GlitchNumberParsing.parse("-", fallback: 5) == 5)
    }

    @Test("formats to a fixed number of decimals")
    func formats() {
        #expect(GlitchNumberParsing.format(7.0, decimals: 0) == "7")
        #expect(GlitchNumberParsing.format(7.456, decimals: 2) == "7.46")
        #expect(GlitchNumberParsing.format(-0.5, decimals: 1) == "-0.5")
    }

    @Test("decimal places are derived from the step")
    func decimalsFromStep() {
        #expect(GlitchNumberParsing.decimals(forStep: 1) == 0)
        #expect(GlitchNumberParsing.decimals(forStep: 5) == 0)
        #expect(GlitchNumberParsing.decimals(forStep: 0.1) == 1)
        #expect(GlitchNumberParsing.decimals(forStep: 0.5) == 1)
        #expect(GlitchNumberParsing.decimals(forStep: 0.25) == 2)
        #expect(GlitchNumberParsing.decimals(forStep: 0.001) == 3)
    }

    @Test("a non-positive step asks for no decimals")
    func decimalsFromNoStep() {
        #expect(GlitchNumberParsing.decimals(forStep: 0) == 0)
        #expect(GlitchNumberParsing.decimals(forStep: -1) == 0)
    }

    @Test("formatting then parsing preserves the value")
    func roundTrips() {
        let value = 13.75
        let text = GlitchNumberParsing.format(value, decimals: 2)
        #expect(GlitchNumberParsing.parse(text, fallback: 0) == value)
    }
}
