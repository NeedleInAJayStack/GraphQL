@testable import GraphQL
import XCTest

class ExecutableDefinitionsRuleTests: ValidationTestCase {
    override func setUp() {
        rule = ExecutableDefinitionsRule
    }

    func testWithOnlyOperation() throws {
        try assertValid(
            """
            query Foo {
              dog {
                name
              }
            }
            """
        )
    }

    func testWithOperationAndFragment() throws {
        try assertValid(
            """
            query Foo {
              dog {
                name
                ...Frag
              }
            }

            fragment Frag on Dog {
              name
            }
            """
        )
    }

    func testWithTypeDefinition() throws {
        let errors = try assertInvalid(
            """
            query Foo {
              dog {
                name
              }
            }

            type Cow {
              name: String
            }

            extend type Dog {
              color: String
            }
            """,
            withErrors: [
                .init(
                    locations: [(line: 7, column: 1)],
                    message: #"The "Cow" definition is not executable."#
                ),
                .init(
                    locations: [(line: 11, column: 1)],
                    message: #"The "Dog" definition is not executable."#
                )
            ]
        )
    }

    func testWithSchemaDefinition() throws {
        try assertInvalid(
            """
            schema {
              query: Query
            }

            type Query {
              test: String
            }

            extend schema @directive
            """,
            withErrors: [
                .init(
                    locations: [(line: 1, column: 1)],
                    message: #"The schema definition is not executable."#
                ),
                .init(
                    locations: [(line: 5, column: 1)],
                    message: #"The "Query" definition is not executable."#
                ),
                .init(
                    locations: [(line: 9, column: 1)],
                    message: #"The schema definition is not executable."#
                )
            ]
        )
    }
}
