import Foundation

@MainActor
@Observable
final class AsyncAwaitPaymentViewModel: PaymentDemoViewModel {

    var amountText = "" {
        didSet { scheduleRecalculation() }
    }

    var selectedAccount: Account? {
        didSet { scheduleRecalculation() }
    }

    var selectedRecipient: Recipient? {
        didSet { scheduleRecalculation() }
    }

    var selectedCurrency: Currency = .nzd {
        didSet { scheduleRecalculation() }
    }

    var promoCodeText = "" {
        didSet { scheduleRecalculation() }
    }

    var networkStatus: NetworkStatus = .online {
        didSet { scheduleRecalculation() }
    }

    var featureFlags = FeatureFlags(
        promoCodesEnabled: true,
        internationalTransfersEnabled: true
    ) {
        didSet { scheduleRecalculation() }
    }

    private(set) var state: PaymentState = .idle
    private(set) var submitResult: Result<Void, Error>?

    var isSubmitEnabled: Bool { state.isSubmitEnabled }
    var feeText: String { state.feeText }
    var totalText: String { state.totalText }

    private let quoteAPI: PaymentQuoteAPI
    private let submitAPI: PaymentSubmitAPI

    @ObservationIgnored private var quoteTask: Task<Void, Never>?
    @ObservationIgnored private var submitTask: Task<Void, Never>?
    @ObservationIgnored private var latestReadyDraftAndQuote: (PaymentDraft, PaymentQuote)?

    convenience init() {
        self.init(
            quoteAPI: MockPaymentQuoteAPI(),
            submitAPI: MockPaymentSubmitAPI()
        )
    }

    init(
        quoteAPI: PaymentQuoteAPI,
        submitAPI: PaymentSubmitAPI
    ) {
        self.quoteAPI = quoteAPI
        self.submitAPI = submitAPI
        scheduleRecalculation()
    }

    deinit {
        quoteTask?.cancel()
        submitTask?.cancel()
    }

    private func scheduleRecalculation() {
        quoteTask?.cancel()

        quoteTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
                try Task.checkCancellation()
                await self?.recalculateQuote()
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    private func recalculateQuote() async {
        let result = PaymentDraftBuilder.build(
            amountText: amountText,
            account: selectedAccount,
            recipient: selectedRecipient,
            currency: selectedCurrency,
            promoCodeText: promoCodeText,
            networkStatus: networkStatus,
            featureFlags: featureFlags
        )

        switch result {
        case let .failure(error):
            latestReadyDraftAndQuote = nil
            state = .invalid(error)

        case let .success(draft):
            latestReadyDraftAndQuote = nil
            state = .loading(draft)

            do {
                let quote = try await quoteAPI.loadQuote(for: draft)
                try Task.checkCancellation()

                latestReadyDraftAndQuote = (draft, quote)
                state = .ready(draft, quote)
            } catch is CancellationError {
                return
            } catch {
                latestReadyDraftAndQuote = nil
                state = .failed(draft, error.localizedDescription)
            }
        }
    }

    func submit() {
        guard let latestReadyDraftAndQuote else { return }

        submitTask?.cancel()
        submitTask = Task { [weak self, submitAPI] in
            do {
                try await submitAPI.submitPayment(
                    draft: latestReadyDraftAndQuote.0,
                    quote: latestReadyDraftAndQuote.1
                )
                self?.setSubmitResult(.success(()))
            } catch is CancellationError {
                return
            } catch {
                self?.setSubmitResult(.failure(error))
            }
        }
    }

    private func setSubmitResult(_ result: Result<Void, Error>) {
        submitResult = result
    }
}
