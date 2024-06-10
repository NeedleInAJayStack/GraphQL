@testable import GraphQL
import NIO
import XCTest

class BuildASTSchemaTests: XCTestCase {
    func testCanUseBuiltSchemaForLimitedExecution() throws {
        let schema = try buildASTSchema(
            documentAST: parse(
                source: """
                type Query {
                  str: String
                }
                """
            )
        )

        let result = try graphql(
            schema: schema,
            request: "{ str }",
            rootValue: ["str": 123],
            eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1)
        ).wait()

        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "str": 123,
            ])
        )
    }

    // Closures are invalid Map keys in Swift.
//    func testCanBuildASchemaDirectlyFromTheSource() throws {
//        let schema = try buildASTSchema(
//            documentAST: try parse(
//                source: """
//                type Query {
//                  add(x: Int, y: Int): Int
//                }
//                """
//            )
//        )
//
//        let result = try graphql(
//            schema: schema,
//            request: "{ add(x: 34, y: 55) }",
//            rootValue: [
//                "add": { (x: Int, y: Int) in
//                    return x + y
//                }
//            ],
//            eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1)
//        ).wait()
//
//        XCTAssertEqual(
//            result,
//            GraphQLResult(data: [
//                "add": 89
//            ])
//        )
//    }

    func testIgnoresNonTypeSystemDefinitions() throws {
        let sdl = """
        type Query {
          str: String
        }

        fragment SomeFragment on Query {
          str
        }
        """

        XCTAssertNoThrow(try buildSchema(source: sdl))
    }

    func testMatchOrderOfDefaultTypesAndDirectives() throws {
        let schema = try GraphQLSchema()
        let sdlSchema = try buildASTSchema(documentAST: .init(definitions: []))

        XCTAssertEqual(sdlSchema.directives.map { $0.name }, schema.directives.map { $0.name })
        XCTAssertEqual(
            sdlSchema.typeMap.mapValues { $0.name },
            schema.typeMap.mapValues { $0.name }
        )
    }

    // TODO: Continue testing with `Empty type` when printSchema is implemented
}
