/// Records ObjectIdentifier of two @Shared-wrapped Stores at body evaluation time,
/// so tests can assert `@Shared` wrappedValue resolves to identical Store references.
@MainActor
final class SharedIdentityProbe {
    private(set) var identities: (ObjectIdentifier, ObjectIdentifier)? = nil

    func record(_ a: ObjectIdentifier, _ b: ObjectIdentifier) {
        identities = (a, b)
    }
}
