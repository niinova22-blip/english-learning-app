import Foundation

/// Legal links shown under the subscription button.
enum StoreLinks {
    /// Apple's standard license agreement satisfies the "terms of use"
    /// requirement for auto-renewing subscriptions.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")

    /// Set to the published privacy policy URL before the first App Store
    /// submission (docs/store-setup.md step 6). The paywall hides the link
    /// while this is nil.
    static let privacyPolicy: URL? = nil
}
