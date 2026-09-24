import Foundation

/// Legal links shown under the subscription button.
enum StoreLinks {
    /// Apple's standard license agreement satisfies the "terms of use"
    /// requirement for auto-renewing subscriptions.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")

    /// Published from the public niinova22-blip/lexpath repo (GitHub Pages),
    /// kept separate so it stays online after this repo goes private.
    static let privacyPolicy = URL(string: "https://niinova22-blip.github.io/lexpath/privacy.html")
}
