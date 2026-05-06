import Foundation

protocol PaymentQuoteAPI {
    func loadQuote(for draft: PaymentDraft) async throws -> PaymentQuote
}

protocol PaymentSubmitAPI {
    func submitPayment(draft: PaymentDraft, quote: PaymentQuote) async throws
}

enum DemoAPIError: Error, LocalizedError {
    case quoteUnavailable
    case submitFailed

    var errorDescription: String? {
        switch self {
        case .quoteUnavailable: "Quote is currently unavailable."
        case .submitFailed: "Payment submit failed."
        }
    }
}

struct MockPaymentQuoteAPI: PaymentQuoteAPI {
    func loadQuote(for draft: PaymentDraft) async throws -> PaymentQuote {
        try await Task.sleep(for: .milliseconds(450))
        try Task.checkCancellation()

        if draft.amount == 13 {
            throw DemoAPIError.quoteUnavailable
        }

        let fee = max(draft.amount * Decimal(string: "0.015")!, 1)
        let discount: Decimal = draft.promoCode == nil ? 0 : 2
        let total = max(draft.amount + fee - discount, 0)

        return PaymentQuote(
            fee: fee,
            total: total,
            estimatedDeliveryDate: Date().addingTimeInterval(86_400)
        )
    }
}

struct MockPaymentSubmitAPI: PaymentSubmitAPI {
    func submitPayment(draft: PaymentDraft, quote: PaymentQuote) async throws {
        try await Task.sleep(for: .milliseconds(350))
        try Task.checkCancellation()

        if quote.total == 666 {
            throw DemoAPIError.submitFailed
        }
    }
}
