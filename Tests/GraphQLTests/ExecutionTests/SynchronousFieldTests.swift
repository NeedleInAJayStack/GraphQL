import Testing

import GraphQL

@Suite struct SynchronousFieldTests {
    @Test func synchronousFieldsPreserveAliasesAndNulls() async throws {
        let schema = try GraphQLSchema(query: GraphQLObjectType(name: "Query", fields: [
            "first": GraphQLField(type: GraphQLInt, resolve: .sync(resolve: { _, _, _, _ in 1 })),
            "missing": GraphQLField(type: GraphQLString),
            "last": GraphQLField(type: GraphQLNonNull(GraphQLString), resolve: .sync(resolve: { _, _, _, _ in "last" })),
        ]))

        let result = try await graphql(schema: schema, request: "{ renamed: first missing last }")

        #expect(result.data == ["renamed": 1, "missing": .null, "last": "last"])
        #expect(result.errors.isEmpty)
    }

    @Test func synchronousLeafErrorsRespectNullability() async throws {
        struct FieldFailure: Error, CustomStringConvertible {
            var description: String { "field failed" }
        }
        let schema = try GraphQLSchema(query: GraphQLObjectType(name: "Query", fields: [
            "bad": GraphQLField(type: GraphQLInt, resolve: .sync(resolve: { _, _, _, _ in
                throw FieldFailure()
            })),
            "good": GraphQLField(type: GraphQLString, resolve: .sync(resolve: { _, _, _, _ in "ok" })),
            "required": GraphQLField(type: GraphQLNonNull(GraphQLString), resolve: .sync(resolve: { _, _, _, _ in nil })),
        ]))

        let nullableResult = try await graphql(schema: schema, request: "{ alias: bad good }")
        #expect(nullableResult.data == ["alias": .null, "good": "ok"])
        #expect(nullableResult.errors.count == 1)
        #expect(nullableResult.errors[0].path.elements == [.key("alias")])

        let requiredResult = try await graphql(schema: schema, request: "{ required }")
        #expect(requiredResult.data == nil)
        #expect(requiredResult.errors.count == 1)
        #expect(requiredResult.errors[0].path.elements == [.key("required")])
    }

    @Test func mixedSelectionsRunAsyncSiblingsConcurrently() async throws {
        let rendezvous = Rendezvous()
        let schema = try GraphQLSchema(query: GraphQLObjectType(name: "Query", fields: [
            "one": GraphQLField(type: GraphQLString, resolve: .async(resolve: { _, _, _, _ in
                await rendezvous.arrive()
                return "one"
            })),
            "middle": GraphQLField(type: GraphQLString, resolve: .sync(resolve: { _, _, _, _ in "middle" })),
            "two": GraphQLField(type: GraphQLString, resolve: .async(resolve: { _, _, _, _ in
                await rendezvous.arrive()
                return "two"
            })),
        ]))

        let result = try await graphql(schema: schema, request: "{ one middle two }")

        #expect(result.data == ["one": "one", "middle": "middle", "two": "two"])
        #expect(result.errors.isEmpty)
    }

    private actor Rendezvous {
        private var first: CheckedContinuation<Void, Never>?

        func arrive() async {
            if let first {
                self.first = nil
                first.resume()
            } else {
                await withCheckedContinuation { first = $0 }
            }
        }
    }
}
