import Foundation

enum MoneyFormatter {
    static func string(from value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
