import Foundation

/// A protocol that enables conforming types to be persisted in `UserDefaults`.
///
/// `Persistable` provides default implementations for saving and loading an object
/// to and from `UserDefaults` using `Codable` conformance. It automatically generates
/// a unique key based on the type name, which is used to store the serialized data.
///
/// Types that conform to `Persistable` should also conform to `Codable`, so that
/// they can be serialized to and deserialized from `Data`.
public protocol Persistable: Storable, Codable { }

extension Persistable {
    
    /// The unique key used for saving and retrieving the state in `UserDefaults`.
    ///
    /// By default, this key is derived from the fully-qualified type name via
    /// `String(reflecting: Self.self)`, which includes the module name — so two
    /// types named `State` in different modules won't collide.
    ///
    /// - Note: `key` is defined in a protocol extension (not a protocol requirement),
    ///   so redeclaring it on a conforming type does NOT override the version used
    ///   by the default `save()`/`load()` implementations below. If you need a custom
    ///   key, provide your own `save()`/`load()` that reads/writes through it.
    static var key: String {
        "\(String(reflecting: Self.self))"
    }
    
    /// Saves the current state to `UserDefaults`.
    ///
    /// Encodes the conforming type as `Data` using `JSONEncoder`, and writes the
    /// result to `UserDefaults` under the type-derived `key`. On encoding failure
    /// the previously persisted blob (if any) is left untouched — losing an
    /// encodable value on a transient error would make recovery impossible.
    ///
    /// - Note: Logs an error message if encoding fails.
    public func save() {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            UserDefaults.standard.set(data, forKey: Self.key)
        } catch {
            Logger.shared.error("\(Self.key): failed to save state: \(error)")
        }
    }

    /// Loads the state from `UserDefaults`.
    ///
    /// Retrieves data from `UserDefaults` associated with the unique `key` and attempts
    /// to decode it back into the conforming type using `JSONDecoder`.
    ///
    /// On decode failure the persisted blob is **not** removed. Decode failure is
    /// a normal consequence of type evolution (added field, renamed case) and callers
    /// may want to migrate the stored data rather than lose it. The next successful
    /// `save()` will overwrite it.
    ///
    /// - Returns: The decoded instance if successful, or `nil` if decoding fails or no
    ///   data is found.
    /// - Note: Logs an error message if decoding fails.
    public static func load() -> Self? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }

        let decoder = JSONDecoder()
        do {
            let state = try decoder.decode(Self.self, from: data)
            return state
        } catch {
            Logger.shared.error("\(Self.key): failed to load state: \(error)")
            return nil
        }
    }
}
