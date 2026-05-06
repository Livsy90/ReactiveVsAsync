import AsyncAlgorithms
import Foundation

@MainActor
@Observable
final class AsyncAlgorithmsPaymentViewModel: PaymentDemoViewModel {

    var amountText = "" {
        didSet { enqueueRecalculation() }
    }

    var selectedAccount: Account? {
        didSet { enqueueRecalculation() }
    }

    var selectedRecipient: Recipient? {
        didSet { enqueueRecalculation() }
    }

    var selectedCurrency: Currency = .nzd {
        didSet { enqueueRecalculation() }
    }

    var promoCodeText = "" {
        didSet { enqueueRecalculation() }
    }

    var networkStatus: NetworkStatus = .online {
        didSet { enqueueRecalculation() }
    }

    var featureFlags = FeatureFlags(
        promoCodesEnabled: true,
        internationalTransfersEnabled: true
    ) {
        didSet { enqueueRecalculation() }
    }

    private(set) var state: PaymentState = .idle
    private(set) var submitResult: Result<Void, Error>?

    var isSubmitEnabled: Bool { state.isSubmitEnabled }
    var feeText: String { state.feeText }
    var totalText: String { state.totalText }

    @ObservationIgnored private let quoteAPI: PaymentQuoteAPI
    @ObservationIgnored private let submitAPI: PaymentSubmitAPI
    @ObservationIgnored private let inputEvents = AsyncChannel<Void>()

    @ObservationIgnored private var workerTask: Task<Void, Never>?
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
        startObservingInputs()
        enqueueRecalculation()
    }

    deinit {
        inputEvents.finish()
        workerTask?.cancel()
        quoteTask?.cancel()
        submitTask?.cancel()
    }

    private func enqueueRecalculation() {
        quoteTask?.cancel()

        Task {
            await inputEvents.send(())
        }
    }

    private func startObservingInputs() {
        workerTask = Task { [weak self, inputEvents] in
            for await _ in inputEvents.debounce(for: .milliseconds(300)) {
                self?.refreshQuote()
            }
        }
    }

    private func refreshQuote() {
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

            quoteTask = Task { [weak self, quoteAPI] in
                do {
                    let quote = try await quoteAPI.loadQuote(for: draft)
                    try Task.checkCancellation()

                    self?.setReadyState(draft: draft, quote: quote)
                } catch is CancellationError {
                    return
                } catch {
                    self?.setFailedState(draft: draft, message: error.localizedDescription)
                }
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

    private func setReadyState(draft: PaymentDraft, quote: PaymentQuote) {
        latestReadyDraftAndQuote = (draft, quote)
        state = .ready(draft, quote)
    }

    private func setFailedState(draft: PaymentDraft, message: String) {
        latestReadyDraftAndQuote = nil
        state = .failed(draft, message)
    }

    private func setSubmitResult(_ result: Result<Void, Error>) {
        submitResult = result
    }
}
