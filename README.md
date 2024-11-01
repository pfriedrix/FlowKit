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
- **Reducer**: Pure functions that specify how the state transitions in response to actions.
- **Effect**: Manages side effects, such as network requests and asynchronous operations.
- **Persistable**: Extends `Storable` by automatically handling state persistence and restoration.

## Usage

### Store

The `Store` is the central component that maintains the application’s state. It initializes with an initial state and a reducer that specifies how actions change the state.

```swift
let store = Store(initialState: AppReducer.State(), reducer: AppReducer())
```

### Reducer

A `Reducer` defines how state changes in response to actions. It takes the current state and an action, applies the necessary changes, and returns any `Effects` for asynchronous tasks.

Example:

```swift
func appReducer(state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .increment:
        state.count += 1  
        return .none
    }
}
```

### Effect

`Effect` is used to handle side effects, such as network requests and other asynchronous operations. Effects can send actions or run async tasks that dispatch actions upon completion.

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

`Effect` can also send direct actions without async tasks:

```swift
func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .fetchData:
        return .send(.updateData("Update Data"))
    case .updateData(let newData):
        state.data = newData
        return .none
    }
}
```

### Storage

FlowKit provides the `Storable` protocol for persisting state between app sessions. Conforming to `Storable` allows state to be saved and loaded automatically. Any state conforming to `Storable` can be saved to and restored from persistent storage, such as `UserDefaults`.

To conform to `Storable`, implement these two methods:

- `save()`: Saves the current state.
- `load()`: Restores the saved state.

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

`Persistable` builds on `Storable` to streamline automatic state persistence in `UserDefaults`. By conforming to `Persistable`, state types are automatically assigned a unique key based on their type name, and gain default implementations for saving and loading to `UserDefaults`. This removes the need to manually implement `save()` and `load()`.

To use `Persistable`, simply conform your state to `Persistable` and call the provided `save()` and `load()` methods.

Example:

```swift
struct AppState: Persistable, Equatable {
    var count: Int
    var isLoggedIn: Bool
}

// Saving state
let state = AppState(count: 5, isLoggedIn: true)
state.save()

// Loading state
if let restoredState = AppState.load() {
    print("Restored state: \(restoredState)")
}
```

Using `Persistable` provides a convenient way to persist state with minimal setup, as it requires only `Codable` conformance for encoding and decoding.

## License

This project is licensed under the MIT License. For details, see the [LICENSE](https://github.com/pfriedrix/FlowKit/blob/main/LICENSE) file.

--- 
