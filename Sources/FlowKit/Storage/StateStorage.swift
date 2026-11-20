/// A place where a store's state is persisted.
///
/// A storage is handed to ``Store/init(reducer:default:storage:)`` by whoever
/// creates the store, so the `State` type itself doesn't need to know where it
/// is kept. Two stores with the same `State` persist independently as long as
/// they are given different storages.
///
/// The store calls a storage like this:
///
/// - ``load()`` once, synchronously, while the store is being initialized.
/// - ``save(_:)`` after every action, on the store's own serial background
///   queue, in the order the actions were reduced. When ``load()`` returned
///   `nil`, the default state is saved once during initialization as well.
///
/// Conforming types must be `Sendable` because ``save(_:)`` runs off the main
/// actor.
///
/// ```swift
/// struct FileStorage<State: Codable>: StateStorage {
///     let url: URL
///
///     func load() -> State? {
///         guard let data = try? Data(contentsOf: url) else { return nil }
///         return try? JSONDecoder().decode(State.self, from: data)
///     }
///
///     func save(_ state: State) {
///         guard let data = try? JSONEncoder().encode(state) else { return }
///         try? data.write(to: url, options: .atomic)
///     }
/// }
/// ```
public protocol StateStorage<State>: Sendable {

    /// The type of state this storage keeps.
    associatedtype State

    /// Loads the previously saved state.
    ///
    /// - Returns: The saved state, or `nil` if nothing was saved or the saved
    ///   data can't be read back.
    func load() -> State?

    /// Saves `state`, replacing whatever was saved before.
    func save(_ state: State)
}
