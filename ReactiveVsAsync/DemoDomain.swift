import Foundation

struct Account: Equatable, Hashable, Identifiable {
    let id: String
    let currency: Currency
    let balance: Decimal
}

struct Recipient: Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let countryCode: String
}

enum Currency: String, CaseIterable, Equatable, Hashable {
    case usd = "USD"
    case eur = "EUR"
    case nzd = "NZD"
}

struct PromoCode: Equatable {
    let value: String
}

struct FeatureFlags: Equatable {
    var promoCodesEnabled: Bool
    var internationalTransfersEnabled: Bool
}

enum NetworkStatus: Equatable {
    case online
    case offline
}

struct PaymentDraft: Equatable {
    let amount: Decimal
    let account: Account
    let recipient: Recipient
    let currency: Currency
    let promoCode: PromoCode?
}

struct PaymentQuote: Equatable {
    let fee: Decimal
    let total: Decimal
    let estimatedDeliveryDate: Date
}

enum PaymentValidationError: Error, Equatable, CustomStringConvertible {
    case emptyAmount
    case missingAccount
    case missingRecipient
    case insufficientFunds
    case offline
    case internationalTransfersDisabled

    var description: String {
        switch self {
        case .emptyAmount: "Enter an amount."
        case .missingAccount: "Select an account."
        case .missingRecipient: "Select a recipient."
        case .insufficientFunds: "Insufficient funds."
        case .offline: "You are offline."
        case .internationalTransfersDisabled: "International transfers are temporarily unavailable."
        }
    }
}

enum PaymentState: Equatable {
    case idle
    case invalid(PaymentValidationError)
    case loading(PaymentDraft)
    case ready(PaymentDraft, PaymentQuote)
    case failed(PaymentDraft, String)

    var isSubmitEnabled: Bool {
        if case .ready = self { return true }
        return false
    }

    var feeText: String {
        guard case let .ready(_, quote) = self else { return "—" }
        return MoneyFormatter.string(from: quote.fee)
    }

    var totalText: String {
        guard case let .ready(_, quote) = self else { return "—" }
        return MoneyFormatter.string(from: quote.total)
    }

    var message: String {
        switch self {
        case .idle: "Fill in payment details."
        case let .invalid(error): error.description
        case .loading: "Calculating quote…"
        case let .ready(_, quote): "Ready. Total: \(MoneyFormatter.string(from: quote.total))"
        case let .failed(_, message): message
        }
    }
}
