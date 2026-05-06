import Foundation

@MainActor
protocol PaymentDemoViewModel: AnyObject, Observable {
    var amountText: String { get set }
    var selectedAccount: Account? { get set }
    var selectedRecipient: Recipient? { get set }
    var selectedCurrency: Currency { get set }
    var promoCodeText: String { get set }
    var networkStatus: NetworkStatus { get set }
    var featureFlags: FeatureFlags { get set }
    var state: PaymentState { get }
    var isSubmitEnabled: Bool { get }
    var feeText: String { get }
    var totalText: String { get }
    func submit()
}
