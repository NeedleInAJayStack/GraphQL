import OrderedCollections

/**
 * Produces a new schema given an existing schema and a document which may
 * contain GraphQL type extensions and definitions. The original schema will
 * remain unaltered.
 *
 * Because a schema represents a graph of references, a schema cannot be
 * extended without effectively making an entire copy. We do not know until it's
 * too late if subgraphs remain unchanged.
 *
 * This algorithm copies the provided schema, applying extensions while
 * producing the copy. The original schema remains unaltered.
 */
public func extendSchema(
    schema: GraphQLSchema,
    documentAST: Document,
    assumeValid: Bool = false,
    assumeValidSDL: Bool = false
) throws -> GraphQLSchema {
    if !assumeValid, !assumeValidSDL {
        try assertValidSDLExtension(documentAST: documentAST, schema: schema)
    }

    let schemaConfig = schema.toConfig()
    let extendedConfig = try extendSchemaImpl(schemaConfig, documentAST, assumeValid)

    return try GraphQLSchema(config: extendedConfig)
//    return schemaConfig == extendedConfig
//        ? schema
//        : GraphQLSchema(config: extendedConfig)
}

func extendSchemaImpl(
    _ schemaConfig: GraphQLSchemaNormalizedConfig,
    _ documentAST: Document,
    _ assumeValid: Bool = false
) throws -> GraphQLSchemaNormalizedConfig {
    // Collect the type definitions and extensions found in the document.
    var typeDefs = [TypeDefinition]()

    var scalarExtensions = [String: [ScalarExtensionDefinition]]()
    var objectExtensions = [String: [TypeExtensionDefinition]]()
    var interfaceExtensions = [String: [InterfaceExtensionDefinition]]()
    var unionExtensions = [String: [UnionExtensionDefinition]]()
    var enumExtensions = [String: [EnumExtensionDefinition]]()
    var inputObjectExtensions = [String: [InputObjectExtensionDefinition]]()

    // New directives and types are separate because a directives and types can
    // have the same name. For example, a type named "skip".
    var directiveDefs = [DirectiveDefinition]()

    var schemaDef: SchemaDefinition? = nil
    // Schema extensions are collected which may add additional operation types.
    var schemaExtensions = [SchemaExtensionDefinition]()

    var isSchemaChanged = false
    for def in documentAST.definitions {
        switch def.kind {
        case .schemaDefinition:
            schemaDef = (def as! SchemaDefinition)
        case .schemaExtensionDefinition:
            schemaExtensions.append(def as! SchemaExtensionDefinition)
        case .directiveDefinition:
            directiveDefs.append(def as! DirectiveDefinition)

        // Type Definitions
        case
            .scalarTypeDefinition,
            .objectTypeDefinition,
            .interfaceTypeDefinition,
            .unionTypeDefinition,
            .enumTypeDefinition,
            .inputObjectTypeDefinition
            :
            typeDefs.append(def as! TypeDefinition)

        // Type System Extensions
        case .scalarExtensionDefinition:
            let def = def as! ScalarExtensionDefinition
            scalarExtensions[def.definition.name.value] = [def]
        case .typeExtensionDefinition:
            let def = def as! TypeExtensionDefinition
            objectExtensions[def.definition.name.value] = [def]
        case .interfaceExtensionDefinition:
            let def = def as! InterfaceExtensionDefinition
            interfaceExtensions[def.definition.name.value] = [def]
        case .unionExtensionDefinition:
            let def = def as! UnionExtensionDefinition
            unionExtensions[def.definition.name.value] = [def]
        case .enumExtensionDefinition:
            let def = def as! EnumExtensionDefinition
            enumExtensions[def.definition.name.value] = [def]
        case .inputObjectExtensionDefinition:
            let def = def as! InputObjectExtensionDefinition
            inputObjectExtensions[def.definition.name.value] = [def]
        default:
            continue
        }
        isSchemaChanged = true
    }

    // If this document contains no new types, extensions, or directives then
    // return the same unmodified GraphQLSchema instance.
    if !isSchemaChanged {
        return schemaConfig
    }

    var typeMap = OrderedDictionary<String, GraphQLNamedType>()
    for type in schemaConfig.types {
        typeMap[type.name] = try extendNamedType(type)
    }

    for typeNode in typeDefs {
        let name = typeNode.name.value
        typeMap[name] = try stdTypeMap[name] ?? buildType(astNode: typeNode)
    }

    // Get the extended root operation types.
    var query = schemaConfig.query.map { replaceNamedType($0) }
    var mutation = schemaConfig.mutation.map { replaceNamedType($0) }
    var subscription = schemaConfig.subscription.map { replaceNamedType($0) }
    // Then, incorporate schema definition and all schema extensions.
    if let schemaDef = schemaDef {
        let schemaOperations = try getOperationTypes(nodes: [schemaDef])
        if let schemaQuery = schemaOperations.query {
            query = schemaQuery
        }
        if let schemaMutation = schemaOperations.mutation {
            mutation = schemaMutation
        }
        if let schemaSubscription = schemaOperations.subscription {
            subscription = schemaSubscription
        }
    }
    let extensionOperations = try getOperationTypes(nodes: schemaExtensions)
    if let extensionQuery = extensionOperations.query {
        query = extensionQuery
    }
    if let extensionMutation = extensionOperations.mutation {
        mutation = extensionMutation
    }
    if let extensionSubscription = extensionOperations.subscription {
        subscription = extensionSubscription
    }

    var extensionASTNodes = schemaConfig.extensionASTNodes
    extensionASTNodes.append(contentsOf: schemaExtensions)

    var directives = [GraphQLDirective]()
    for directive in schemaConfig.directives {
        try directives.append(replaceDirective(directive))
    }
    for directive in directiveDefs {
        try directives.append(buildDirective(node: directive))
    }
    // Then, incorporate schema definition and all schema extensions.
    return GraphQLSchemaNormalizedConfig(
        description: schemaDef?.description?.value ?? schemaConfig.description,
        query: query,
        mutation: mutation,
        subscription: subscription,
        types: Array(typeMap.values),
        directives: directives,
        extensions: schemaConfig.extensions,
        astNode: schemaDef ?? schemaConfig.astNode,
        extensionASTNodes: extensionASTNodes,
        assumeValid: assumeValid
    )

    // Below are functions used for producing this schema that have closed over
    // this scope and have access to the schema, cache, and newly defined types.

    func replaceType<T: GraphQLType>(_ type: T) -> T {
        if let type = type as? GraphQLList {
            return GraphQLList(replaceType(type.ofType)) as! T
        }
        if let type = type as? GraphQLNonNull {
            return GraphQLNonNull(replaceType(type.ofType)) as! T
        }
        if let type = type as? GraphQLNamedType {
            return replaceNamedType(type) as! T
        }
        return type
    }

    func replaceNamedType<T: GraphQLNamedType>(_ type: T) -> T {
        // Note: While this could make early assertions to get the correctly
        // typed values, that would throw immediately while type system
        // validation with validateSchema() will produce more actionable results.
        return typeMap[type.name] as! T
    }

    func replaceDirective(_ directive: GraphQLDirective) throws -> GraphQLDirective {
        if isSpecifiedDirective(directive) {
            // Builtin directives are not extended.
            return directive
        }

        return try GraphQLDirective(
            name: directive.name,
            description: directive.description,
            locations: directive.locations,
            args: directive.argConfigMap().mapValues { arg in extendArg(arg) },
            isRepeatable: directive.isRepeatable
        )
    }

    func extendNamedType(_ type: GraphQLNamedType) throws -> GraphQLNamedType {
        if isIntrospectionType(type: type) || isSpecifiedScalarType(type) {
            // Builtin types are not extended.
            return type
        }
        if let type = type as? GraphQLScalarType {
            return try extendScalarType(type)
        }
        if let type = type as? GraphQLObjectType {
            return try extendObjectType(type)
        }
        if let type = type as? GraphQLInterfaceType {
            return try extendInterfaceType(type)
        }
        if let type = type as? GraphQLUnionType {
            return try extendUnionType(type)
        }
        if let type = type as? GraphQLEnumType {
            return try extendEnumType(type)
        }
        if let type = type as? GraphQLInputObjectType {
            return try extendInputObjectType(type)
        }

        // Not reachable, all possible type definition nodes have been considered.
        throw GraphQLError(message: "Unexpected type: \(type.name)")
    }

    func extendInputObjectType(
        _ type: GraphQLInputObjectType
    ) throws -> GraphQLInputObjectType {
        let extensions = inputObjectExtensions[type.name] ?? []

        let fields = try type.fields.mapValues { field in
            InputObjectField(
                type: replaceType(field.type),
                defaultValue: field.defaultValue,
                description: field.description,
                deprecationReason: field.deprecationReason
            )
        }.merging(buildInputFieldMap(nodes: extensions)) { $1 }

        return try GraphQLInputObjectType(
            name: type.name,
            description: type.description,
            fields: fields
        )
    }

    func extendEnumType(_ type: GraphQLEnumType) throws -> GraphQLEnumType {
        let extensions = enumExtensions[type.name] ?? []
        var values = GraphQLEnumValueMap()
        for value in type.values {
            values[value.name] = GraphQLEnumValue(
                value: value.value,
                description: value.description,
                deprecationReason: value.deprecationReason
            )
        }
        for (name, value) in try buildEnumValueMap(nodes: extensions) {
            values[name] = value
        }

        return try GraphQLEnumType(
            name: type.name,
            description: type.description,
            values: values
        )
    }

    // Not implemented due to lack of `specifiedByURL`
    func extendScalarType(_ type: GraphQLScalarType) throws -> GraphQLScalarType {
        let extensions = scalarExtensions[type.name] ?? []
        var specifiedByURL = type.specifiedByURL
        for extensionNode in extensions {
            specifiedByURL = try getSpecifiedByURL(node: extensionNode) ?? specifiedByURL
        }

        return try GraphQLScalarType(
            name: type.name,
            description: type.description,
            specifiedByURL: specifiedByURL,
            serialize: type.serialize,
            parseValue: type.parseValue,
            parseLiteral: type.parseLiteral
        )
    }

    func extendObjectType(_ type: GraphQLObjectType) throws -> GraphQLObjectType {
        let extensions = objectExtensions[type.name] ?? []
        var interfaces = type.interfaces.map { interface in
            replaceNamedType(interface)
        }
        try interfaces.append(contentsOf: buildInterfaces(nodes: extensions))
        let fields = try type.fields.mapValues { field in
            extendField(field.toField())
        }.merging(buildFieldMap(nodes: extensions)) { $1 }

        return try GraphQLObjectType(
            name: type.name,
            description: type.description,
            fields: fields,
            interfaces: interfaces,
            isTypeOf: type.isTypeOf
        )
    }

    func extendInterfaceType(_ type: GraphQLInterfaceType) throws -> GraphQLInterfaceType {
        let extensions = interfaceExtensions[type.name] ?? []
        var interfaces = type.interfaces.map { interface in
            replaceNamedType(interface)
        }
        try interfaces.append(contentsOf: buildInterfaces(nodes: extensions))
        let fields = try type.fields.mapValues { field in
            extendField(field.toField())
        }.merging(buildFieldMap(nodes: extensions)) { $1 }

        return try GraphQLInterfaceType(
            name: type.name,
            description: type.description,
            interfaces: interfaces,
            fields: fields,
            resolveType: type.resolveType
        )
    }

    func extendUnionType(_ type: GraphQLUnionType) throws -> GraphQLUnionType {
        let extensions = unionExtensions[type.name] ?? []
        var types = type.types.map { type in
            replaceNamedType(type)
        }
        try types.append(contentsOf: buildUnionTypes(nodes: extensions))

        return try GraphQLUnionType(
            name: type.name,
            description: type.description,
            resolveType: type.resolveType,
            types: types
        )
    }

    func extendField(_ field: GraphQLField) -> GraphQLField {
        let args = field.args.merging(field.args.mapValues { extendArg($0) }) { $1 }
        return GraphQLField(
            type: replaceType(field.type),
            description: field.description,
            deprecationReason: field.deprecationReason,
            args: args,
            resolve: field.resolve,
            subscribe: field.subscribe
        )
    }

    func extendArg(_ arg: GraphQLArgument) -> GraphQLArgument {
        return GraphQLArgument(
            type: replaceType(arg.type),
            description: arg.description,
            defaultValue: arg.defaultValue,
            deprecationReason: arg.deprecationReason
        )
    }

    struct OperationTypes {
        let query: GraphQLObjectType?
        let mutation: GraphQLObjectType?
        let subscription: GraphQLObjectType?
    }

    func getOperationTypes(
        nodes: [SchemaDefinition]
    ) throws -> OperationTypes {
        var query: GraphQLObjectType? = nil
        var mutation: GraphQLObjectType? = nil
        var subscription: GraphQLObjectType? = nil
        for node in nodes {
            let operationTypesNodes = node.operationTypes

            for operationType in operationTypesNodes {
                // Note: While this could make early assertions to get the correctly
                // typed values below, that would throw immediately while type system
                // validation with validateSchema() will produce more actionable results.
                switch operationType.operation {
                case .query:
                    query = try getNamedType(operationType.type) as? GraphQLObjectType
                case .mutation:
                    mutation = try getNamedType(operationType.type) as? GraphQLObjectType
                case .subscription:
                    subscription = try getNamedType(operationType.type) as? GraphQLObjectType
                }
            }
        }

        return OperationTypes(query: query, mutation: mutation, subscription: subscription)
    }

    func getOperationTypes(
        nodes: [SchemaExtensionDefinition]
    ) throws -> OperationTypes {
        var query: GraphQLObjectType? = nil
        var mutation: GraphQLObjectType? = nil
        var subscription: GraphQLObjectType? = nil
        for node in nodes {
            let operationTypesNodes = node.definition.operationTypes

            for operationType in operationTypesNodes {
                // Note: While this could make early assertions to get the correctly
                // typed values below, that would throw immediately while type system
                // validation with validateSchema() will produce more actionable results.
                switch operationType.operation {
                case .query:
                    query = try getNamedType(operationType.type) as? GraphQLObjectType
                case .mutation:
                    mutation = try getNamedType(operationType.type) as? GraphQLObjectType
                case .subscription:
                    subscription = try getNamedType(operationType.type) as? GraphQLObjectType
                }
            }
        }

        return OperationTypes(query: query, mutation: mutation, subscription: subscription)
    }

    func getNamedType(_ node: NamedType) throws -> GraphQLNamedType {
        let name = node.name.value
        let type = stdTypeMap[name] ?? typeMap[name]

        guard let type = type else {
            throw GraphQLError(message: "Unknown type: \"\(name)\".")
        }
        return type
    }

    func getWrappedType(_ node: Type) throws -> GraphQLType {
        if let node = node as? ListType {
            return try GraphQLList(getWrappedType(node.type))
        }
        if let node = node as? NonNullType {
            return try GraphQLNonNull(getWrappedType(node.type))
        }
        if let node = node as? NamedType {
            return try getNamedType(node)
        }
        throw GraphQLError(
            message: "No type wrapped"
        )
    }

    func buildDirective(node: DirectiveDefinition) throws -> GraphQLDirective {
        return try GraphQLDirective(
            name: node.name.value,
            description: node.description?.value ?? "",
            locations: node.locations.compactMap { DirectiveLocation(rawValue: $0.value) },
            args: buildArgumentMap(node.arguments),
            isRepeatable: node.repeatable
        )
    }

    func buildFieldMap(
        nodes: [InterfaceTypeDefinition]
    ) throws -> GraphQLFieldMap {
        var fieldConfigMap = GraphQLFieldMap()
        for node in nodes {
            for field in node.fields {
                guard let type = try getWrappedType(field.type) as? GraphQLOutputType else {
                    throw GraphQLError(message: "Expected GraphQLOutputType")
                }

                fieldConfigMap[field.name.value] = try .init(
                    type: type,
                    description: field.description?.value,
                    deprecationReason: getDeprecationReason(field),
                    args: buildArgumentMap(field.arguments),
                    astNode: field
                )
            }
        }
        return fieldConfigMap
    }

    func buildFieldMap(
        nodes: [InterfaceExtensionDefinition]
    ) throws -> GraphQLFieldMap {
        var fieldConfigMap = GraphQLFieldMap()
        for node in nodes {
            for field in node.definition.fields {
                guard let type = try getWrappedType(field.type) as? GraphQLOutputType else {
                    throw GraphQLError(message: "Expected GraphQLOutputType")
                }

                fieldConfigMap[field.name.value] = try .init(
                    type: type,
                    description: field.description?.value,
                    deprecationReason: getDeprecationReason(field),
                    args: buildArgumentMap(field.arguments),
                    astNode: field
                )
            }
        }
        return fieldConfigMap
    }

    func buildFieldMap(
        nodes: [ObjectTypeDefinition]
    ) throws -> GraphQLFieldMap {
        var fieldConfigMap = GraphQLFieldMap()
        for node in nodes {
            for field in node.fields {
                guard let type = try getWrappedType(field.type) as? GraphQLOutputType else {
                    throw GraphQLError(message: "Expected GraphQLOutputType")
                }

                fieldConfigMap[field.name.value] = try .init(
                    type: type,
                    description: field.description?.value,
                    deprecationReason: getDeprecationReason(field),
                    args: buildArgumentMap(field.arguments),
                    astNode: field
                )
            }
        }
        return fieldConfigMap
    }

    func buildFieldMap(
        nodes: [TypeExtensionDefinition]
    ) throws -> GraphQLFieldMap {
        var fieldConfigMap = GraphQLFieldMap()
        for node in nodes {
            for field in node.definition.fields {
                guard let type = try getWrappedType(field.type) as? GraphQLOutputType else {
                    throw GraphQLError(message: "Expected GraphQLOutputType")
                }

                fieldConfigMap[field.name.value] = try .init(
                    type: type,
                    description: field.description?.value,
                    deprecationReason: getDeprecationReason(field),
                    args: buildArgumentMap(field.arguments),
                    astNode: field
                )
            }
        }
        return fieldConfigMap
    }

    func buildArgumentMap(
        _ args: [InputValueDefinition]?
    ) throws -> GraphQLArgumentConfigMap {
        let argsNodes = args ?? []

        var argConfigMap = GraphQLArgumentConfigMap()
        for arg in argsNodes {
            guard let type = try getWrappedType(arg.type) as? GraphQLInputType else {
                throw GraphQLError(message: "type is not input type: \(arg.type)")
            }

            argConfigMap[arg.name.value] = try GraphQLArgument(
                type: type,
                description: arg.description?.value,
                defaultValue: arg.defaultValue.map { try valueFromAST(valueAST: $0, type: type) },
                deprecationReason: getDeprecationReason(arg)
            )
        }
        return argConfigMap
    }

    func buildInputFieldMap(
        nodes: [InputObjectTypeDefinition]
    ) throws -> InputObjectFieldMap {
        var inputFieldMap = InputObjectFieldMap()
        for node in nodes {
            for field in node.fields {
                // Note: While this could make assertions to get the correctly typed
                // value, that would throw immediately while type system validation
                // with validateSchema() will produce more actionable results.
                let type = try getWrappedType(field.type)
                guard let type = type as? GraphQLInputType else {
                    throw GraphQLError(message: "Expected GraphQLInputType")
                }

                inputFieldMap[field.name.value] = try .init(
                    type: type,
                    defaultValue: field.defaultValue
                        .map { try valueFromAST(valueAST: $0, type: type) },
                    description: field.description?.value,
                    deprecationReason: getDeprecationReason(field),
                    astNode: field
                )
            }
        }
        return inputFieldMap
    }

    func buildInputFieldMap(
        nodes: [InputObjectExtensionDefinition]
    ) throws -> InputObjectFieldMap {
        var inputFieldMap = InputObjectFieldMap()
        for node in nodes {
            for field in node.definition.fields {
                // Note: While this could make assertions to get the correctly typed
                // value, that would throw immediately while type system validation
                // with validateSchema() will produce more actionable results.
                let type = try getWrappedType(field.type)
                guard let type = type as? GraphQLInputType else {
                    throw GraphQLError(message: "Expected GraphQLInputType")
                }

                inputFieldMap[field.name.value] = try .init(
                    type: type,
                    defaultValue: field.defaultValue
                        .map { try valueFromAST(valueAST: $0, type: type) },
                    description: field.description?.value,
                    deprecationReason: getDeprecationReason(field),
                    astNode: field
                )
            }
        }
        return inputFieldMap
    }

    func buildEnumValueMap(
        nodes: [EnumTypeDefinition] // | EnumTypeExtension],
    ) throws -> GraphQLEnumValueMap {
        var enumValueMap = GraphQLEnumValueMap()
        for node in nodes {
            var valuesNodes = node.values

            for value in valuesNodes {
                enumValueMap[value.name.value] = try GraphQLEnumValue(
                    value: .string(value.name.value),
                    description: value.description?.value,
                    deprecationReason: getDeprecationReason(value)
                )
            }
        }
        return enumValueMap
    }

    func buildEnumValueMap(
        nodes: [EnumExtensionDefinition]
    ) throws -> GraphQLEnumValueMap {
        var enumValueMap = GraphQLEnumValueMap()
        for node in nodes {
            var valuesNodes = node.definition.values

            for value in valuesNodes {
                enumValueMap[value.name.value] = try GraphQLEnumValue(
                    value: .string(value.name.value),
                    description: value.description?.value,
                    deprecationReason: getDeprecationReason(value)
                )
            }
        }
        return enumValueMap
    }

    func buildInterfaces(
        nodes: [ObjectTypeDefinition]
    ) throws -> [GraphQLInterfaceType] {
        return try nodes.flatMap { node in
            try node.interfaces.compactMap { type in
                try getNamedType(type) as? GraphQLInterfaceType
            }
        }
    }

    func buildInterfaces(
        nodes: [TypeExtensionDefinition]
    ) throws -> [GraphQLInterfaceType] {
        return try nodes.flatMap { node in
            try node.definition.interfaces.compactMap { type in
                try getNamedType(type) as? GraphQLInterfaceType
            }
        }
    }

    func buildInterfaces(
        nodes: [InterfaceTypeDefinition]
    ) throws -> [GraphQLInterfaceType] {
        return try nodes.flatMap { node in
            try node.interfaces.compactMap { type in
                try getNamedType(type) as? GraphQLInterfaceType
            }
        }
    }

    func buildInterfaces(
        nodes: [InterfaceExtensionDefinition]
    ) throws -> [GraphQLInterfaceType] {
        return try nodes.flatMap { node in
            try node.definition.interfaces.compactMap { type in
                try getNamedType(type) as? GraphQLInterfaceType
            }
        }
    }

    func buildUnionTypes(
        nodes: [UnionTypeDefinition]
    ) throws -> [GraphQLObjectType] {
        return try nodes.flatMap { node in
            try node.types.compactMap { type in
                try getNamedType(type) as? GraphQLObjectType
            }
        }
    }

    func buildUnionTypes(
        nodes: [UnionExtensionDefinition]
    ) throws -> [GraphQLObjectType] {
        return try nodes.flatMap { node in
            try node.definition.types.compactMap { type in
                try getNamedType(type) as? GraphQLObjectType
            }
        }
    }

    func buildType(astNode: TypeDefinition) throws -> GraphQLNamedType {
        let name = astNode.name.value

        switch astNode.kind {
        case Kind.objectTypeDefinition:
            let extensionASTNodes = objectExtensions[name] ?? []
            guard let node = astNode as? ObjectTypeDefinition else {
                throw GraphQLError(message: "Expected ObjectTypeDefinition", locations: [])
            }
            var interfaces = try buildInterfaces(nodes: [node])
            try interfaces.append(contentsOf: buildInterfaces(nodes: extensionASTNodes))

            var fields = try buildFieldMap(nodes: [node])
            for (name, value) in try buildFieldMap(nodes: extensionASTNodes) {
                fields[name] = value
            }

            return try GraphQLObjectType(
                name: name,
                description: node.description?.value,
                fields: fields,
                interfaces: interfaces,
                astNode: node,
                extensionASTNodes: extensionASTNodes
            )
        case Kind.interfaceTypeDefinition:
            let extensionASTNodes = interfaceExtensions[name] ?? []
            guard let node = astNode as? InterfaceTypeDefinition else {
                throw GraphQLError(message: "Expected InterfaceTypeDefinition", locations: [])
            }
            var interfaces = try buildInterfaces(nodes: [node])
            try interfaces.append(contentsOf: buildInterfaces(nodes: extensionASTNodes))

            var fields = try buildFieldMap(nodes: [node])
            for (name, value) in try buildFieldMap(nodes: extensionASTNodes) {
                fields[name] = value
            }

            return try GraphQLInterfaceType(
                name: name,
                description: node.description?.value,
                interfaces: interfaces,
                fields: fields,
                astNode: node,
                extensionASTNodes: extensionASTNodes
            )
        case Kind.enumTypeDefinition:
            let extensionASTNodes = enumExtensions[name] ?? []
            guard let node = astNode as? EnumTypeDefinition else {
                throw GraphQLError(message: "Expected EnumTypeDefinition", locations: [])
            }
            var enumValues = try buildEnumValueMap(nodes: [node])
            for (name, value) in try buildEnumValueMap(nodes: extensionASTNodes) {
                enumValues[name] = value
            }

            return try GraphQLEnumType(
                name: name,
                description: node.description?.value,
                values: enumValues,
                astNode: node,
                extensionASTNodes: extensionASTNodes
            )
        case Kind.unionTypeDefinition:
            let extensionASTNodes = unionExtensions[name] ?? []
            guard let node = astNode as? UnionTypeDefinition else {
                throw GraphQLError(message: "Expected UnionTypeDefinition", locations: [])
            }
            var unionTypes = try buildUnionTypes(nodes: [node])
            try unionTypes.append(contentsOf: buildUnionTypes(nodes: extensionASTNodes))

            return try GraphQLUnionType(
                name: name,
                description: node.description?.value,
                types: unionTypes,
                astNode: node,
                extensionASTNodes: extensionASTNodes
            )
        case Kind.scalarTypeDefinition:
            let extensionASTNodes = scalarExtensions[name] ?? []
            guard let node = astNode as? ScalarTypeDefinition else {
                throw GraphQLError(message: "Expected ScalarTypeDefinition", locations: [])
            }

            return try GraphQLScalarType(
                name: name,
                description: node.description?.value,
                specifiedByURL: getSpecifiedByURL(node: node),
                astNode: node,
                extensionASTNodes: extensionASTNodes
            )
        case Kind.inputObjectTypeDefinition:
            let extensionASTNodes = inputObjectExtensions[name] ?? []
            guard let node = astNode as? InputObjectTypeDefinition else {
                throw GraphQLError(message: "Expected InputObjectTypeDefinition", locations: [])
            }
            var fields = try buildInputFieldMap(nodes: [node])
            for (name, value) in try buildInputFieldMap(nodes: extensionASTNodes) {
                fields[name] = value
            }

            return try GraphQLInputObjectType(
                name: name,
                description: node.description?.value,
                fields: fields,
                astNode: node,
                extensionASTNodes: extensionASTNodes,
                isOneOf: isOneOf(node: node)
            )
        default:
            throw GraphQLError(message: "Unsupported kind: \(astNode.kind)")
        }
    }
}

let stdTypeMap = {
    var types = [GraphQLNamedType]()
    types.append(contentsOf: specifiedScalarTypes)
    types.append(contentsOf: introspectionTypes)

    var typeMap = [String: GraphQLNamedType]()
    for type in types {
        typeMap[type.name] = type
    }
    return typeMap
}()

/**
 * Given a field or enum value node, returns the string value for the
 * deprecation reason.
 */

func getDeprecationReason(
    _ node: EnumValueDefinition
) throws -> String? {
    let deprecated = try getDirectiveValues(
        directiveDef: GraphQLDeprecatedDirective,
        directives: node.directives
    )
    return deprecated?.dictionary?["reason"]?.string
}

func getDeprecationReason(
    _ node: FieldDefinition
) throws -> String? {
    let deprecated = try getDirectiveValues(
        directiveDef: GraphQLDeprecatedDirective,
        directives: node.directives
    )
    return deprecated?.dictionary?["reason"]?.string
}

func getDeprecationReason(
    _ node: InputValueDefinition
) throws -> String? {
    let deprecated = try getDirectiveValues(
        directiveDef: GraphQLDeprecatedDirective,
        directives: node.directives
    )
    return deprecated?.dictionary?["reason"]?.string
}

/**
 * Given a scalar node, returns the string value for the specifiedByURL.
 */
func getSpecifiedByURL(
    node: ScalarTypeDefinition
) throws -> String? {
    let specifiedBy = try getDirectiveValues(
        directiveDef: GraphQLSpecifiedByDirective,
        directives: node.directives
    )
    return specifiedBy?.dictionary?["url"]?.string
}

func getSpecifiedByURL(
    node: ScalarExtensionDefinition
) throws -> String? {
    let specifiedBy = try getDirectiveValues(
        directiveDef: GraphQLSpecifiedByDirective,
        directives: node.directives
    )
    return specifiedBy?.dictionary?["url"]?.string
}

/**
 * Given an input object node, returns if the node should be OneOf.
 */
func isOneOf(node: InputObjectTypeDefinition) throws -> Bool {
    let isOneOf = try getDirectiveValues(
        directiveDef: GraphQLOneOfDirective,
        directives: node.directives
    )
    return try isOneOf?.boolValue() ?? false
}
