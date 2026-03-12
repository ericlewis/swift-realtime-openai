import Foundation

/// Configures turn detection for input audio.
public struct TurnDetection: AudioInputComponentConvertible {
	private let value: SessionConfiguration.AudioInput.TurnDetection
	private let validationErrors: [SessionConfigurationBuilderError]

	public init(@TurnDetectionBuilder _ content: () -> TurnDetectionKind) {
		let kind = content()
		self.value = kind.value
		self.validationErrors = kind.validationErrors
	}

	public var audioInputComponent: AudioInputComponent {
		AudioInputComponent({ input in
			input.turnDetection = value
		}, validationErrors: validationErrors)
	}
}

public struct TurnDetectionKind {
	fileprivate let value: SessionConfiguration.AudioInput.TurnDetection
	fileprivate let validationErrors: [SessionConfigurationBuilderError]

	fileprivate init(
		value: SessionConfiguration.AudioInput.TurnDetection,
		validationErrors: [SessionConfigurationBuilderError] = []
	) {
		self.value = value
		self.validationErrors = validationErrors
	}
}

@resultBuilder
public enum TurnDetectionBuilder {
	public static func buildExpression(_ expression: Semantic) -> TurnDetectionKind {
		TurnDetectionKind(value: expression.value, validationErrors: expression.validationErrors)
	}

	public static func buildExpression(_ expression: ServerVAD) -> TurnDetectionKind {
		TurnDetectionKind(value: expression.value, validationErrors: expression.validationErrors)
	}

	public static func buildBlock(_ component: TurnDetectionKind) -> TurnDetectionKind {
		component
	}

	public static func buildEither(first component: TurnDetectionKind) -> TurnDetectionKind {
		component
	}

	public static func buildEither(second component: TurnDetectionKind) -> TurnDetectionKind {
		component
	}
}

/// Configures semantic turn detection.
public struct Semantic {
	fileprivate let value: SessionConfiguration.AudioInput.TurnDetection
	fileprivate let validationErrors: [SessionConfigurationBuilderError]

	public init(interrupts: Bool, responds: Bool, @SemanticBuilder _ content: () -> [SemanticComponent] = { [] }) {
		var draft = SemanticDraft(interruptResponse: interrupts, createResponse: responds)
		let components = content()

		for component in components {
			component.apply(&draft)
		}

		self.value = draft.makeTurnDetection()
		self.validationErrors = components.flatMap(\.validationErrors)
	}
}

public struct SemanticComponent {
	fileprivate let apply: (inout SemanticDraft) -> Void
	fileprivate let validationErrors: [SessionConfigurationBuilderError]

	fileprivate init(_ apply: @escaping (inout SemanticDraft) -> Void, validationErrors: [SessionConfigurationBuilderError] = []) {
		self.apply = apply
		self.validationErrors = validationErrors
	}
}

public protocol SemanticComponentConvertible {
	var semanticComponent: SemanticComponent { get }
}

@resultBuilder
public enum SemanticBuilder {
	public static func buildExpression<T: SemanticComponentConvertible>(_ expression: T) -> [SemanticComponent] {
		[expression.semanticComponent]
	}

	public static func buildBlock(_ components: [SemanticComponent]...) -> [SemanticComponent] {
		components.flatMap(\.self)
	}
}

/// Sets semantic turn-detection eagerness.
public struct Eagerness: SemanticComponentConvertible {
	private let value: SessionConfiguration.AudioInput.TurnDetection.Eagerness

	public init(_ value: SessionConfiguration.AudioInput.TurnDetection.Eagerness) {
		self.value = value
	}

	public var semanticComponent: SemanticComponent {
		SemanticComponent { draft in
			draft.eagerness = value
		}
	}
}

/// Configures server-side VAD turn detection.
public struct ServerVAD {
	fileprivate let value: SessionConfiguration.AudioInput.TurnDetection
	fileprivate let validationErrors: [SessionConfigurationBuilderError]

	public init(interrupts: Bool, responds: Bool, @ServerVADBuilder _ content: () -> [ServerVADComponent] = { [] }) {
		var draft = ServerVADDraft(interruptResponse: interrupts, createResponse: responds)
		let components = content()

		for component in components {
			component.apply(&draft)
		}

		self.value = draft.makeTurnDetection()
		self.validationErrors = components.flatMap(\.validationErrors)
	}
}

public struct ServerVADComponent {
	fileprivate let apply: (inout ServerVADDraft) -> Void
	fileprivate let validationErrors: [SessionConfigurationBuilderError]

	fileprivate init(_ apply: @escaping (inout ServerVADDraft) -> Void, validationErrors: [SessionConfigurationBuilderError] = []) {
		self.apply = apply
		self.validationErrors = validationErrors
	}
}

public protocol ServerVADComponentConvertible {
	var serverVADComponent: ServerVADComponent { get }
}

@resultBuilder
public enum ServerVADBuilder {
	public static func buildExpression<T: ServerVADComponentConvertible>(_ expression: T) -> [ServerVADComponent] {
		[expression.serverVADComponent]
	}

	public static func buildBlock(_ components: [ServerVADComponent]...) -> [ServerVADComponent] {
		components.flatMap(\.self)
	}
}

/// A convenience duration wrapper used by audio timing directives.
public struct TimeAmount: Equatable, Hashable, Sendable {
	fileprivate let milliseconds: Int

	private init(milliseconds: Int) {
		self.milliseconds = milliseconds
	}

	public static func milliseconds(_ value: Int) -> Self {
		.init(milliseconds: value)
	}

	public static func seconds(_ value: Double) -> Self {
		.init(milliseconds: Int((value * 1000).rounded()))
	}
}

/// Configures how much audio to retain before speech starts.
public struct PrefixPadding: ServerVADComponentConvertible {
	private let value: Int
	private let validationErrors: [SessionConfigurationBuilderError]

	public init(_ amount: TimeAmount) {
		self.value = amount.milliseconds
		self.validationErrors = amount.milliseconds >= 0 ? [] : [.invalidPrefixPadding(amount.milliseconds)]
	}

	public var serverVADComponent: ServerVADComponent {
		ServerVADComponent({ draft in
			draft.prefixPaddingMs = value
		}, validationErrors: validationErrors)
	}
}

/// Configures how much silence ends a server-VAD turn.
public struct SilenceDuration: ServerVADComponentConvertible {
	private let value: Int
	private let validationErrors: [SessionConfigurationBuilderError]

	public init(_ amount: TimeAmount) {
		self.value = amount.milliseconds
		self.validationErrors = amount.milliseconds > 0 ? [] : [.invalidSilenceDuration(amount.milliseconds)]
	}

	public var serverVADComponent: ServerVADComponent {
		ServerVADComponent({ draft in
			draft.silenceDurationMs = value
		}, validationErrors: validationErrors)
	}
}

/// Configures the idle timeout used by server-VAD.
public struct IdleTimeout: ServerVADComponentConvertible {
	private let value: Int
	private let validationErrors: [SessionConfigurationBuilderError]

	public init(_ amount: TimeAmount) {
		self.value = amount.milliseconds
		self.validationErrors = amount.milliseconds > 0 ? [] : [.invalidIdleTimeout(amount.milliseconds)]
	}

	public var serverVADComponent: ServerVADComponent {
		ServerVADComponent({ draft in
			draft.idleTimeoutMs = value
		}, validationErrors: validationErrors)
	}
}

/// Configures the server-VAD activation threshold.
public struct Threshold: ServerVADComponentConvertible {
	public enum Level: Equatable, Hashable, Sendable {
		case low, medium, high

		fileprivate var numericValue: Double {
			switch self {
				case .low: 0.3
				case .medium: 0.5
				case .high: 0.7
			}
		}
	}

	private let value: Double
	private let validationErrors: [SessionConfigurationBuilderError]

	public init(_ value: Double) {
		self.value = value
		self.validationErrors = (0...1).contains(value) ? [] : [.invalidThreshold(value)]
	}

	public init(_ value: Level) {
		self.value = value.numericValue
		self.validationErrors = []
	}

	public var serverVADComponent: ServerVADComponent {
		ServerVADComponent({ draft in
			draft.threshold = value
		}, validationErrors: validationErrors)
	}
}

private struct SemanticDraft {
	var interruptResponse: Bool
	var createResponse: Bool
	var eagerness: SessionConfiguration.AudioInput.TurnDetection.Eagerness?

	func makeTurnDetection() -> SessionConfiguration.AudioInput.TurnDetection {
		.semanticVAD(
			createResponse: createResponse,
			eagerness: eagerness,
			interruptResponse: interruptResponse
		)
	}
}

private struct ServerVADDraft {
	var interruptResponse: Bool
	var createResponse: Bool
	var idleTimeoutMs: Int?
	var prefixPaddingMs: Int?
	var silenceDurationMs: Int?
	var threshold: Double?

	func makeTurnDetection() -> SessionConfiguration.AudioInput.TurnDetection {
		.serverVAD(
			createResponse: createResponse,
			idleTimeoutMs: idleTimeoutMs,
			interruptResponse: interruptResponse,
			prefixPaddingMs: prefixPaddingMs,
			silenceDurationMs: silenceDurationMs,
			threshold: threshold
		)
	}
}
