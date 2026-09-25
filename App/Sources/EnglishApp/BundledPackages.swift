import Foundation
import SwiftData

/// The content packages shipped inside the app. Each is a JSON resource
/// produced by scripts/assemble-content.py (YDS) or scripts/assemble-package.py.
enum BundledPackages {
    static let resourceNames = ["YDSAcademicVocabulary1", "BusinessEnglish1", "EverydayEnglish1"]

    /// Seeds each named resource on its own and returns one message per
    /// package that could not be installed (missing file or invalid content).
    @discardableResult
    static func seedAll(
        names: [String] = resourceNames, from bundle: Bundle = .main, into context: ModelContext
    ) -> [String] {
        var failures: [String] = []
        for name in names {
            guard let url = bundle.url(forResource: name, withExtension: "json") else {
                failures.append("\(name).json missing from app bundle")
                continue
            }
            do {
                _ = try ContentSeeder.seed(bundledData: Data(contentsOf: url), into: context)
            } catch {
                failures.append("Failed to seed \(name): \(error.localizedDescription)")
            }
        }
        return failures
    }
}
