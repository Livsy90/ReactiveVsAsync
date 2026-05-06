internal import Combine
import Foundation

@MainActor
@Observable
final class CombinePaymentViewModel: PaymentDemoViewModel {

    var amountText = "" {
        didSet { amountTextSubject.send(amountText) }
    }
    var selectedAccount: Account? {
        didSet { selectedAccountSubject.send(selectedAccount) }
    }
    var selectedRecipient: Recipient? {
        didSet { selectedRecipientSubject.send(selectedRecipient) }
    }
    var selectedCurrency: Currency = .nzd {
        didSet { selectedCurrencySubject.send(selectedCurrency) }
    }
    var promoCodeText = "" {
        didSet { promoCodeTextSubject.send(promoCodeText) }
    }
    var networkStatus: NetworkStatus = .online {
        didSet { networkStatusSubject.send(networkStatus) }
    }
    var featureFlags = FeatureFlags(
        promoCodesEnabled: true,
        internationalTransfersEnabled: true
    ) {
        didSet { featureFlagsSubject.send(featureFlags) }
    }

    private(set) var state: PaymentState = .idle
    private(set) var submitResult: Result<Void, Error>?

    var isSubmitEnabled: Bool { state.isSubmitEnabled }
    var feeText: String { state.feeText }
    var totalText: String { state.totalText }

    @ObservationIgnored private let quoteAPI: PaymentQuoteAPI
    @ObservationIgnored private let submitAPI: PaymentSubmitAPI
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var submitTask: Task<Void, Never>?
    @ObservationIgnored private var latestReadyDraftAndQuote: (PaymentDraft, PaymentQuote)?
    @ObservationIgnored private let amountTextSubject = CurrentValueSubject<String, Never>("")
    @ObservationIgnored private let selectedAccountSubject = CurrentValueSubject<Account?, Never>(nil)
    @ObservationIgnored private let selectedRecipientSubject = CurrentValueSubject<Recipient?, Never>(nil)
    @ObservationIgnored private let selectedCurrencySubject = CurrentValueSubject<Currency, Never>(.nzd)
    @ObservationIgnored private let promoCodeTextSubject = CurrentValueSubject<String, Never>("")
    @ObservationIgnored private let networkStatusSubject = CurrentValueSubject<NetworkStatus, Never>(.online)
    @ObservationIgnored private let featureFlagsSubject = CurrentValueSubject<FeatureFlags, Never>(
        FeatureFlags(
            promoCodesEnabled: true,
            internationalTransfersEnabled: true
        )
    )

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
        bind()
    }

    private func bind() {
        let draft = Publishers.CombineLatest4(
            amountTextSubject.removeDuplicates(),
            selectedAccountSubject.removeDuplicates(),
            selectedRecipientSubject.removeDuplicates(),
            selectedCurrencySubject.removeDuplicates()
        )
        .combineLatest(
            promoCodeTextSubject.removeDuplicates(),
            networkStatusSubject.removeDuplicates(),
            featureFlagsSubject.removeDuplicates()
        )
        .map { firstGroup, promoCodeText, networkStatus, featureFlags in
            let (amountText, account, recipient, currency) = firstGroup

            return PaymentDraftBuilder.build(
                amountText: amountText,
                account: account,
                recipient: recipient,
                currency: currency,
                promoCodeText: promoCodeText,
                networkStatus: networkStatus,
                featureFlags: featureFlags
            )
        }
        .eraseToAnyPublisher()

        draft
            .debounce(for: RunLoop.SchedulerTimeType.Stride.milliseconds(300), scheduler: RunLoop.main)
            .map { [quoteAPI] (result: Result<PaymentDraft, PaymentValidationError>) -> AnyPublisher<PaymentState, Never> in
                switch result {
                case let .failure(error):
                    return Just(PaymentState.invalid(error))
                        .eraseToAnyPublisher()

                case let .success(draft):
                    return Deferred {
                        let subject = PassthroughSubject<PaymentQuote, Error>()
                        let task = Task {
                            do {
                                let quote = try await quoteAPI.loadQuote(for: draft)
                                subject.send(quote)
                                subject.send(completion: .finished)
                            } catch is CancellationError {
                                subject.send(completion: .finished)
                            } catch {
                                subject.send(completion: .failure(error))
                            }
                        }

                        return subject
                            .handleEvents(receiveCancel: {
                                task.cancel()
                            })
                            .eraseToAnyPublisher()
                    }
                    .map { quote in
                        PaymentState.ready(draft, quote)
                    }
                    .catch { error in
                        Just(PaymentState.failed(draft, error.localizedDescription))
                    }
                    .prepend(.loading(draft))
                    .eraseToAnyPublisher()
                }
            }
            .switchToLatest()
            .receive(on: RunLoop.main)
            .sink { [weak self] (state: PaymentState) in
                self?.state = state

                if case let .ready(draft, quote) = state {
                    self?.latestReadyDraftAndQuote = (draft, quote)
                } else {
                    self?.latestReadyDraftAndQuote = nil
                }
            }
            .store(in: &cancellables)
    }

    func submit() {
        guard let latestReadyDraftAndQuote else { return }

        submitTask?.cancel()
        submitTask = Task { [submitAPI] in
            do {
                try await submitAPI.submitPayment(
                    draft: latestReadyDraftAndQuote.0,
                    quote: latestReadyDraftAndQuote.1
                )
                submitResult = .success(())
            } catch is CancellationError {
                return
            } catch {
                submitResult = .failure(error)
            }
        }
    }
}
