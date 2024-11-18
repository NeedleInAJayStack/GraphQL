typealias GraphQLReferenceResolver = (
    _ reference: Any,
    _ context: Any,
    _ info: GraphQLResolveInfo
) throws -> Any

protocol ApolloSubgraphExtensions {
    var resolveReference: GraphQLReferenceResolver? { get }
}

//protocol ApolloGraphQLObjectTypeExtensions: GraphQLObjectTypeExtensions {
//    apollo?: {
//        subgraph: ApolloSubgraphExtensions?
//    }
//}
//
//
//protocol ApolloGraphQLInterfaceTypeExtensions: GraphQLInterfaceTypeExtensions {
//    apollo?: {
//        subgraph: ApolloSubgraphExtensions?
//    }
//}
//
//protocol ApolloGraphQLUnionTypeExtensions: GraphQLUnionTypeExtensions {
//    apollo?: {
//        subgraph: ApolloSubgraphExtensions?
//    }
//}
