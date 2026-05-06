# ReactiveVsAsync

`ReactiveVsAsync` is a small SwiftUI demo project that compares three ways to model the same non-trivial UI flow:

- `Combine`
- plain Swift Concurrency with `async/await` and `Task`
- `AsyncAlgorithms`

## Why This Project Exists

This project is meant to make the tradeoffs visible when a screen has many independent inputs and asynchronous side effects.

The goal is not to build a production payment feature. The goal is to show how the same problem reads and behaves when implemented with different orchestration styles.

## What It Demonstrates

The demo uses a payment form with multiple changing inputs:

- amount
- selected account
- selected recipient
- currency
- promo code
- network status
- feature flags

From those inputs, each implementation must do the same work:

- validate user input
- derive a `PaymentDraft`
- debounce recalculation
- cancel stale quote requests
- fetch a payment quote asynchronously
- convert failures into UI state
- keep the latest valid quote for submit
- expose derived values such as fee, total, and submit availability

This makes it a useful example for comparing:

- reactive pipelines vs task-based orchestration
- cancellation handling
- state propagation into SwiftUI
- readability and maintenance costs of each approach

## Project Structure

- `ReactiveVSAsyncDemoView.swift` contains the demo UI with three tabs.
- `CombinePaymentViewModel.swift` shows the Combine-based solution.
- `AsyncAwaitPaymentViewModel.swift` shows a direct Swift Concurrency approach.
- `AsyncAlgorithmsPaymentViewModel.swift` shows an Async Algorithms-based approach.
- `PaymentDraftBuilder.swift` contains shared validation and draft-building logic.
- `PaymentAPI.swift` contains mock async APIs used by all implementations.
- `DemoDomain.swift` contains the shared domain models and state types.

## How To Use It

Run the app and switch between the three tabs:

- `Combine`
- `Async/Await`
- `AsyncAlgorithms`

Then interact with the same form in each tab and observe how each implementation handles the same requirements.

## Intended Takeaway

This project is useful if you want to study when reactive code is still helpful, when plain `async/await` is enough, and where `AsyncAlgorithms` can provide a middle ground for event-driven async flows.
