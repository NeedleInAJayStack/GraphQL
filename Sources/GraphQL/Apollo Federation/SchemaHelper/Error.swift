struct GraphQLSchemaValidationError: Error {
    let errors: [GraphQLError]
}
