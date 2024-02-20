
/**
 * Unique argument names
 *
 * A GraphQL field or directive is only valid if all supplied arguments are
 * uniquely named.
 *
 * See https://spec.graphql.org/draft/#sec-Argument-Names
 */
func UniqueArgumentNamesRule(context: ValidationContext) -> Visitor {
    return Visitor(
        enter: { node, _, _, _, _ in
            let argumentNodes: [Argument]
            if node.kind == .field {
                let field = node as! Field
//            if let field = node as? Field {
                argumentNodes = field.arguments
            } else if node.kind == .directive {
                let directive = node as! Directive
//            } else if let directive = node as? Directive {
                argumentNodes = directive.arguments
            } else {
                return .continue
            }

            let seenArgs = Dictionary(grouping: argumentNodes) { $0.name.value }

            for (argName, argNodes) in seenArgs {
                if argNodes.count > 1 {
                    context.report(
                        error: GraphQLError(
                            message: "There can be only one argument named \"\(argName)\".",
                            nodes: argNodes.map { $0.name }
                        )
                    )
                }
            }
            return .continue
        }
    )
}
