import Foundation

/// Utility for formatting translation text based on user preferences.
enum TextFormatter {
    /// Returns text with first letter formatted according to the capitalizeFirstLetter setting.
    /// - When capitalizeFirstLetter is true: ensures first letter is uppercase
    /// - When capitalizeFirstLetter is false: ensures first letter is lowercase
    static func format(_ text: String, capitalizeFirstLetter: Bool) -> String {
        guard !text.isEmpty else { return text }
        if capitalizeFirstLetter {
            return text.prefix(1).uppercased() + text.dropFirst()
        } else {
            return text.prefix(1).lowercased() + text.dropFirst()
        }
    }
}
