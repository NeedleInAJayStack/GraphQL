import XCTest

@testable import GraphQL

class GraphQLSchemaTests: XCTestCase {
    
    /// Object should be valid if it implements an interface by requiring arguments
    func testInterfaceArgsPresent()
        throws
    {
        let interface = try GraphQLInterfaceType(
            name: "Interface",
            fields: [
                "fieldWithNoArg": GraphQLField(
                    type: GraphQLInt,
                    args: [:]
                ),
                "fieldWithOneArg": GraphQLField(
                    type: GraphQLInt,
                    args: ["requiredArg": GraphQLArgument(type: GraphQLString)]
                ),
                "fieldWithMultipleArgs": GraphQLField(
                    type: GraphQLInt,
                    args: [
                        "arg1": GraphQLArgument(type: GraphQLString),
                        "arg2": GraphQLArgument(type: GraphQLNonNull(GraphQLInt)),
                        "arg3": GraphQLArgument(type: GraphQLNonNull(GraphQLBoolean)),
                    ]
                ),
            ]
        )

        let object = try GraphQLObjectType(
            name: "Object",
            fields: [
                "fieldWithNoArg": GraphQLField(
                    type: GraphQLInt,
                    args: [:]
                ),
                "fieldWithOneArg": GraphQLField(
                    type: GraphQLInt,
                    args: ["requiredArg": GraphQLArgument(type: GraphQLString)]
                ),
                "fieldWithMultipleArgs": GraphQLField(
                    type: GraphQLInt,
                    args: [
                        "arg1": GraphQLArgument(type: GraphQLString),
                        "arg2": GraphQLArgument(type: GraphQLNonNull(GraphQLInt)),
                        "arg3": GraphQLArgument(type: GraphQLNonNull(GraphQLBoolean)),
                    ]
                ),
            ],
            interfaces: [interface],
            isTypeOf: { (_, _, _) -> Bool in
                preconditionFailure("Should not be called")
            }
        )

        _ = try GraphQLSchema(query: object, types: [interface, object])
    }
    
    /// Object should be valid if it implements an interface using default values
    func testInterfaceArgsDefault() throws {
        let interface = try GraphQLInterfaceType(
            name: "Interface",
            fields: [
                "fieldWithOneArg": GraphQLField(
                    type: GraphQLInt,
                    args: [:]
                )
            ]
        )

        let object = try GraphQLObjectType(
            name: "Object",
            fields: [
                "fieldWithOneArg": GraphQLField(
                    type: GraphQLInt,
                    args: [
                        "addedRequiredArgWithDefaultValue": GraphQLArgument(
                            type: GraphQLNonNull(GraphQLInt),
                            defaultValue: .int(5)
                        )
                    ]
                )
            ],
            interfaces: [interface],
            isTypeOf: { (_, _, _) -> Bool in
                preconditionFailure("Should not be called")
            }
        )

        _ = try GraphQLSchema(query: object, types: [interface, object])
    }
    
    /// Object should be valid if it implements an interface using nullable arguments
    func testInterfaceArgsNullable() throws {
        let interface = try GraphQLInterfaceType(
            name: "Interface",
            fields: [
                "fieldWithOneArg": GraphQLField(
                    type: GraphQLInt,
                    args: [:]
                )
            ]
        )

        let object = try GraphQLObjectType(
            name: "Object",
            fields: [
                "fieldWithOneArg": GraphQLField(
                    type: GraphQLInt,
                    args: ["addedNullableArg": GraphQLArgument(type: GraphQLInt)]
                )
            ],
            interfaces: [interface],
            isTypeOf: { (_, _, _) -> Bool in
                preconditionFailure("Should not be called")
            }
        )

        _ = try GraphQLSchema(query: object, types: [interface, object])
    }
    
    /// Object should be invalid if it implements an interface but doesn't require interface-required arguments
    func testInterfaceArgsMissing() throws {
        let interface = try GraphQLInterfaceType(
            name: "Interface",
            fields: [
                "fieldWithoutArg": GraphQLField(
                    type: GraphQLInt,
                    args: [:]
                )
            ]
        )

        let object = try GraphQLObjectType(
            name: "Object",
            fields: [
                "fieldWithoutArg": GraphQLField(
                    type: GraphQLInt,
                    args: [
                        "addedRequiredArg": GraphQLArgument(type: GraphQLNonNull(GraphQLInt))
                    ]
                )
            ],
            interfaces: [interface],
            isTypeOf: { (_, _, _) -> Bool in
                preconditionFailure("Should not be called")
            }
        )

        do {
            _ = try GraphQLSchema(query: object, types: [interface, object])
            XCTFail("Expected errors when creating schema")
        } catch {
            let graphQLError = try XCTUnwrap(error as? GraphQLError)
            XCTAssertEqual(
                graphQLError.message,
                "Object.fieldWithoutArg includes required argument (addedRequiredArg:) that is missing from the Interface field Interface.fieldWithoutArg."
            )
        }
    }
}
