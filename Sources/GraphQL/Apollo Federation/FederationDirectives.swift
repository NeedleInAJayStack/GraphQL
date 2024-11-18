let KeyDirective = try! GraphQLDirective(
    name: "key",
    description: "Designates an object type as an entity and specifies its key fields. Key fields are a set of fields that a subgraph can use to uniquely identify any instance of the entity.",
    locations: [.object, .interface],
    args: [
        "fields": .init(
            type: GraphQLNonNull(GraphQLString)
        ),
        "resolvable": .init(
            type: GraphQLBoolean,
            defaultValue: true
        ),
    ],
    isRepeatable: true
)

let ExtendsDirective = try! GraphQLDirective(
    name: "extends",
    description: "Indicates that an object or interface definition is an extension of another definition of that same type. This directive is for use with GraphQL subgraph libraries that do not support the extend keyword. Most commonly, these are subgraph libraries that generate their schema programmatically instead of using a static .graphql file.",
    locations: [.object, .interface]
)

let ExternalDirective = try! GraphQLDirective(
    name: "external",
    description: "Indicates that this subgraph usually can't resolve a particular object field, but it still needs to define that field for other purposes. This directive is always used in combination with another directive that references object fields, such as @provides or @requires.",
    locations: [.object, .fieldDefinition]
)

let RequiresDirective = try! GraphQLDirective(
    name: "requires",
    description: "Indicates that the resolver for a particular entity field depends on the values of other entity fields that are resolved by other subgraphs. This tells the router that it needs to fetch the values of those externally defined fields first, even if the original client query didn't request them.",
    locations: [.fieldDefinition],
    args: [
        "fields": .init(
            type: GraphQLNonNull(GraphQLString)
        ),
    ]
)

let ProvidesDirective = try! GraphQLDirective(
    name: "provides",
    description: "Specifies a set of entity fields that a subgraph can resolve, but only at a particular schema path (at other paths, the subgraph can't resolve those fields). If a subgraph can always resolve a particular entity field, do not apply this directive. Using this directive is always an optional optimization. It can reduce the total number of subgraphs that your router needs to communicate with to resolve certain operations, which can improve performance.",
    locations: [.fieldDefinition],
    args: [
        "fields": .init(
            type: GraphQLNonNull(GraphQLString)
        ),
    ]
)

let TagDirective = try! GraphQLDirective(
    name: "tag",
    description: "Applies arbitrary string metadata to a schema location. Custom tooling can use this metadata during any step of the schema delivery flow, including composition, static analysis, and documentation. The GraphOS Enterprise contracts feature uses @tag with its inclusion and exclusion filters.",
    locations: [
        .fieldDefinition,
        .object,
        .interface,
        .union,
        .argumentDefinition,
        .scalar,
        .enum,
        .enumValue,
        .inputObject,
        .inputFieldDefinition,
        .schema,
    ],
    args: [
        "name": .init(
            type: GraphQLNonNull(GraphQLString)
        ),
    ],
    isRepeatable: true
)

let ShareableDirective = try! GraphQLDirective(
    name: "shareable",
    description: "Indicates that an object type's field is allowed to be resolved by multiple subgraphs (by default in Federation 2, object fields can be resolved by only one subgraph).",
    locations: [.fieldDefinition, .object]
)

let LinkDirective = try! GraphQLDirective(
    name: "link",
    description: "This directive links definitions from an external specification to this schema.",
    locations: [.schema],
    args: [
        "url": .init(
            type: GraphQLNonNull(GraphQLString)
        ),
        "import": .init(
            type: GraphQLList(LinkImportType)
        ),
    ]
)

let InaccessibleDirective = try! GraphQLDirective(
    name: "inaccessible",
    description: "Indicates that a definition in the subgraph schema should be omitted from the router's API schema, even if that definition is also present in other subgraphs. This means that the field is not exposed to clients at all.",
    locations: [
        .fieldDefinition,
        .object,
        .interface,
        .union,
        .argumentDefinition,
        .scalar,
        .enum,
        .enumValue,
        .inputObject,
        .inputFieldDefinition,
    ]
)

let OverrideDirective = try! GraphQLDirective(
    name: "override",
    description: "Indicates that an object field is now resolved by this subgraph instead of another subgraph where it's also defined. This enables you to migrate a field from one subgraph to another.",
    locations: [.fieldDefinition],
    args: [
        "from": .init(
            type: GraphQLNonNull(GraphQLString)
        ),
        "label": .init(
            type: GraphQLString
        ),
    ]
)

let federationDirectives = [
    KeyDirective,
    ExtendsDirective,
    ExternalDirective,
    RequiresDirective,
    ProvidesDirective,
    ShareableDirective,
    LinkDirective,
    TagDirective,
    InaccessibleDirective,
    OverrideDirective,
]

func isFederationDirective(directive: GraphQLDirective) -> Bool {
    return federationDirectives.contains { $0.name == directive.name }
}

protocol ASTNodeWithDirectives {
    var directives: [Directive] { get }
}

extension FieldDefinition: ASTNodeWithDirectives {}
extension InputValueDefinition: ASTNodeWithDirectives {}
extension EnumValueDefinition: ASTNodeWithDirectives {}
// ExecutableDefinition
extension OperationDefinition: ASTNodeWithDirectives {}
extension FragmentDefinition: ASTNodeWithDirectives {}

extension SchemaDefinition: ASTNodeWithDirectives {}
// TypeDefinitions
extension ScalarTypeDefinition: ASTNodeWithDirectives {}
extension ObjectTypeDefinition: ASTNodeWithDirectives {}
extension InterfaceTypeDefinition: ASTNodeWithDirectives {}
extension UnionTypeDefinition: ASTNodeWithDirectives {}
extension EnumTypeDefinition: ASTNodeWithDirectives {}
extension InputObjectTypeDefinition: ASTNodeWithDirectives {}

// TypeSystemExtension
// TODO: Add directive support to Schema/Type extensions
// extension SchemaExtensionDefinition: ASTNodeWithDirectives {}
// extension TypeExtensionDefinition: ASTNodeWithDirectives {}

func hasDirectives(
    node: ASTNodeWithDirectives
) -> [Directive] {
    return node.directives
}

public func directiveDefinitionsAreCompatible(
    baseDefinition: DirectiveDefinition,
    toCompare: DirectiveDefinition
) -> Bool {
    guard baseDefinition.name.value == toCompare.name.value else {
        return false
    }
    // arguments must be equal in length
    guard baseDefinition.arguments.count == toCompare.arguments.count else {
        return false
    }
    // arguments must be equal in type
    for arg in baseDefinition.arguments {
        let toCompareArg = toCompare.arguments.find { a in
            a.name.value == arg.name.value
        }
        guard let toCompareArg = toCompareArg else {
            return false
        }
        guard
            print(ast: stripDescriptions(astNode: arg)) ==
            print(ast: stripDescriptions(astNode: toCompareArg))
        else {
            return false
        }
    }
    // toCompare's locations must exist in baseDefinition's locations
    for location in toCompare.locations {
        guard baseDefinition.locations.contains(where: { $0.value == location.value }) else {
            return false
        }
    }

    return true
}

func stripDescriptions(astNode: Node) -> Node {
    // TODO: This should strip descriptions, but currently that's not possible
    return astNode
}

protocol NodeWithDescription {
    var description: StringValue? { get }
}

extension SchemaDefinition: NodeWithDescription {}
