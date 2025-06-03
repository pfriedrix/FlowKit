/// An attached accessor and member macro that generates dependency injection code for properties
/// in types conforming to `StoreValues`. It extracts the default initializer as the default value.
@attached(accessor)
@attached(peer, names: prefixed(__Store_))
public macro Inject() = #externalMacro(module: "FlowMacros", type: "InjectMacro")
