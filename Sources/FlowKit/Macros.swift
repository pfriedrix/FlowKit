/// Generates DI boilerplate for a property on `StoreValues`.
///
/// Apply to a property declared inside `extension StoreValues`. The property
/// must have an explicit type annotation and a default initializer — the
/// initializer expression becomes the `StoreKey.defaultValue`.
///
/// Expansion produces two peer/accessor members:
///
/// 1. A `fileprivate` `StoreKey` struct named `__Store_<propertyName>` whose
///    `@MainActor static let defaultValue` holds the declared initializer.
/// 2. Computed `get`/`set` accessors that read and write through the
///    `StoreValues` subscript using that key.
///
/// **Example:**
///
/// ```swift
/// extension StoreValues {
///     @Inject
///     var myStore: Store<MyReducer> = .init(initial: .init(), reducer: .init())
/// }
/// ```
///
/// Expands to roughly:
///
/// ```swift
/// extension StoreValues {
///     fileprivate struct __Store_myStore: StoreKey {
///         @MainActor static let defaultValue: Store<MyReducer> =
///             .init(initial: .init(), reducer: .init())
///     }
///     var myStore: Store<MyReducer> {
///         get { self[__Store_myStore.self] }
///         set { self[__Store_myStore.self] = newValue }
///     }
/// }
/// ```
///
/// - Note: The `__Store_` prefix is hard-coded in `InjectMacro` and declared
///   here via `prefixed(__Store_)`. Changing one requires changing the other.
@attached(accessor)
@attached(peer, names: prefixed(__Store_))
public macro Inject() = #externalMacro(module: "FlowMacros", type: "InjectMacro")
