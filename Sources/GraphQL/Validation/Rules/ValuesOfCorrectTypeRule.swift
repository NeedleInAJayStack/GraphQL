
/**
 * Value literals of correct type
 *
 * A GraphQL document is only valid if all value literals are of the type
 * expected at their position.
 *
 * See https://spec.graphql.org/draft/#sec-Values-of-Correct-Type
 */
func ValuesOfCorrectTypeRule(context: ValidationContext) -> Visitor {
    var variableDefinitions = [String: VariableDefinition]()

    return Visitor(
        enter: { node, _, _, _, _ in
            if node.kind == .operationDefinition {
//            if node is OperationDefinition {
                variableDefinitions = [:]
                return .continue
            }
            if node.kind == .variableDefinition {
                let variableDefinition = node as! VariableDefinition
//            if let variableDefinition = node as? VariableDefinition {
                variableDefinitions[variableDefinition.variable.name.value] = variableDefinition
                return .continue
            }
            if node.kind == .listValue {
                let list = node as! ListValue
//            if let list = node as? ListValue {
                guard let type = getNullableType(type: context.parentInputType) else {
                    return .continue
                }
                guard type is GraphQLList else {
                    isValidValueNode(context, list)
                    return .break // Don't traverse further.
                }
                return .continue
            }
            if node.kind == .objectValue {
                let object = node as! ObjectValue
//            if let object = node as? ObjectValue {
                let type = getNamedType(type: context.inputType)
                guard let type = type as? GraphQLInputObjectType else {
                    isValidValueNode(context, object)
                    return .break // Don't traverse further.
                }
                // Ensure every required field exists.
                let fieldNodeMap = Dictionary(grouping: object.fields) { field in
                    field.name.value
                }
                for (fieldName, fieldDef) in type.fields {
                    if fieldNodeMap[fieldName] == nil, isRequiredInputField(fieldDef) {
                        let typeStr = fieldDef.type
                        context.report(
                            error: GraphQLError(
                                message: "Field \"\(type.name).\(fieldDef.name)\" of required type \"\(typeStr)\" was not provided.",
                                nodes: [object]
                            )
                        )
                    }
                }

                // TODO: Add oneOf support
                return .continue
            }
            if node.kind == .objectField {
                let field = node as! ObjectField
//            if let field = node as? ObjectField {
                let parentType = getNamedType(type: context.parentInputType)
                if
                    context.inputType == nil,
                    let parentType = parentType as? GraphQLInputObjectType
                {
                    let suggestions = suggestionList(
                        input: field.name.value,
                        options: Array(parentType.fields.keys)
                    )
                    context.report(
                        error: GraphQLError(
                            message:
                            "Field \"\(field.name.value)\" is not defined by type \"\(parentType.name)\"." +
                                didYouMean(suggestions: suggestions),
                            nodes: [field]
                        )
                    )
                }
                return .continue
            }
            if node.kind == .nullValue {
                let null = node as! NullValue
//            if let null = node as? NullValue {
                let type = context.inputType
                if let type = type as? GraphQLNonNull {
                    context.report(
                        error: GraphQLError(
                            message:
                            "Expected value of type \"\(type)\", found \(print(ast: node)).",
                            nodes: [null]
                        )
                    )
                }
                return .continue
            }
            if node.kind == .enumValue {
                let node = node as! EnumValue
//            if let node = node as? EnumValue {
                isValidValueNode(context, node)
                return .continue
            }
            if node.kind == .intValue {
                let node = node as! IntValue
//            if let node = node as? IntValue {
                isValidValueNode(context, node)
                return .continue
            }
            if node.kind == .floatValue {
                let node = node as! FloatValue
//            if let node = node as? FloatValue {
                isValidValueNode(context, node)
                return .continue
            }
            if node.kind == .stringValue {
                let node = node as! StringValue
//            if let node = node as? StringValue {
                isValidValueNode(context, node)
                return .continue
            }
            if node.kind == .booleanValue {
                let node = node as! BooleanValue
//            if let node = node as? BooleanValue {
                isValidValueNode(context, node)
                return .continue
            }
            return .continue
        }
    )
}

/**
 * Any value literal may be a valid representation of a Scalar, depending on
 * that scalar type.
 */
func isValidValueNode(_ context: ValidationContext, _ node: Value) {
    // Report any error at the full type expected by the location.
    guard let locationType = context.inputType else {
        return
    }

    let type = getNamedType(type: locationType)

    if !isLeafType(type: type) {
        context.report(
            error: GraphQLError(
                message: "Expected value of type \"\(locationType)\", found \(print(ast: node)).",
                nodes: [node]
            )
        )
        return
    }

    // Scalars and Enums determine if a literal value is valid via parseLiteral(),
    // which may throw or return an invalid value to indicate failure.
    do {
        if let type = type as? GraphQLScalarType {
            if try type.parseLiteral(valueAST: node) == .undefined {
                context.report(
                    error: GraphQLError(
                        message: "Expected value of type \"\(locationType)\", found \(print(ast: node)).",
                        nodes: [node]
                    )
                )
            }
        }
        if let type = type as? GraphQLEnumType {
            if try type.parseLiteral(valueAST: node) == .undefined {
                context.report(
                    error: GraphQLError(
                        message: "Expected value of type \"\(locationType)\", found \(print(ast: node)).",
                        nodes: [node]
                    )
                )
            }
        }
    } catch {
        if let graphQLError = error as? GraphQLError {
            context.report(error: graphQLError)
        } else {
            context.report(
                error: GraphQLError(
                    message: "Expected value of type \"\(locationType)\", found \(print(ast: node)).",
                    nodes: [node]
                )
            )
        }
    }
}
