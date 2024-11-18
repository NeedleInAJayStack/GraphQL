//protocol GraphQLSchemaModule {
//    var typeDefs: Document { get }
//    var resolvers: GraphQLResolverMap? { get }
//}
//
//protocol GraphQLResolverMap {
//    var [typeName: string]:
//        |
//    {
//        [fieldName: string]:
//            | GraphQLFieldResolve
//            | {
//                requires?: string
//                resolve?: GraphQLFieldResolve
//                subscribe?: GraphQLFieldResolve
//            }
//    }
//        | GraphQLScalarType
//        | {
//            [enumValue: string]: string | number
//        }
//}
