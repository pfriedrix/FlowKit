import Foundation

/// A protocol that enables conforming types to be persisted in `UserDefaults`.
///
/// `Persistable` provides default implementations for saving and loading an object
/// to and from `UserDefaults.standard` using `Codable` conformance, under a key
/// derived from the type name.
///
/// Deprecated: conform the state to `Codable` and give the store a storage with
/// an explicit key instead. To keep reading data that `Persistable` saved, pass
/// the key it used, which is `String(reflecting:)` of the state type:
///
/// ```swift
/// // before
/// struct AppState: Persistable { ... }
/// Store(reducer: AppReducer(), default: AppState())
///
/// // after
/// struct AppState: Codable { ... }
/// Store(reducer: AppReducer(), default: AppState(), storage: .userDefaults(key: "MyApp.AppState"))
/// ```
@available(*, deprecated, message: "Conform to Codable and pass storage: .userDefaults(key:) to Store(reducer:default:storage:).")
public protocol Persistable: Storable, Codable { }

@available(*, deprecated)
extension Persistable {

    /// The unique key used for saving and retrieving the state in `UserDefaults`.
    ///
    /// This key is derived from the fully-qualified type name via
    /// `String(reflecting: Self.self)`, which includes the module name — so two
    /// types named `State` in different modules won't collide.
    ///
    /// - Note: `key` is defined in a protocol extension (not a protocol requirement),
    ///   so redeclaring it on a conforming type does NOT override the version used
    ///   by the default `save()`/`load()` implementations below.
    static var key: String {
        "\(String(reflecting: Self.self))"
    }

    /// Saves the current state to `UserDefaults.standard` under the type-derived `key`.
    ///
    /// Goes through ``UserDefaultsStorage``, so the stored format and the handling
    /// of encoding failures are the same as for `storage: .userDefaults(key:)`.
    public func save() {
        UserDefaultsStorage<Self>(key: Self.key).save(self)
    }

    /// Loads the state from `UserDefaults.standard` under the type-derived `key`.
    ///
    /// Goes through ``UserDefaultsStorage``, so the stored format and the handling
    /// of decoding failures are the same as for `storage: .userDefaults(key:)`.
    ///
    /// - Returns: The decoded instance if successful, or `nil` if decoding fails or no
    ///   data is found.
    public static func load() -> Self? {
        UserDefaultsStorage<Self>(key: key).load()
    }
}
