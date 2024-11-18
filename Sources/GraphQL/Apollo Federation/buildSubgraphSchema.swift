
func buildSubgraphSchema(documentAST: Document) throws -> GraphQLSchema {
//    let documentAST = concatAST(documents: documents);
    
    let schema = try buildASTSchema(documentAST: documentAST, assumeValid: true, assumeValidSDL: true)
    let subgraph = SubGraph(name: "<unnamed>", url: "", schema: schema)

    let sdl = printSchema(schema: subgraph.schema)
    
    guard let queryType = schema.queryType else {
        throw GraphQLError(message: "A Query root type should have been added by `buildASTSchema`")
    }
    
    // Trying to just use normal schema extension, but hard to do with AST types...
//    try extendSchemaImpl(schema.toConfig(), .init(definitions: [
//        ObjectTypeDefinition(
//            name: .init(value: "_Service"),
//            fields: [
//                .init(
//                    name: .init(value: "sdl"),
//                    type: GraphQLString,
//                    description:
//                    "The sdl representing the federated service capabilities. Includes federation directives, removes federation types, and includes rest of full schema after schema directives have been applied",
//                    resolve: {_, _, _, _ in
//                        return sdl
//                    }
//                ),
//            ]
//        )
//        TypeExtensionDefinition(
//            definition: .init(
//                name: .init(value: "query")
//                fields: [
//                    "_service": FieldDefinition(
//                        type: serviceType(sdl: sdl)
//                    )
//                ]
//            )
//        )
//    ]))
    
    // This doesn't appear to override the constructed schema query type. Always comes back nil
    let originalFields = queryType.fields
    schema.queryType?.fields = {
        var fields = try originalFields()
        fields["_service"] = GraphQLField(
            type: serviceType(sdl: sdl)
        )
        return fields
    }
    

//  addResolversToSchema(schema, {
//     [queryRootName] : {
//      _service: () => ({ sdl }),
//    }
//  });
//
//  if (subgraph.metadata().entityType()) {
//    addResolversToSchema(schema, {
//     [queryRootName] : {
//        _entities: (_source, { representations }, context, info) => entitiesResolver({ representations, context, info }),
//      },
//      _Entity: {
//        __resolveType(parent: { __typename: string }) {
//          return parent.__typename;
//        },
//      }
//    });
//  }
//
//  for module in modules {
//    if (!module.resolvers) continue;
//    addResolversToSchema(schema, module.resolvers);
//  }

  return schema;
}

struct SubGraph {
    let name: String
    let url: String
    let schema: GraphQLSchema
}
