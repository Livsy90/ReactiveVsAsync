import SwiftUI

struct ReactiveVSAsyncDemoView: View {
    var body: some View {
        TabView {
            Tab("Combine", systemImage: "link") {
                PaymentDemoScreen(
                    title: "Combine",
                    viewModel: CombinePaymentViewModel()
                )
            }

            Tab("Async/Await", systemImage: "arrow.trianglehead.2.clockwise") {
                PaymentDemoScreen(
                    title: "Async/Await",
                    viewModel: AsyncAwaitPaymentViewModel()
                )
            }

            Tab("AsyncAlgorithms", systemImage: "arrow.branch") {
                PaymentDemoScreen(
                    title: "AsyncAlgorithms",
                    viewModel: AsyncAlgorithmsPaymentViewModel()
                )
            }
        }
    }
}

private struct PaymentDemoScreen<ViewModel: PaymentDemoViewModel>: View {
    let title: String

    @State var viewModel: ViewModel

    private let accounts = [
        Account(id: "Main", currency: .nzd, balance: 1_000),
        Account(id: "Low Balance", currency: .nzd, balance: 10)
    ]

    private let recipients = [
        Recipient(id: "Local", name: "Local Recipient", countryCode: "NZ"),
        Recipient(id: "International", name: "International Recipient", countryCode: "US")
    ]

    var body: some View {
        Form {
            Section(title) {
                TextField("Amount", text: $viewModel.amountText)
                    .keyboardType(.decimalPad)

                Picker("Account", selection: $viewModel.selectedAccount) {
                    Text("None").tag(Account?.none)
                    ForEach(accounts) { account in
                        Text("\(account.id), balance: \(MoneyFormatter.string(from: account.balance))")
                            .tag(Optional(account))
                    }
                }

                Picker("Recipient", selection: $viewModel.selectedRecipient) {
                    Text("None").tag(Recipient?.none)
                    ForEach(recipients) { recipient in
                        Text(recipient.name).tag(Optional(recipient))
                    }
                }

                Picker("Currency", selection: $viewModel.selectedCurrency) {
                    ForEach(Currency.allCases, id: \.self) { currency in
                        Text(currency.rawValue).tag(currency)
                    }
                }

                TextField("Promo code", text: $viewModel.promoCodeText)
            }

            Section("Environment") {
                Toggle(
                    "Online",
                    isOn: Binding(
                        get: { viewModel.networkStatus == .online },
                        set: { viewModel.networkStatus = $0 ? .online : .offline }
                    )
                )

                Toggle(
                    "Promo codes enabled",
                    isOn: $viewModel.featureFlags.promoCodesEnabled
                )

                Toggle(
                    "International transfers enabled",
                    isOn: $viewModel.featureFlags.internationalTransfersEnabled
                )
            }

            Section("Derived State") {
                Text(viewModel.state.message)
                Text("Fee: \(viewModel.feeText)")
                Text("Total: \(viewModel.totalText)")

                Button("Submit") {
                    viewModel.submit()
                }
                .disabled(!viewModel.isSubmitEnabled)
            }
        }
    }
}

#Preview {
    ReactiveVSAsyncDemoView()
}
