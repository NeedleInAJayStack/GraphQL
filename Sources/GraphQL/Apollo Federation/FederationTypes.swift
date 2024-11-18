import NIO

// FIXME: Pass in ELG
let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

let EntityType = try! GraphQLUnionType(
    name: "_Entity",
    types: []
)

func serviceType(sdl: String) -> GraphQLObjectType {
    return try! GraphQLObjectType(
        name: "_Service",
        fields: [
            "sdl": .init(
                type: GraphQLString,
                description:
                "The sdl representing the federated service capabilities. Includes federation directives, removes federation types, and includes rest of full schema after schema directives have been applied",
                resolve: {_, _, _, _ in
                    return sdl
                }
            ),
        ]
    )
}

let ServiceType = try! GraphQLObjectType(
    name: "_Service",
    fields: [
        "sdl": .init(
            type: GraphQLString,
            description:
            "The sdl representing the federated service capabilities. Includes federation directives, removes federation types, and includes rest of full schema after schema directives have been applied"
        ),
    ]
)

let AnyType = try! GraphQLScalarType(
    name: "_Any",
    serialize: { value in
        try .init(any: value)
    }
)

let LinkImportType = try! GraphQLScalarType(
    name: "link__Import",
    specifiedByURL: nil
)

//func maybeAddTypeNameToPossibleReturn(
//    maybeObject: Map,
//    typename: String
//) -> Map {
//    var objectOrNull = maybeObject
//    if
//        objectOrNull != .null,
//        let object = objectOrNull.dictionary
//    {
//        // If the object already has a __typename assigned, we're "refining" the
//        // type from an interface to an interfaceObject.
//        if let __typename = object["__typename"]?.string, __typename != typename {
//            objectOrNull["__typename"] = .string(typename)
//        }
//    }
//    return objectOrNull
//}
//
///**
// * Copied and adapted from GraphQL-js to provide more tailored error messages (but the equivalent method is also not exported
// * by `graphql-js`).
// *
// * For @key on interfaces, we need to check that we can resolve the runtime type of the object returned by the interface
// * `__resolveReference`. If we cannot, and we simply don't add any `__typename` to the result, the graphQL-js will end
// * erroring out, but the error will not be user friendly as it will say something along the lines of:
// * ```
// *   Abstract type "_Entity" must resolve to an Object type at runtime for field "Query._entities". Either the "_Entity" type
// *   should provide a "resolveType" function or each possible type should provide an "isTypeOf" function.
// * ```
// * But this is ultimately incorrect, as it is only interface type the user must use "resolveType", add a __typename, or rely
// * on "isTypeOf". And so we have to somewhat copy and adapt the logic slightly (mostly to provide a more user friendly method).
// */
//func ensureValidRuntimeType(
//    runtimeTypeName: Any?,
//    schema: GraphQLSchema,
//    returnType: GraphQLAbstractType,
//    result: Any
//) throws -> GraphQLObjectType {
//    guard let runtimeTypeName else {
//        throw GraphQLError(
//            message: "Abstract type \"\(returnType.name)\" `__resolveReference` method must resolve to an Object type at runtime. Either the object returned by \"\(returnType).__resolveReference\" must include a valid `__typename` field, or the \"\(returnType.name)\" type should provide a \"resolveType\" function or each possible type should provide an \"isTypeOf\" function."
//        )
//    }
//
//    guard let runtimeTypeName = runtimeTypeName as? String else {
//        throw GraphQLError(
//            message: "Abstract type \"\(returnType.name)\" `__resolveReference` method must resolve to an Object type at runtime with value \(print(result)), received \"\(print(runtimeTypeName))\"."
//        )
//    }
//
//    let runtimeType = schema.getType(name: runtimeTypeName)
//    if runtimeType == nil {
//        throw GraphQLError(
//            message: "Abstract type \"\(returnType.name)\" `__resolveReference` method resolved to a type \"\(runtimeTypeName)\" that does not exist inside the schema."
//        )
//    }
//
//    guard let runtimeType = runtimeType as? GraphQLObjectType else {
//        throw GraphQLError(
//            message: "Abstract type \"\(returnType.name)\" `__resolveReference` method resolved to a non-object type \"\(runtimeTypeName)\"."
//        )
//    }
//
//    if !schema.isSubType(abstractType: returnType, maybeSubType: runtimeType) {
//        throw GraphQLError(
//            message: "Runtime Object type \"\(runtimeType.name)\" `__resolveReference` method is not a possible type for \"\(returnType.name)\"."
//        )
//    }
//
//    return runtimeType
//}
//
//func withResolvedType(
//    type: GraphQLInterfaceType,
//    value: Any,
//    context _: Any,
//    info: GraphQLResolveInfo,
//    callback: (_ runtimeType: GraphQLObjectType) -> Map
//) throws -> Map {
//    var runtimeType = try type.resolveType?(value, eventLoopGroup, info).typeResolveResult
//    runtimeType = try runtimeType ?? defaultResolveType(
//        value: value,
//        eventLoopGroup: eventLoopGroup,
//        info: info,
//        abstractType: type
//    )
//    return try callback(ensureValidRuntimeType(
//        runtimeTypeName: runtimeType,
//        schema: info.schema,
//        returnType: type,
//        result: value
//    ))
//}
//
//func definedResolveReference(type: GraphQLObjectType) -> GraphQLReferenceResolver? {
//    let extensions: ApolloGraphQLObjectTypeExtensions = type.extensions
//    return extensions.apollo?.subgraph?.resolveReference
//}
//
//func definedResolveReference(type: GraphQLInterfaceType) -> GraphQLReferenceResolver? {
//    let extensions: ApolloGraphQLInterfaceTypeExtensions = type.extensions
//    return extensions.apollo?.subgraph?.resolveReference
//}
//
//func entitiesResolver(
//    _ representations: Map,
//    _ context: Any,
//    _ info: GraphQLResolveInfo
//) {
//    return representations.arrayValue().map { reference in
//        guard let __typename = reference["__typename"].string else {
//            throw GraphQLError(
//                message: "The _entities resolver tried to load an entity that was missing a `__typename`"
//            )
//        }
//
//        let type = info.schema.getType(name: __typename)
//        let objectType = type as? GraphQLObjectType
//        let interfaceType = type as? GraphQLInterfaceType
//
//        let resolveReference: GraphQLReferenceResolver?
//        if let objectType {
//            resolveReference = definedResolveReference(type: objectType)
//        } else if let interfaceType {
//            resolveReference = definedResolveReference(type: interfaceType)
//        } else {
//            throw GraphQLError(
//                message: "The _entities resolver tried to load an entity for type \"\(__typename)\", but no object or interface type of that name was found in the schema"
//            )
//        }
//
//        let result: Any
//        if let resolveReference {
//            result = try resolveReference(reference, context, info)
//        } else {
//            result = reference
//        }
//
//        if let interfaceType {
//            return withResolvedType(
//                type: interfaceType,
//                value: result,
//                context: context,
//                info: info,
//                callback: { runtimeType in
//                    // If we had no interface-level __resolveReference, then we look for one on
//                    // the runtime
//                    // type itself, and call it if it exists. If that one also doesn't, we
//                    // essentially end
//                    // up using the same resolver than for object types, one that does nothing.
//                    let finalResult = maybeAddTypeNameToPossibleReturn(result, runtimeType.name)
//                    if !resolveReference {
//                        let runtimeResolveReference = definedResolveReference(runtimeType)
//                        if runtimeResolveReference {
//                            // Note that we call the resolver on the reference with the "proper"
//                            // __typename,
//                            // and then add back the __typename again in case the resolver
//                            // removed it (which
//                            // ultimately is the behaviour we use with object type
//                            // __resolveReference in
//                            // general).
//                            finalResult = runtimeResolveReference(finalResult, context, info)
//                            finalResult = maybeAddTypeNameToPossibleReturn(
//                                finalResult,
//                                runtimeType.name
//                            )
//                        }
//                    }
//                    return finalResult
//                }
//            )
//        }
//
//        return maybeAddTypeNameToPossibleReturn(result, __typename)
//    }
//}

//let entitiesField = GraphQLField(
//    type: GraphQLNonNull(GraphQLList(EntityType)),
//    args: [
//        "representations": .init(
//            type: GraphQLNonNull(GraphQLList(GraphQLNonNull(AnyType)))
//        ),
//    ],
//    resolve: { _, args, context, info in
//        entitiesResolver(args["representations"], context, info)
//    }
//)

let serviceField = GraphQLField(
    type: GraphQLNonNull(ServiceType)
)

let federationTypes: [GraphQLNamedType] = [
    ServiceType,
    AnyType,
    EntityType,
    LinkImportType,
]

func isFederationType(type: GraphQLType) -> Bool {
    guard let type = type as? GraphQLNamedType else { return false }
    return federationTypes.contains { $0.name == type.name }
}
