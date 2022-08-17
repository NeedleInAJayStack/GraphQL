import XCTest

@testable import GraphQL

class ProvidedNonNullArgumentsTests: ValidationTestCase {
    override func setUp() {
        rule = ProvidedNonNullArgumentsRule
    }

    func testValidWithObjectWithoutArguments() throws {
        try assertValid(
            "fragment objectFieldSelection on Dog { __typename name }"
        )
    }

    func testValidWithCorrectArgumentNames() throws {
        try assertValid(
            "fragment objectFieldSelection on Dog { __typename doesKnowCommand(dogCommand: SIT) }"
        )
    }
}
