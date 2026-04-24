# FlowKit

FlowKit is a Swift state-management library that implements Unidirectional Data Flow (UDF) on top of `@Observable` and Swift Concurrency. State, reducers, and effect dispatch are MainActor-isolated; async work runs off-actor and hops back via `Send`.

```
Action → Reducer → State → Effect → (async work) → Action
```

## Requirements

- Swift 6.0 (Xcode 16+), Swift language mode `.v6`
- iOS 17, macOS 14, watchOS 10, tvOS 17
- Strict-concurrency clean: every `State` and `Action` must be `Sendable`

## Installation

Add FlowKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pfriedrix/FlowKit", from: "0.3.2")
],
targets: [
    .target(name: "App", dependencies: ["FlowKit"])
]
```

Or in Xcode: **File → Add Packages…**, enter `https://github.com/pfriedrix/FlowKit`, pick a version, add the **FlowKit** product to your target.

## Quick start

```swift
import FlowKit
import SwiftUI

struct CounterReducer: Reducer {
    struct State: Equatable, Sendable { var count = 0 }
    enum Action: Sendable { case increment, decrement }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment: state.count += 1; return .none
        case .decrement: state.count -= 1; return .none
        }
    }
}

struct CounterView: View {
    @State private var store = Store(initial: .init(), reducer: CounterReducer())

    var body: some View {
        VStack {
            Text("\(store.state.count)")
            Button("+") { store.send(.increment) }
            Button("-") { store.send(.decrement) }
        }
    }
}
```

`Store` is `@Observable`, so SwiftUI tracks `state` automatically.

## Store

```swift
@MainActor
@Observable
public final class Store<R: Reducer> {
    public var state: State
    public required init(initial: State, reducer: R)
    public func send(_ action: Action)
}
```

`send(_:)` runs the reducer synchronously on MainActor, commits the new state, then schedules any returned effect. In-flight `.run` effects are tracked in a per-store registry keyed by UUID and cancelled on `deinit`.

A second initializer is available when `State: Storable` — see [Persistence](#persistence).

## Reducer

```swift
public protocol Reducer<State, Action>: Sendable {
    associatedtype State: Sendable
    associatedtype Action: Sendable

    @MainActor
    func reduce(into state: inout State, action: Action) -> Effect<Action>
}
```

## Effect

`Effect<Action>` is the only return type from a reducer. It carries one of:

- `.none` — no side effect
- `.send(Action)` — dispatch a follow-up action
- `.merge(Action...)` — dispatch several actions in order
- `.run { send in … }` — run an async closure, optionally `throws`, with an optional `catch` handler
- `.cancel(id:)` — cancel an in-flight cancellable run

```swift
case .fetchUser(let id):
    return .run { send in
        let user = try await api.user(id: id)
        await send(.userLoaded(user))
    } catch: { error, send in
        await send(.userFailed(error))
    }
```

Inside a `.run`, `send` is a `Send<Action>` you call as a function. Each call hops to MainActor and dispatches into this store. To dispatch into a *different* shared store, pass a key path:

```swift
return .run { send in
    let value = await fetchValue()
    await send(\.analyticsStore, action: .track(value))
}
```

If you only need fire-and-forget dispatch into another store from a reducer, use `Effect.send(_:action:)`:

```swift
return .send(\.analyticsStore, action: .screenViewed)
```

### Effect modifiers

```swift
.cancellable(id: SearchID(), cancelInFlight: true)
.animation(.spring())
```

- `.cancellable(id:cancelInFlight:)` — registers the `.run` task in the store's MainActor task registry under `id`. Pair with `Effect.cancel(id:)` to cancel it. Set `cancelInFlight: true` to cancel any prior task with the same id before this one starts.
- `Effect.cancel(id:)` — pure-data effect; cancellation happens synchronously on MainActor when the store handles it, so it's safe to dispatch in the same `send` chain that registered the task.
- `.animation(_:)` — wraps the action dispatches this effect performs in `withAnimation(_:)`. Pass `nil` to clear an inherited animation.

> Cancellation is cooperative. The async body must observe `Task.isCancelled` (e.g. via `try await Task.sleep`, `try Task.checkCancellation()`) for cancellation to actually stop work.

## Persistence

### Storable

```swift
public protocol Storable {
    func save()
    static func load() -> Self?
}
```

When `State: Storable`, use the convenience initializer to wire automatic save-on-action:

```swift
let store = Store(reducer: AppReducer(), default: AppState())
```

This restores from `State.load()` if available, otherwise seeds with `default` and saves it. Subsequent `send(_:)` calls fire `state.save()` on a per-store serial background queue, so encoding stays off MainActor.

### Persistable

`Persistable: Storable, Codable` ships default JSON + `UserDefaults` implementations keyed by `String(reflecting: Self.self)`. Conformance is one line:

```swift
struct AppState: Persistable, Equatable {
    var count = 0
    var isLoggedIn = false
}
```

For custom backing stores (Keychain, files, SwiftData…) implement `Storable` directly.

## Dependency injection

FlowKit ships a SwiftUI-style task-local registry: `StoreValues` is to stores what `EnvironmentValues` is to environment values.

### @Inject

`@Inject` is the recommended way to register a shared store. Apply it to a typed, initialized property inside `extension StoreValues`:

```swift
extension StoreValues {
    @Inject var counterStore: Store<CounterReducer> = .init(
        initial: .init(),
        reducer: .init()
    )
}
```

The macro expands to:

```swift
extension StoreValues {
    fileprivate struct __Store_counterStore: StoreKey {
        @MainActor static let defaultValue: Store<CounterReducer> =
            .init(initial: .init(), reducer: .init())
    }
    var counterStore: Store<CounterReducer> {
        get { self[__Store_counterStore.self] }
        set { self[__Store_counterStore.self] = newValue }
    }
}
```

### @Shared

Pull a registered store into a SwiftUI view:

```swift
struct CounterView: View {
    @Shared(\.counterStore) var store

    var body: some View {
        Text("\(store.state.count)")
    }
}
```

`@Shared` resolves the store from `StoreValues` once, at init time. The wrapped value is read-only — for test-time overrides use `StoreValues.withValues { ... }`:

```swift
StoreValues.withValues { values in
    values.counterStore = Store(initial: .init(count: 42), reducer: CounterReducer())
} operation: {
    // store reads inside this closure see the override
}
```

A `@Sendable` async overload exists for use inside `Task { … }`.

## SwiftUI bindings

`Store` exposes four `binding(...)` overloads for driving SwiftUI controls:

```swift
// 1. Custom getter and action-returning setter
store.binding(get: { someValue }, set: { .didChange($0) })

// 2. Getter receives the state
store.binding(get: \.someValue, set: { .didChange($0) })

// 3. KeyPath + action factory
store.binding(for: \.username, set: { .usernameChanged($0) })

// 4. KeyPath + a single action dispatched on every change
store.binding(for: \.isPresented, set: .didDismiss)
```

Getters capture the store strongly so SwiftUI never reads through a dangling reference; setters capture weakly so a discarded `Binding` does not extend the store's lifetime.

## Logging

FlowKit logs every action and resolved state through `os.Logger` (subsystem `flow-kit`, category `store-events`). Configure verbosity and action formatting at process start:

```swift
import os
import FlowKit

Logger.logLevel = .info          // .debug | .info | .error | .fault
Logger.formatStyle = .short      // .full | .short | .abbreviated
```

Both properties are thread-safe.

## Testing

Tests run on `@MainActor` and create stores directly. The test target ships a `waitForStateChange` helper for asserting state after async effects:

```swift
let store = Store(initial: .init(), reducer: CounterReducer())
store.send(.fetchData)

try await waitForStateChange(timeout: 1) {
    store.state.data != nil
}
```

It observes `@Observable` notifications and falls back to short polling, so it returns as soon as the predicate flips.

## License

MIT — see [LICENSE](LICENSE).
