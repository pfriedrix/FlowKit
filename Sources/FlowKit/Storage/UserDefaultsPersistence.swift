public import Foundation

/// A ``Persistence`` that keeps a `Codable` state as JSON in `UserDefaults`.
///
/// Both the defaults database and the key are chosen by the caller, so the
/// saved data doesn't depend on the name of the state type:
///
/// ```swift
/// let store = Store(
///     reducer: AppReducer(),
///     default: AppState(),
///     persistence: .userDefaults(key: "app")
/// )
/// ```
public struct UserDefaultsPersistence<State: Codable>: Persistence {

    // `UserDefaults` is documented as thread-safe but isn't annotated `Sendable`.
    nonisolated(unsafe) private let defaults: UserDefaults
    private let key: String

    /// Creates a persistence that reads and writes `key` in `defaults`.
    ///
    /// - Parameters:
    ///   - defaults: The defaults database to use. Pass a suite to share state
    ///     with an App Group, or to keep a test away from `UserDefaults.standard`.
    ///   - key: The key the state is saved under.
    public init(_ defaults: UserDefaults = .standard, key: String) {
        self.defaults = defaults
        self.key = key
    }

    /// Loads the state saved under the key.
    ///
    /// On decode failure the saved data is **not** removed. Decode failure is
    /// a normal consequence of type evolution (added field, renamed case) and
    /// callers may want to migrate the stored data rather than lose it. The
    /// next successful ``save(_:)`` overwrites it.
    ///
    /// - Returns: The decoded state, or `nil` if nothing is saved or decoding fails.
    /// - Note: Logs an error message if decoding fails.
    public func load() -> State? {
        guard let data = defaults.data(forKey: key) else { return nil }

        do {
            return try JSONDecoder().decode(State.self, from: data)
        } catch {
            Logger.shared.error("\(key): failed to load state: \(error)")
            return nil
        }
    }

    /// Saves `state` under the key.
    ///
    /// On encoding failure the previously saved data (if any) is left
    /// untouched: losing an encodable value on a transient error would make
    /// recovery impossible.
    ///
    /// - Note: Logs an error message if encoding fails.
    public func save(_ state: State) {
        do {
            let data = try JSONEncoder().encode(state)
            defaults.set(data, forKey: key)
        } catch {
            Logger.shared.error("\(key): failed to save state: \(error)")
        }
    }
}

extension Persistence {

    /// A persistence that keeps a `Codable` state as JSON in `UserDefaults`.
    ///
    /// - Parameters:
    ///   - defaults: The defaults database to use. Defaults to `.standard`.
    ///   - key: The key the state is saved under.
    public static func userDefaults<S: Codable>(
        _ defaults: UserDefaults = .standard,
        key: String
    ) -> Self where Self == UserDefaultsPersistence<S> {
        UserDefaultsPersistence(defaults, key: key)
    }
}
