---

# FlowKit

FlowKit is a Swift-based library that implements a Unidirectional Data Flow (UDF) architecture, designed to simplify state management within applications. It centralizes application state and logic, making your app's behavior more predictable, testable, and maintainable.

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Architecture Overview](#architecture-overview)
4. [Usage](#usage)
   - [Store](#store)
   - [Reducer](#reducer)
   - [Effect](#effect)
   - [Storage](#storage)
   - [Persistable](#persistable)
   - [Shared](#shared)
   - [Inject Macro](#inject-macro)
5. [License](#license)

## Introduction

Inspired by the UDF architecture pattern, FlowKit provides a structured approach to managing state in Swift applications. With FlowKit, developers can centralize state in a single `Store`, apply updates through `Reducers`, and handle asynchronous tasks with `Effects`. This architecture provides a straightforward flow that scales easily and aids in debugging by making application state predictable and consistent.

## Installation

To install FlowKit via Swift Package Manager (SPM):

1. Open your Xcode project.
2. Go to `File` > `Add Packages...`.
3. Enter the following URL in the search bar:
   ```
   https://github.com/pfriedrix/FlowKit
   ```
4. Select the FlowKit package and choose the desired version.
5. Click `Add Package`.

This will add FlowKit to your project, enabling state management using UDF principles in Swift.

## Architecture Overview

FlowKit follows a unidirectional data flow to make state changes predictable and easy to trace. The main components are:

- **Store**: Holds the application’s state and allows updates via dispatched actions.
- **Action**: Describes events that occur, like user interactions or external data updates.
- **Reducer**: Defines how the state transitions in response to actions.
- **Effect**: Manages side effects, such as network requests and asynchronous operations.
  
## Usage

### Store

The `Store` is the central component that maintains the application’s state. It initializes with an initial state and a reducer that specifies how actions change the state.

```swift
let store = Store(initial: AppReducer.State(), reducer: AppReducer())
```

### Reducer

A `Reducer` is responsible for handling actions and modifying the state accordingly. It defines how actions influence the application state and can return an `Effect` for asynchronous operations.

Example:

```swift
struct CounterReducer: Reducer {
    struct State: Equatable {
        var count: Int = 0
    }
    
    enum Action {
        case increment
        case decrement
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none
        case .decrement:
            state.count -= 1
            return .none
        }
    }
}
```

### Effect

`Effect` is used to handle side effects, such as network requests and other asynchronous operations.

Example of using an effect to handle async tasks:

```swift
func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .fetchData:
        return .run { send in
            let data = await fetchData()
            await send(.updateData(data))
        }
    case .updateData(let newData):
        state.data = newData
        return .none
    }
}
```

### Storage

FlowKit provides the `Storable` protocol for persisting state between app sessions. This allows application state to be saved and restored automatically, ensuring data continuity across app launches. `Storable` defines essential methods for saving and loading state. This is especially useful for maintaining user preferences, session data, and application configurations without requiring additional manual handling by developers.

Example:

```swift
struct State: Storable {
    var count: Int

    func save() {
        // Save the state
    }

    static func load() -> State? {
        // Load and return the saved state
    }
}
```

### Persistable

`Persistable` builds on `Storable` to streamline automatic state persistence in `UserDefaults`. It provides default implementations for saving and loading state without requiring additional code from the developer. By conforming to `Persistable`, a type automatically gains support for encoding and decoding its state using `Codable`, and saving/restoring from persistent storage using a uniquely derived key. This ensures that the application state is always retained across app restarts, making it easy to manage user sessions, preferences, and other critical data.

Example:

```swift
struct AppState: Persistable, Equatable {
    var count: Int = 0
    var isLoggedIn: Bool = false
}

enum AppAction {
    case increment
    case decrement
    case login
    case logout
}

struct AppReducer: Reducer {
    func reduce(into state: inout AppState, action: AppAction) -> Effect<AppAction> {
        switch action {
        case .increment:
            state.count += 1
            return .none
        case .decrement:
            state.count -= 1
            return .none
        case .login:
            state.isLoggedIn = true
            return .none
        case .logout:
            state.isLoggedIn = false
            return .none
        }
    }
}

// Initializing a store with automatic persistence using Storage.swift functionality
let store = Store(reducer: AppReducer(), default: AppState.load() ?? AppState())

// Dispatching an action that modifies the state
store.send(.increment)

// The state is automatically saved after each action
/*
Explanation of the persistence mechanism:

1. `AppState` conforms to `Persistable`, allowing it to be automatically saved and loaded.
2. The store is initialized with `AppState.load()` to restore previous state if available.
3. Whenever an action is dispatched (`store.send(.increment)`),
   - The reducer updates the state.
   - The `Store` automatically persists the updated state.
4. On app restart, `AppState.load()` retrieves the last saved state, ensuring continuity.
4. `@Inject` automatically creates a `StoreKey` type to manage store access dynamically, whereas manually defining it would require extra code:

```swift
fileprivate struct __Key_counterStore: StoreKey {
    static let defaultValue: Store<CounterReducer> = .init(initial: .init(), reducer: .init())
}

extension StoreValues {
    var counterStore: Store<CounterReducer> {
        get { self[__Key_counterStore.self] }
        set { self[__Key_counterStore.self] = newValue }
    }
}
```

5. Without `@Inject`, any changes to the store initialization must be manually updated in multiple places, whereas `@Inject` centralizes it for maintainability.
*/
```

### Shared

`Shared` allows accessing a globally stored instance of `Store` in a SwiftUI environment. It simplifies state management by ensuring that views always have access to a consistent, shared state without needing to manually pass the store down the view hierarchy. This approach improves modularity and maintainability, as different parts of the app can access and modify state while staying in sync. The `Shared` property wrapper retrieves the store from the globally defined `StoreValues`, ensuring that state updates trigger SwiftUI view updates automatically.

Example:

```swift
struct ContentView: View {
    @Shared(\.counterStore) var store
    
    var body: some View {
        Text("Count: \(store.state.count)")
    }
}
```

### Inject Macro

The `@Inject` macro provides a convenient way to define and inject dependencies. It simplifies dependency management by automatically generating a `StoreKey` for the property it is applied to, ensuring that the associated store can be accessed globally via `StoreValues`. This eliminates the need for manual dependency injection and makes the store easily accessible across different parts of the application. The macro works by creating a computed property backed by a global store repository, ensuring that instances are managed efficiently and consistently throughout the app lifecycle.

Example:

```swift
extension StoreValues {
    @Inject var counterStore: Store<CounterReducer> = .init(initial: .init(), reducer: .init())
}

/*
Without `@Inject`, dependency injection must be handled manually by defining a store property and associating it with a unique key for global access.

Example of manual dependency injection:

fileprivate struct CounterStoreKey: StoreKey {
    static let defaultValue: Store<CounterReducer> = .init(initial: .init(), reducer: .init())
}

extension StoreValues {
    var counterStore: Store<CounterReducer> {
        get { self[CounterStoreKey.self] }
        set { self[CounterStoreKey.self] = newValue }
    }
}

// Accessing the store:
let store = StoreValues().counterStore

// The key differences:
1. With `@Inject`, the `StoreKey` is generated automatically, reducing boilerplate code.
2. Without `@Inject`, developers must manually define and maintain `StoreKey` structures.
3. `@Inject` dynamically retrieves the store instance via `StoreValues`, ensuring automatic injection and consistency.
4. Using `@Inject` centralizes store initialization, reducing maintenance effort when store dependencies change.
*/
```

This automatically generates a `StoreKey` and allows accessing the store like:

```swift
@Shared(\.counterStore) var store
```

This enables seamless access to the store within SwiftUI views using `@Shared`, ensuring that state updates propagate efficiently throughout the application.

## License

This project is licensed under the MIT License. For details, see the [LICENSE](https://github.com/pfriedrix/FlowKit/blob/main/LICENSE) file.

---

