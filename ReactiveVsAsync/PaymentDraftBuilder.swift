import Foundation

enum PaymentDraftBuilder {
    static func build(
        amountText: String,
        account: Account?,
        recipient: Recipient?,
        currency: Currency,
        promoCodeText: String,
        networkStatus: NetworkStatus,
        featureFlags: FeatureFlags
    ) -> Result<PaymentDraft, PaymentValidationError> {
        guard networkStatus == .online else {
            return .failure(.offline)
        }

        guard let amount = Decimal(string: amountText), amount > 0 else {
            return .failure(.emptyAmount)
        }

        guard let account else {
            return .failure(.missingAccount)
        }

        guard account.balance >= amount else {
            return .failure(.insufficientFunds)
        }

        guard let recipient else {
            return .failure(.missingRecipient)
        }

        let isInternational = recipient.countryCode != "NZ"
        guard !isInternational || featureFlags.internationalTransfersEnabled else {
            return .failure(.internationalTransfersDisabled)
        }

        let promoCode: PromoCode?
        if featureFlags.promoCodesEnabled, !promoCodeText.isEmpty {
            promoCode = PromoCode(value: promoCodeText)
        } else {
            promoCode = nil
        }

        return .success(
            PaymentDraft(
                amount: amount,
                account: account,
                recipient: recipient,
                currency: currency,
                promoCode: promoCode
            )
        )
    }
}
