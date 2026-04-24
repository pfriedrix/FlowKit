import Foundation
import SwiftCompilerPlugin
public import SwiftSyntax
import SwiftSyntaxBuilder
public import SwiftSyntaxMacros

/// A composite macro that generates dependency injection code for properties in types conforming to `StoreValues`.
///
/// This macro generates two things:
/// 1. A peer member (a store key struct) for the property, which holds the default value for the store.
/// 2. Getter and setter accessors that reference the generated store key struct.
///
/// The macro is attached as both a peer macro and an accessor macro. The generated peer
/// struct is named `__Store_<propertyName>` (the `__Store_` prefix is baked into the macro
/// expansion and must stay in sync with `@attached(peer, names: prefixed(__Store_))` on
/// the public `@Inject` declaration in `Macros.swift`).
///
/// **Example Usage:**
///
/// Given the following property in an extension of `StoreValues`:
///
/// ```swift
/// extension StoreValues {
///     @Inject
///     var myStore: Store<MyReducer> = .init(initial: .init(), reducer: .init())
/// }
/// ```
///
/// The macro will generate a peer member similar to:
///
/// ```swift
/// fileprivate struct __Store_myStore: StoreKey {
///     @MainActor static let defaultValue: Store<MyReducer> = .init(initial: .init(), reducer: .init())
/// }
/// ```
///
/// And computed accessors:
///
/// ```swift
/// var myStore: Store<MyReducer> {
///     get { self[__Store_myStore.self] }
///     set { self[__Store_myStore.self] = newValue }
/// }
/// ```
///
public struct InjectMacro: PeerMacro, AccessorMacro {
    
    // MARK: - Peer Macro: Inject Peer Member
    
    /// Generates a peer member that serves as a store key for the injected property.
    ///
    /// This method extracts the property’s name, type annotation, and default initializer,
    /// and emits a peer `StoreKey` struct named `__Store_<propertyName>`. The `__Store_`
    /// prefix is hardcoded into the emitted source and must match the `prefixed(__Store_)`
    /// entry on the `@attached(peer, ...)` attribute at the `@Inject` declaration site.
    ///
    /// **Example:**
    ///
    /// For a property declared as:
    ///
    /// ```swift
    /// @Inject var myStore: Store<MyReducer> = .init(initial: .init(), reducer: .init())
    /// ```
    ///
    /// This method generates a peer declaration equivalent to:
    ///
    /// ```swift
    /// fileprivate struct __Store_myStore: StoreKey {
    ///     @MainActor static let defaultValue: Store<MyReducer> = .init(initial: .init(), reducer: .init())
    /// }
    /// ```
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self),
              let binding = variableDecl.bindings.first,
              let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self)
        else {
            throw MacroExpansionErrorMessage("'@Inject' must be applied to a property")
        }
        
        let propertyName = identifierPattern.identifier.text
        
        guard let typeAnnotation = binding.typeAnnotation?.type else {
            throw MacroExpansionErrorMessage("'@Inject' property must have an explicit type annotation")
        }
        
        let storeTypeString = typeAnnotation.description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let initializerExpr = binding.initializer?.value else {
            throw MacroExpansionErrorMessage("'@Inject' property must have a default initializer")
        }
        
        let key = "__Store_\(propertyName)"
        let storeKeyStructSource = """
    fileprivate struct \(key): StoreKey {
        @MainActor static let defaultValue: \(storeTypeString) = \(initializerExpr)
    }
    """
        
        return [DeclSyntax(stringLiteral: storeKeyStructSource)]
    }
    
    // MARK: - Accessor Macro: Generate Getter/Setter
    
    /// Generates getter and setter accessors for the injected property.
    ///
    /// These accessors reference the `__Store_<propertyName>` peer struct emitted by
    /// the peer-macro expansion above.
    ///
    /// **Example:**
    ///
    /// For a property `myStore`, the generated accessors will be:
    ///
    /// ```
    /// get {
    ///     self[__Store_myStore.self]
    /// }
    /// set {
    ///     self[__Store_myStore.self] = newValue
    /// }
    /// ```
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self),
              let binding = variableDecl.bindings.first,
              let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self)
        else {
            throw MacroExpansionErrorMessage("'@Inject' must be applied to a property")
        }
        
        let propertyName = identifierPattern.identifier.text
        
        let key = "__Store_\(propertyName)"
        
        let getterSource = """
    get {
        self[\(key).self]
    }
    """
        
        let setterSource = """
    set {
        self[\(key).self] = newValue
    }
    """
        
        return [
            AccessorDeclSyntax(stringLiteral: getterSource),
            AccessorDeclSyntax(stringLiteral: setterSource)
        ]
    }
}
