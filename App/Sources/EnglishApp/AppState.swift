import Foundation

@Observable
final class AppState {
    private(set) var dataGeneration = 0

    func bumpDataGeneration() {
        dataGeneration += 1
    }
}
