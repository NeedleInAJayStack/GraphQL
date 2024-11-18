 typealias TypeTransformer = (
  _ type: GraphQLNamedType
 ) -> GraphQLNamedType?

 func transformSchema(
  schema: GraphQLSchema,
  transformType: TypeTransformer
 ) throws -> GraphQLSchema {
    var typeMap = [String: GraphQLNamedType]()

    for (_, oldType) in schema.typeMap {
        if isIntrospectionType(type: oldType) {
            continue
        }

        var result = transformType(oldType)

        // Returning `undefined` keeps the old type.
        let newType = result ?? oldType
        typeMap[newType.name] = try recreateNamedType(type: newType)
      }

  let schemaConfig = schema.toConfig();

  return try GraphQLSchema(
    description: schemaConfig.description,
    query: replaceMaybeType(schemaConfig.query),
    mutation: replaceMaybeType(schemaConfig.mutation),
    subscription: replaceMaybeType(schemaConfig.subscription),
    types: Array(typeMap.values),
    directives: replaceDirectives(schemaConfig.directives),
    extensions: schemaConfig.extensions,
    astNode: schemaConfig.astNode,
    extensionASTNodes: schemaConfig.extensionASTNodes,
    assumeValid: schemaConfig.assumeValid
  )

  func recreateNamedType(type: GraphQLNamedType) throws -> GraphQLNamedType {
    if let type = type as? GraphQLObjectType {
        return try GraphQLObjectType(
        name: type.name,
        description: type.description,
        fields: { try replaceFields(type.fields()) },
        interfaces: { try type.interfaces().map { replaceNamedType($0) } },
        isTypeOf: type.isTypeOf,
        astNode: type.astNode,
        extensionASTNodes: type.extensionASTNodes
      );
    } else if let type = type as? GraphQLInterfaceType {
      return try GraphQLInterfaceType(
        name: type.name,
        description: type.description,
        fields: { try replaceFields(type.fields()) },
        interfaces: { try type.interfaces().map { replaceNamedType($0) } },
        astNode: type.astNode,
        extensionASTNodes: type.extensionASTNodes
      );
    } else if let type = type as? GraphQLUnionType {
      return try GraphQLUnionType(
        name: type.name,
        description: type.description,
        types: { try type.types().map { replaceNamedType($0) } },
        astNode: type.astNode,
        extensionASTNodes: type.extensionASTNodes
      );
    } else if let type = type as? GraphQLInputObjectType {
      return try GraphQLInputObjectType(
        name: type.name,
        description: type.description,
        fields: { try replaceInputFields(type.fields()) },
        astNode: type.astNode,
        extensionASTNodes: type.extensionASTNodes
      );
    }

    return type
  }

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
        return typeMap[type.name] as! T
  }

    func replaceMaybeType<T: GraphQLNamedType>(
    _ type: T?
  ) -> T? {
      return type.map { replaceNamedType($0) }
  }

  func replaceFields(
    _ fieldsMap: GraphQLFieldMap
  ) -> GraphQLFieldMap {
      return fieldsMap.mapValues { field in
          return GraphQLField(
            type: replaceType(field.type) ,
            description: field.description,
            deprecationReason: field.deprecationReason,
            args: replaceArgs(field.args),
            resolve: field.resolve,
            subscribe: field.subscribe,
            astNode: field.astNode
          )
      }
  }

  func replaceInputFields(
    _ fieldsMap: InputObjectFieldMap
  ) -> InputObjectFieldMap {
      return fieldsMap.mapValues { field in
          return InputObjectField(
            type: replaceType(field.type),
            defaultValue: field.defaultValue,
            description: field.description,
            deprecationReason: field.deprecationReason,
            astNode: field.astNode
          )
      }
  }

    func replaceArgs(_ args: GraphQLArgumentConfigMap) -> GraphQLArgumentConfigMap {
      return args.mapValues { arg in
          return GraphQLArgument(
            type: replaceType(arg.type),
            description: arg.description,
            defaultValue: arg.defaultValue,
            deprecationReason: arg.deprecationReason,
            astNode: arg.astNode
          )
      }
  }

  func replaceDirectives(_ directives: [GraphQLDirective]) throws -> [GraphQLDirective] {
      return try directives.map { directive in
          return try GraphQLDirective(
            name: directive.name,
            description: directive.description,
            locations: directive.locations,
            args: replaceArgs(directive.argConfigMap()),
            isRepeatable: directive.isRepeatable,
            astNode: directive.astNode
          );
      }
  }
 }
