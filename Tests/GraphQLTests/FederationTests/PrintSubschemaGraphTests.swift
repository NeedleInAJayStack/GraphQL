@testable import GraphQL
import XCTest

final class PrintSubgraphSchemaTests: XCTestCase {
    
    func testPrintsASubgraphCorrectly() throws {
        let schema = try buildSubgraphSchema(
            documentAST: parse(
                source: """
                schema {
                  query: Query
                }
                
                type Query {}
                
                type Product @key(fields: "upc") {
                  upc: String!
                  name: String
                  price: Int
                }
                """
            )
        )
        
        print(
            try graphql(
                schema: schema,
                request: "{ _service { sdl }}",
                eventLoopGroup: .singletonMultiThreadedEventLoopGroup
            ).wait()
        )
        
        XCTAssertEqual(
            printType(type: schema.getType(name: "Product")!),
            """
            type Product {
              upc: String!
              name: String
              price: Int
            }
            """
        )
        
    }
//    func testPrintsASubgraphCorrectly() throws {
//        XCTAssertEqual(
//            buildSubgraphSchema(modulesOrSDL: fixtures[0].typeDefs),
//            """
//            schema {
//              query: RootQuery
//              mutation: Mutation
//            }
//
//            extend schema
//              ${FEDERATION2_LINK_WITH_AUTO_EXPANDED_IMPORTS}
//
//            directive @stream on FIELD
//
//            directive @transform(from: String!) on FIELD
//
//            directive @cacheControl(maxAge: Int, scope: CacheControlScope, inheritMaxAge: Boolean) on FIELD_DEFINITION | OBJECT | INTERFACE | UNION
//
//            enum CacheControlScope
//              @tag(name: "from-reviews")
//            {
//              PUBLIC @tag(name: "from-reviews")
//              PRIVATE
//            }
//
//            scalar JSON
//              @tag(name: "from-reviews")
//              @specifiedBy(url: "https://json-spec.dev")
//
//            type RootQuery {
//              user(id: ID!): User
//              me: User @cacheControl(maxAge: 1000, scope: PRIVATE)
//            }
//
//            type PasswordAccount
//              @key(fields: "email")
//            {
//              email: String!
//            }
//
//            type SMSAccount
//              @key(fields: "number")
//            {
//              number: String
//            }
//
//            union AccountType
//              @tag(name: "from-accounts")
//             = PasswordAccount | SMSAccount
//
//            type UserMetadata {
//              name: String
//              address: String
//              description: String
//            }
//
//            type User
//              @key(fields: "id")
//              @key(fields: "username name { first last }")
//              @tag(name: "from-accounts")
//            {
//              id: ID! @tag(name: "accounts")
//              name: Name @cacheControl(inheritMaxAge: true)
//              username: String @shareable
//              birthDate(locale: String @tag(name: "admin")): String @tag(name: "admin") @tag(name: "dev")
//              account: AccountType
//              metadata: [UserMetadata]
//              ssn: String
//            }
//
//            type Name {
//              first: String
//              last: String
//            }
//
//            type Mutation {
//              login(username: String!, password: String!, userId: String @deprecated(reason: "Use username instead")): User
//            }
//
//            type Library
//              @key(fields: "id")
//            {
//              id: ID!
//              name: String @external
//              userAccount(id: ID! = 1): User @requires(fields: "name")
//              description: String @override(from: "books")
//            }
//            """
//        )
//    }
}
