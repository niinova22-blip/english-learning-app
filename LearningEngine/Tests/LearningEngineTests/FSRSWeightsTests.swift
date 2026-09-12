import XCTest
@testable import LearningEngine

final class FSRSWeightsTests: XCTestCase {
    func test_default_has21Weights() {
        XCTAssertEqual(FSRSWeights.default.values.count, 21)
    }

    func test_default_matchesReferenceImplementation() {
        let w = FSRSWeights.default.values
        XCTAssertEqual(w[0], 0.212, accuracy: 1e-9)
        XCTAssertEqual(w[4], 6.4133, accuracy: 1e-9)
        XCTAssertEqual(w[20], 0.1542, accuracy: 1e-9)
    }

    func test_init_acceptsCustom21LengthArray() {
        // FSRSWeights.init is not failable; this test only exercises the
        // happy path of constructing a custom (non-default) 21-length array.
        let custom = FSRSWeights(values: Array(repeating: 1.0, count: 21))
        XCTAssertEqual(custom.values.count, 21)
    }
}
