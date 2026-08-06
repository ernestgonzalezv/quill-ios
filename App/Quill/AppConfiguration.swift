import Foundation

/// Build-time configuration, read from `Info.plist`.
///
/// The API host is a build setting (`QUILL_API_BASE_URL` per configuration) rather
/// than an `#if DEBUG` branch in Swift. An inverted `#if` ships a debug build
/// pointing at production — or worse, a release build pointing at staging — and
/// nothing catches it. A build setting is visible in the archive and diffable.
struct AppConfiguration: Sendable {
    let apiBaseURL: URL

    static func fromBundle(_ bundle: Bundle = .main) -> AppConfiguration {
        AppConfiguration(apiBaseURL: Self.readAPIBaseURL(from: bundle))
    }

    private static func readAPIBaseURL(from bundle: Bundle) -> URL {
        guard
            let raw = bundle.object(forInfoDictionaryKey: "QuillAPIBaseURL") as? String,
            let url = URL(string: raw),
            url.scheme == "https"
        else {
            // A missing or plaintext-HTTP endpoint is a build misconfiguration, not
            // a runtime condition to degrade through: failing loudly in development
            // is the whole point, and the app still works offline regardless.
            assertionFailure("QuillAPIBaseURL is missing or is not an https URL")
            return URL(string: "https://invalid.localhost")!
        }
        return url
    }
}
