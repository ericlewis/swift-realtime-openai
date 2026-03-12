import Foundation

/// Configures input audio for a session in the DSL.
public struct AudioInput: SessionComponentConvertible {
	private let value: SessionConfiguration.AudioInput
	private let validationErrors: [SessionConfigurationBuilderError]

	public init(_ format: SessionConfiguration.AudioFormat? = nil, @AudioInputBuilder _ content: () -> [AudioInputComponent] = { [] }) {
		var draft = SessionConfiguration.AudioInput(format: format)
		let components = content()

		for component in components {
			component.apply(&draft)
		}

		self.value = draft
		self.validationErrors = components.flatMap(\.validationErrors)
	}

	public var sessionComponent: SessionComponent {
		SessionComponent({ draft in
			draft.audioInput = value
		}, validationErrors: validationErrors)
	}
}

public struct AudioInputComponent {
	let apply: (inout SessionConfiguration.AudioInput) -> Void
	let validationErrors: [SessionConfigurationBuilderError]

	init(_ apply: @escaping (inout SessionConfiguration.AudioInput) -> Void, validationErrors: [SessionConfigurationBuilderError] = []) {
		self.apply = apply
		self.validationErrors = validationErrors
	}
}

public protocol AudioInputComponentConvertible {
	var audioInputComponent: AudioInputComponent { get }
}

@resultBuilder
public enum AudioInputBuilder {
	public static func buildExpression<T: AudioInputComponentConvertible>(_ expression: T) -> [AudioInputComponent] {
		[expression.audioInputComponent]
	}

	public static func buildBlock(_ components: [AudioInputComponent]...) -> [AudioInputComponent] {
		components.flatMap(\.self)
	}
}

/// Enables or tunes input noise reduction.
public struct NoiseReduction: AudioInputComponentConvertible {
	private let value: SessionConfiguration.AudioInput.NoiseReduction

	public init(_ value: SessionConfiguration.AudioInput.NoiseReduction) {
		self.value = value
	}

	public var audioInputComponent: AudioInputComponent {
		AudioInputComponent { input in
			input.noiseReduction = value
		}
	}
}

/// Configures asynchronous input transcription for audio written to the input buffer.
public struct Transcription: AudioInputComponentConvertible {
	private let value: SessionConfiguration.AudioInput.Transcription
	private let validationErrors: [SessionConfigurationBuilderError]

	public init(_ model: Model.Transcription, @TranscriptionBuilder _ content: () -> [TranscriptionComponent] = { [] }) {
		var draft = SessionConfiguration.AudioInput.Transcription(model: model)
		let components = content()

		for component in components {
			component.apply(&draft)
		}

		self.value = draft
		self.validationErrors = components.flatMap(\.validationErrors)
	}

	public var audioInputComponent: AudioInputComponent {
		AudioInputComponent({ input in
			input.transcription = value
		}, validationErrors: validationErrors)
	}
}

public struct TranscriptionComponent {
	fileprivate let apply: (inout SessionConfiguration.AudioInput.Transcription) -> Void
	fileprivate let validationErrors: [SessionConfigurationBuilderError]

	fileprivate init(_ apply: @escaping (inout SessionConfiguration.AudioInput.Transcription) -> Void, validationErrors: [SessionConfigurationBuilderError] = []) {
		self.apply = apply
		self.validationErrors = validationErrors
	}
}

public protocol TranscriptionComponentConvertible {
	var transcriptionComponent: TranscriptionComponent { get }
}

@resultBuilder
public enum TranscriptionBuilder {
	public static func buildExpression<T: TranscriptionComponentConvertible>(_ expression: T) -> [TranscriptionComponent] {
		[expression.transcriptionComponent]
	}

	public static func buildBlock(_ components: [TranscriptionComponent]...) -> [TranscriptionComponent] {
		components.flatMap(\.self)
	}
}

/// Sets the transcription language hint.
public struct Language: TranscriptionComponentConvertible {
	public struct Code: Equatable, Hashable, Sendable {
		public let rawValue: String

		public init(_ rawValue: String) {
			self.rawValue = rawValue
		}

		public static let english = Self("en")
	}

	private let code: String

	public init(_ code: Code) {
		self.code = code.rawValue
	}

	public init(_ code: String) {
		self.code = code
	}

	public var transcriptionComponent: TranscriptionComponent {
		TranscriptionComponent { transcription in
			transcription.language = code
		}
	}
}

extension Prompt: TranscriptionComponentConvertible {
	public var transcriptionComponent: TranscriptionComponent {
		TranscriptionComponent { transcription in
			transcription.prompt = text
		}
	}
}
