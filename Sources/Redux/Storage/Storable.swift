import Foundation

public protocol Storable {
    
    /// Saves the current state to persistent storage.
    ///
    /// This method should handle serializing and storing the current state
    /// in a way that allows it to be restored later.
    func save()
    
    /// Loads the state from persistent storage.
    ///
    /// This method should handle retrieving and deserializing the state from
    /// storage. If no state is found, or if deserialization fails, it should return `nil`.
    ///
    /// - Returns: The loaded state, or `nil` if no valid state is found.
    static func load() -> Self?
}

extension Storable where Self: Codable {
    
    /// Saves the current state to UserDefaults.
    ///
    /// - Parameter key: The key under which the state will be saved.
    @available(*, deprecated, message: "Use the Persistable protocol's save() method without specifying a key.")
    public func save(forKey key: String) {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            Logger.shared.error("Failed to save state: \(error)")
        }
    }
    
    /// Loads the state from UserDefaults.
    ///
    /// - Parameter key: The key under which the state is stored.
    /// - Returns: The loaded state, or `nil` if no valid state is found.
    @available(*, deprecated, message: "Use the Persistable protocol's load() method without specifying a key.")
    public static func load(fromKey key: String) -> Self? {
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
