import Foundation

public struct FSRSWeights: Sendable, Equatable {
    public let values: [Double]

    public init(values: [Double]) {
        precondition(values.count == 21, "FSRS-6 requires exactly 21 weights, got \(values.count)")
        self.values = values
    }

    /// FSRS-6 default parameters (open-spaced-repetition/py-fsrs, fsrs/scheduler.py).
    public static let `default` = FSRSWeights(values: [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001,
        1.8722, 0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014,
        1.8729, 0.5425, 0.0912, 0.0658, 0.1542
    ])
}
