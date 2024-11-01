---

# FlowKit

This project provides a UDF-like architecture implemented in Swift, designed to manage state in applications effectively. It centralizes the application's state and logic, making the app's behavior predictable and easy to maintain.

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Architecture Overview](#architecture-overview)
4. [Usage](#usage)
   - [Store](#store)
   - [Reducer](#reducer)
   - [Effect](#effect)
   - [Storage](#storage)
6. [License](#license)

## Introduction

This project is inspired by the UDF architecture pattern and implemented in Swift. It is designed to help developers manage state in a centralized and predictable way, improving scalability and simplifying debugging. The core of the system revolves around a central `Store` that holds the app's state, and `Reducers` that specify how state should change in response to actions. Additionally, `Effects` handle asynchronous operations and other side effects.

## Installation

To install this package using Swift Package Manager (SPM):

1. Open your Xcode project.
2. Navigate to `File` > `Add Packages...`.
3. Enter the following URL in the search bar:
   ```
   https://github.com/pfriedrix/Redux
   ```
5. Select the package and choose the version you want to install.
6. Click `Add Package`.

This will integrate the package into your project, allowing you to begin managing state using the Redux architecture in Swift.

## Architecture Overview

The architecture follows a unidirectional data flow, which makes the app's state predictable and easy to debug. The main components are:

- **Store**: The central repository that holds the application's state. The store allows the state to be modified by dispatching actions.
- **Action**: Actions describe events that have occurred, such as user interactions or external inputs like API responses.
- **Reducer**: A pure function that takes the current state and an action as input, modifing the current state in place. It defines how the state transitions happen.
- **Effect**: A component that manages side effects like network requests, I/O operations, or other asynchronous tasks.

## Usage

### Store

The `Store` is the central hub that holds the entire application’s state and manages how state transitions are handled by dispatching actions. It is initialized with an initial state and a reducer that updates the state based on dispatched actions.

Example usage:

```swift
let store = Store(initialState: AppReducer.State(), reducer: AppReducer())
```

### Reducer

The `Reducer` is a pure function that determines how the state should change in response to an action. Reducers take the current state and an action as inputs and return a new state.

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

The `Effect` struct is used for handling side effects, such as asynchronous tasks or external dependencies. It supports operations like sending actions or running async tasks that might result in new actions being dispatched.

Example of using an effect to handle async operations:

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

`Effect` can also send actions directly without async operations:

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

The `Storable` protocol allows the state to be persisted between app sessions. Any state conforming to `Storable` can be saved and restored from persistent storage. This enables long-term storage of application data.

A type that conforms to `Storable` must implement two key methods:

- `save()`: Saves the current state.
- `load()`: Restores the saved state.

Example:

```swift
struct State: Storable {
    var count: Int

    func save() {
        // Save the state
    }

    static func load() -> AppState? {
        // Load and return the saved state
    }
}
```

## License

This project is licensed under the MIT License. See the [LICENSE](https://github.com/pfriedrix/Redux/blob/main/LICENSE) file for details.
