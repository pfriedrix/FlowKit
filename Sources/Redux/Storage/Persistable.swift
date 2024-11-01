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
    /// By default, this key is generated using the type name of the conforming object,
    /// ensuring uniqueness for each type. Override this property if a custom key is needed.
    static var key: String {
        String(describing: Self.self)
    }
    
    /// Saves the current state to `UserDefaults`.
    ///
    /// Encodes the conforming type as `Data` using `JSONEncoder`, and then saves
    /// it to `UserDefaults` under the `key` generated by the type name.
    ///
    /// - Note: Logs an error message if encoding fails.
    public func save() {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            UserDefaults.standard.set(data, forKey: Self.key)
        } catch {
            Logger.shared.error("Failed to save state: \(error)")
        }
    }
    
    /// Loads the state from `UserDefaults`.
    ///
    /// Retrieves data from `UserDefaults` associated with the unique `key` and attempts
    /// to decode it back into the conforming type using `JSONDecoder`.
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
            Logger.shared.error("Failed to load state: \(error)")
            return nil
        }
    }
}
