/**
 * This takes the ast of a schema document produced by the parse function in
 * src/language/parser.js.
 *
 * If no schema definition is provided, then it will look for types named Query,
 * Mutation and Subscription.
 *
 * Given that AST it constructs a GraphQLSchema. The resulting schema
 * has no resolve methods, so execution will use default resolvers.
 */
public func buildASTSchema(
    documentAST: Document
    // TODO: Add SDL validation support
//    assumeValidSDL: Bool = false
) throws -> GraphQLSchema {
//    if assumeValid != true, !assumeValidSDL {
//      assertValidSDL(documentAST)
//    }
    let emptySchemaConfig = GraphQLSchemaNormalizedConfig()
    let config = try extendSchemaImpl(emptySchemaConfig, documentAST)

    // Note: Commented out because this is required to detect operation types on parsed schemas
//    if config.astNode == nil {
    config.types.compactMap { type in
        type as? GraphQLObjectType
    }.forEach { type in
        switch type.name {
        case "Query": config.query = type
        case "Mutation": config.mutation = type
        case "Subscription": config.subscription = type
        default: break
        }
    }
//    }

    var directives = config.directives
    directives.append(contentsOf: specifiedDirectives.filter { stdDirective in
        config.directives.allSatisfy { directive in
            directive.name != stdDirective.name
        }
    })

    config.directives = directives

    return try GraphQLSchema(config: config)
}

/**
 * A helper function to build a GraphQLSchema directly from a source
 * document.
 */
public func buildSchema(
    source: Source
) throws -> GraphQLSchema {
    let document = try parse(
        source: source
    )

    return try buildASTSchema(
        documentAST: document
    )
}

/**
 * A helper function to build a GraphQLSchema directly from a source
 * document.
 */
public func buildSchema(
    source: String
) throws -> GraphQLSchema {
    let document = try parse(
        source: source
    )

    return try buildASTSchema(
        documentAST: document
    )
}
