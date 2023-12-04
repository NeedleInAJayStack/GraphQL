@testable import GraphQL
import XCTest

class ValidationTestCase: XCTestCase {
    typealias Rule = (ValidationContext) -> Visitor

    var rule: Rule!

    func assertValid(
        _ query: String,
        schema: GraphQLSchema = ValidationExampleSchema,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let errors = try validate(body: query, schema: schema)
        XCTAssertEqual(
            errors.count,
            0,
            "Expecting to pass validation without any errors",
            file: file,
            line: line
        )
    }
    
    @discardableResult func assertInvalid(
        errorCount: Int,
        query: String,
        schema: GraphQLSchema = ValidationExampleSchema,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> [GraphQLError] {
        let errors = try validate(body: query, schema: schema)
        XCTAssertEqual(
            errors.count,
            errorCount,
            "Expecting to fail validation with at least 1 error",
            file: file,
            line: line
        )
        return errors
    }

    func assertInvalid(
        _ query: String,
        withErrors expectedErrors: [ErrorInfo],
        schema: GraphQLSchema = ValidationExampleSchema,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let errors = try validate(body: query, schema: schema)
        XCTAssertEqual(
            errors.count,
            expectedErrors.count,
            "Expecting to fail validation with at least 1 error",
            file: file,
            line: line
        )
        for (error, expectedError) in zip(errors, expectedErrors) {
            try assertValidationError(
                error: error,
                locations: expectedError.locations,
                message: expectedError.message,
                testFile: file,
                testLine: line
            )
        }
    }

    func assertValidationError(
        error: GraphQLError?,
        line: Int,
        column: Int,
        path: String = "",
        message: String,
        testFile: StaticString = #file,
        testLine: UInt = #line
    ) throws {
        guard let error = error else {
            return XCTFail("Error was not provided")
        }

        XCTAssertEqual(
            error.message,
            message,
            "Unexpected error message",
            file: testFile,
            line: testLine
        )
        XCTAssertEqual(
            error.locations[0].line,
            line,
            "Unexpected line location",
            file: testFile,
            line: testLine
        )
        XCTAssertEqual(
            error.locations[0].column,
            column,
            "Unexpected column location",
            file: testFile,
            line: testLine
        )
        let errorPath = error.path.elements.map { $0.description }.joined(separator: " ")
        XCTAssertEqual(errorPath, path, "Unexpected error path", file: testFile, line: testLine)
    }

    func assertValidationError(
        error: GraphQLError?,
        locations: [(line: Int, column: Int)],
        path: String = "",
        message: String,
        testFile: StaticString = #file,
        testLine: UInt = #line
    ) throws {
        guard let error = error else {
            return XCTFail("Error was not provided")
        }

        XCTAssertEqual(
            error.message,
            message,
            "Unexpected error message",
            file: testFile,
            line: testLine
        )
        for (index, actualLocation) in error.locations.enumerated() {
            let expectedLocation = locations[index]
            XCTAssertEqual(
                actualLocation.line,
                expectedLocation.line,
                "Unexpected line location",
                file: testFile,
                line: testLine
            )
            XCTAssertEqual(
                actualLocation.column,
                expectedLocation.column,
                "Unexpected column location",
                file: testFile,
                line: testLine
            )
        }
        let errorPath = error.path.elements.map { $0.description }.joined(separator: " ")
        XCTAssertEqual(errorPath, path, "Unexpected error path", file: testFile, line: testLine)
    }
    
    private func validate(
        body request: String,
        schema: GraphQLSchema = ValidationExampleSchema
    ) throws -> [GraphQLError] {
        return try GraphQL.validate(
            schema: schema,
            ast: parse(source: Source(body: request, name: "GraphQL request")),
            rules: [rule]
        )
    }
}

struct ErrorInfo {
    let locations: [(line: Int, column: Int)]
    let path: String = ""
    let message: String
}
