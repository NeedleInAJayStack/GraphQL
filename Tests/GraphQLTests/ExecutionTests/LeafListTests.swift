import Testing

import GraphQL

@Suite struct LeafListTests {
    @Test func nullableItemsKeepTheirPositionsAndReportSerializationErrors() async throws {
        let schema = try GraphQLSchema(query: GraphQLObjectType(
            name: "Query",
            fields: [
                "values": GraphQLField(type: GraphQLList(GraphQLInt)) { _, _, _, _ in
                    [1, nil, "invalid", 4] as [(any Sendable)?]
                }
            ]
        ))

        let result = try await graphql(schema: schema, request: "{ values }")

        #expect(result.data == ["values": [1, .null, .null, 4]])
        #expect(result.errors.count == 1)
        #expect(result.errors[0].path.elements == [.key("values"), .index(2)])
    }

    @Test func nonNullItemFailureNullsTheList() async throws {
        let schema = try GraphQLSchema(query: GraphQLObjectType(
            name: "Query",
            fields: [
                "values": GraphQLField(type: GraphQLList(GraphQLNonNull(GraphQLString))) {
                    _, _, _, _ in
                    ["first", nil, "third"] as [(any Sendable)?]
                }
            ]
        ))

        let result = try await graphql(schema: schema, request: "{ values }")

        #expect(result.data == ["values": .null])
        #expect(result.errors.count == 1)
        #expect(result.errors[0].path.elements == [.key("values"), .index(1)])
    }

    @Test func enumItemsAreSerializedInOrder() async throws {
        let status = try GraphQLEnumType(name: "Status", values: [
            "READY": GraphQLEnumValue(value: "ready"),
            "DONE": GraphQLEnumValue(value: "done"),
        ])
        let schema = try GraphQLSchema(query: GraphQLObjectType(
            name: "Query",
            fields: [
                "statuses": GraphQLField(type: GraphQLList(status)) { _, _, _, _ in
                    ["ready", "done"]
                }
            ]
        ))

        let result = try await graphql(schema: schema, request: "{ statuses }")

        #expect(result.data == ["statuses": ["READY", "DONE"]])
        #expect(result.errors.isEmpty)
    }
}
