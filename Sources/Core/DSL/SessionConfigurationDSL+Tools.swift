import Foundation

/// Controls how the model is allowed to choose tools in the session DSL.
public struct ToolSelection: Equatable, Hashable, Sendable {
	fileprivate let value: ToolChoice
	fileprivate let requiredFunctionName: String?
	fileprivate let requiredFunctionType: ObjectIdentifier?

	private init(_ value: ToolChoice, requiredFunctionName: String? = nil, requiredFunctionType: ObjectIdentifier? = nil) {
		self.value = value
		self.requiredFunctionName = requiredFunctionName
		self.requiredFunctionType = requiredFunctionType
	}

	public static let none = Self(.none)
	public static let auto = Self(.auto)
	public static let required = Self(.required)

	public static func required<T: FunctionTool>(_ type: T.Type) -> Self {
		let name = _defaultToolName(for: type)
		return .init(.function(name: name), requiredFunctionName: name, requiredFunctionType: ObjectIdentifier(type))
	}
}

public protocol ToolDefinitionConvertible {
	var toolDefinition: ToolDefinition { get }
	var toolDefinitionValidationErrors: [SessionConfigurationBuilderError] { get }
}

public extension ToolDefinitionConvertible {
	var toolDefinitionValidationErrors: [SessionConfigurationBuilderError] { [] }
}

public struct ToolDefinitionComponent {
	fileprivate let definition: ToolDefinition
	fileprivate let validationErrors: [SessionConfigurationBuilderError]
	fileprivate let functionType: ObjectIdentifier?
	fileprivate let functionName: String?

	fileprivate init(
		definition: ToolDefinition,
		validationErrors: [SessionConfigurationBuilderError] = [],
		functionType: ObjectIdentifier? = nil,
		functionName: String? = nil
	) {
		self.definition = definition
		self.validationErrors = validationErrors
		self.functionType = functionType
		self.functionName = functionName
	}
}

/// Declares the set of tools advertised by the session DSL.
public struct Tools: SessionComponentConvertible {
	private let choice: ToolChoice
	private let definitions: [ToolDefinition]
	private let validationErrors: [SessionConfigurationBuilderError]

	public init(choice: ToolSelection, @ToolsBuilder _ content: () -> [ToolDefinitionComponent] = { [] }) {
		let components = content()
		let definitions = components.map(\.definition)
		var validationErrors = components.flatMap(\.validationErrors)
		let resolvedRequiredName: String?

		if let requiredFunctionType = choice.requiredFunctionType,
		   let matchingComponent = components.first(where: { $0.functionType == requiredFunctionType }),
		   let functionName = matchingComponent.functionName
		{
			resolvedRequiredName = functionName
		} else {
			resolvedRequiredName = choice.requiredFunctionName
		}

		if let requiredName = resolvedRequiredName {
			let hasMatchingTool = definitions.contains { definition in
				guard case let .function(function) = definition else { return false }
				return function.name == requiredName
			}
			if !hasMatchingTool {
				validationErrors.append(.requiredToolMissing(requiredName))
			}
		}

		if let requiredName = resolvedRequiredName, case .function = choice.value {
			self.choice = .function(name: requiredName)
		} else {
			self.choice = choice.value
		}
		self.definitions = definitions
		self.validationErrors = validationErrors
	}

	public var sessionComponent: SessionComponent {
		SessionComponent({ draft in
			draft.toolChoice = choice
			draft.tools = definitions
		}, validationErrors: validationErrors)
	}
}

@resultBuilder
public enum ToolsBuilder {
	public static func buildExpression<T: FunctionTool>(_ expression: T) -> [ToolDefinitionComponent] {
		[.init(
			definition: expression.definition,
			functionType: ObjectIdentifier(T.self),
			functionName: expression.name
		)]
	}

	public static func buildExpression<T: ToolDefinitionConvertible>(_ expression: T) -> [ToolDefinitionComponent] {
		[.init(definition: expression.toolDefinition, validationErrors: expression.toolDefinitionValidationErrors)]
	}

	public static func buildBlock(_ components: [ToolDefinitionComponent]...) -> [ToolDefinitionComponent] {
		components.flatMap(\.self)
	}

	public static func buildOptional(_ component: [ToolDefinitionComponent]?) -> [ToolDefinitionComponent] {
		component ?? []
	}

	public static func buildEither(first component: [ToolDefinitionComponent]) -> [ToolDefinitionComponent] {
		component
	}

	public static func buildEither(second component: [ToolDefinitionComponent]) -> [ToolDefinitionComponent] {
		component
	}

	public static func buildArray(_ components: [[ToolDefinitionComponent]]) -> [ToolDefinitionComponent] {
		components.flatMap(\.self)
	}
}
