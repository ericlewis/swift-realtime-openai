import Foundation

/// Errors surfaced while building a session configuration through the DSL.
public enum SessionConfigurationBuilderError: Error, Equatable, Sendable {
	case invalidMaxTokens(Int)
	case invalidPrefixPadding(Int)
	case invalidSilenceDuration(Int)
	case invalidIdleTimeout(Int)
	case invalidThreshold(Double)
	case invalidVoiceSpeed(Double)
	case invalidInlineInstructionsContent
	case invalidMCPServerURL(String)
	case requiredToolMissing(String)
}

public extension SessionConfiguration {
	init(_ model: Model, @SessionBuilder _ content: () -> [SessionComponent]) throws {
		var draft = SessionDraft(model: model)

		for component in content() {
			if let error = component.validationErrors.first {
				throw error
			}
			component.apply(&draft)
		}

		self = draft.makeSession()
	}
}

public struct SessionComponent {
	fileprivate let apply: (inout SessionDraft) -> Void
	fileprivate let validationErrors: [SessionConfigurationBuilderError]

	init(_ apply: @escaping (inout SessionDraft) -> Void, validationErrors: [SessionConfigurationBuilderError] = []) {
		self.apply = apply
		self.validationErrors = validationErrors
	}
}

public protocol SessionComponentConvertible {
	var sessionComponent: SessionComponent { get }
}

@resultBuilder
public enum SessionBuilder {
	public static func buildExpression<T: SessionComponentConvertible>(_ expression: T) -> [SessionComponent] {
		[expression.sessionComponent]
	}

	public static func buildBlock(_ components: [SessionComponent]...) -> [SessionComponent] {
		components.flatMap(\.self)
	}

	public static func buildOptional(_ component: [SessionComponent]?) -> [SessionComponent] {
		component ?? []
	}

	public static func buildEither(first component: [SessionComponent]) -> [SessionComponent] {
		component
	}

	public static func buildEither(second component: [SessionComponent]) -> [SessionComponent] {
		component
	}

	public static func buildArray(_ components: [[SessionComponent]]) -> [SessionComponent] {
		components.flatMap(\.self)
	}
}

public struct InstructionsFragment {
	let texts: [String]
	let validationErrors: [SessionConfigurationBuilderError]

	init(texts: [String] = [], validationErrors: [SessionConfigurationBuilderError] = []) {
		self.texts = texts
		self.validationErrors = validationErrors
	}
}

@resultBuilder
public enum InstructionsBuilder {
	public static func buildExpression(_ expression: String) -> [InstructionsFragment] {
		[.init(texts: [expression])]
	}

	public static func buildExpression<T: InstructionsRepresentable>(_ expression: T) -> [InstructionsFragment] {
		guard let text = expression.instructionsRepresentation.inlineText else {
			return [.init(validationErrors: [.invalidInlineInstructionsContent])]
		}

		return [.init(texts: [text])]
	}

	public static func buildBlock(_ components: [InstructionsFragment]...) -> [InstructionsFragment] {
		components.flatMap(\.self)
	}

	public static func buildOptional(_ component: [InstructionsFragment]?) -> [InstructionsFragment] {
		component ?? []
	}

	public static func buildEither(first component: [InstructionsFragment]) -> [InstructionsFragment] {
		component
	}

	public static func buildEither(second component: [InstructionsFragment]) -> [InstructionsFragment] {
		component
	}

	public static func buildArray(_ components: [[InstructionsFragment]]) -> [InstructionsFragment] {
		components.flatMap(\.self)
	}
}

public protocol InstructionsRepresentable {
	var instructionsRepresentation: Instructions { get }
}

@resultBuilder
public enum PromptBuilder {
	public static func buildExpression(_ expression: String) -> [String] {
		[expression]
	}

	public static func buildExpression<T: PromptRepresentable>(_ expression: T) -> [String] {
		[expression.promptRepresentation.text]
	}

	public static func buildBlock(_ components: [String]...) -> [String] {
		components.flatMap(\.self)
	}

	public static func buildOptional(_ component: [String]?) -> [String] {
		component ?? []
	}

	public static func buildEither(first component: [String]) -> [String] {
		component
	}

	public static func buildEither(second component: [String]) -> [String] {
		component
	}

	public static func buildArray(_ components: [[String]]) -> [String] {
		components.flatMap(\.self)
	}
}

public protocol PromptRepresentable {
	var promptRepresentation: Prompt { get }
}

/// A prompt value that can be reused in session DSL and tool-generated content.
public struct Prompt: Equatable, Hashable, Sendable, ExpressibleByStringLiteral, PromptRepresentable {
	public let text: String

	public init(_ text: String) {
		self.text = text
	}

	public init(@PromptBuilder _ content: () -> [String]) {
		self.text = content().joined(separator: "\n")
	}

	public init(stringLiteral value: StringLiteralType) {
		self.init(value)
	}

	public var promptRepresentation: Prompt { self }
}

/// Describes inline instructions or a hosted prompt reference for a session.
public struct Instructions: SessionComponentConvertible, InstructionsRepresentable {
	private enum Storage {
		case inline(String)
		case prompt(SessionConfiguration.Prompt)
	}

	private let storage: Storage
	private let validationErrors: [SessionConfigurationBuilderError]

	public init(_ text: String) {
		self.storage = .inline(text)
		self.validationErrors = []
	}

	public init(@InstructionsBuilder _ content: () -> [InstructionsFragment]) {
		let fragments = content()
		self.storage = .inline(fragments.flatMap(\.texts).joined(separator: "\n"))
		self.validationErrors = fragments.flatMap(\.validationErrors)
	}

	public init(_ id: String, version: String? = nil) {
		self.storage = .prompt(.init(id: id, version: version))
		self.validationErrors = []
	}

	public init(_ id: String, version: Int) {
		self.init(id, version: String(version))
	}

	public init(_ id: String, version: String? = nil, @HostedInstructionsBuilder _ content: () -> [HostedInstructionsComponent]) {
		var prompt = SessionConfiguration.Prompt(id: id, version: version)

		for component in content() {
			component.apply(&prompt)
		}

		self.storage = .prompt(prompt)
		self.validationErrors = []
	}

	public init(_ id: String, version: Int, @HostedInstructionsBuilder _ content: () -> [HostedInstructionsComponent]) {
		self.init(id, version: String(version), content)
	}

	fileprivate var inlineText: String? {
		guard case let .inline(text) = storage else { return nil }
		return text
	}

	public var instructionsRepresentation: Instructions { self }

	public var sessionComponent: SessionComponent {
		SessionComponent({ draft in
			switch storage {
				case let .inline(text):
					draft.instructions = text
					draft.prompt = nil
				case let .prompt(prompt):
					draft.prompt = prompt
					draft.instructions = nil
			}
		}, validationErrors: validationErrors)
	}
}

public struct HostedInstructionsComponent {
	fileprivate let apply: (inout SessionConfiguration.Prompt) -> Void

	fileprivate init(_ apply: @escaping (inout SessionConfiguration.Prompt) -> Void) {
		self.apply = apply
	}
}

public protocol HostedInstructionsComponentConvertible {
	var hostedInstructionsComponent: HostedInstructionsComponent { get }
}

@resultBuilder
public enum HostedInstructionsBuilder {
	public static func buildExpression<T: HostedInstructionsComponentConvertible>(_ expression: T) -> [HostedInstructionsComponent] {
		[expression.hostedInstructionsComponent]
	}

	public static func buildBlock(_ components: [HostedInstructionsComponent]...) -> [HostedInstructionsComponent] {
		components.flatMap(\.self)
	}
}

/// Supplies variables for a hosted prompt reference.
public struct Variables: HostedInstructionsComponentConvertible {
	private let values: [String: SessionConfiguration.Prompt.VariableValue]

	public init(_ values: [String: SessionConfiguration.Prompt.VariableValue]) {
		self.values = values
	}

	public init(_ values: [String: String]) {
		self.values = values.mapValues(SessionConfiguration.Prompt.VariableValue.string)
	}

	public var hostedInstructionsComponent: HostedInstructionsComponent {
		HostedInstructionsComponent { prompt in
			prompt.variables = values
		}
	}
}
