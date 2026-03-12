import Foundation

/// Configures output audio for a session in the DSL.
public struct AudioOutput: SessionComponentConvertible {
	private let value: SessionConfiguration.AudioOutput
	private let validationErrors: [SessionConfigurationBuilderError]

	public init(_ format: SessionConfiguration.AudioFormat? = nil, @AudioOutputBuilder _ content: () -> [AudioOutputComponent] = { [] }) {
		var draft = AudioOutputDraft(format: format)
		let components = content()

		for component in components {
			component.apply(&draft)
		}

		self.value = draft.makeAudioOutput()
		self.validationErrors = components.flatMap(\.validationErrors)
	}

	public var sessionComponent: SessionComponent {
		SessionComponent({ draft in
			draft.audioOutput = value
		}, validationErrors: validationErrors)
	}
}

public struct AudioOutputComponent {
	fileprivate let apply: (inout AudioOutputDraft) -> Void
	fileprivate let validationErrors: [SessionConfigurationBuilderError]

	fileprivate init(_ apply: @escaping (inout AudioOutputDraft) -> Void, validationErrors: [SessionConfigurationBuilderError] = []) {
		self.apply = apply
		self.validationErrors = validationErrors
	}
}

public protocol AudioOutputComponentConvertible {
	var audioOutputComponent: AudioOutputComponent { get }
}

@resultBuilder
public enum AudioOutputBuilder {
	public static func buildExpression<T: AudioOutputComponentConvertible>(_ expression: T) -> [AudioOutputComponent] {
		[expression.audioOutputComponent]
	}

	public static func buildBlock(_ components: [AudioOutputComponent]...) -> [AudioOutputComponent] {
		components.flatMap(\.self)
	}
}

/// Chooses the output voice and optional playback speed.
public struct Voice: AudioOutputComponentConvertible {
	private let value: SessionConfiguration.Voice
	private var speedValue: Double?
	private var validationErrors: [SessionConfigurationBuilderError]

	public init(_ value: SessionConfiguration.Voice) {
		self.value = value
		self.speedValue = nil
		self.validationErrors = []
	}

	public func speed(_ value: Double) -> Self {
		var copy = self
		if (0.25...1.5).contains(value) {
			copy.speedValue = value
		} else {
			copy.validationErrors.append(.invalidVoiceSpeed(value))
		}
		return copy
	}

	public var audioOutputComponent: AudioOutputComponent {
		AudioOutputComponent({ draft in
			draft.voice = value
			draft.speed = speedValue
		}, validationErrors: validationErrors)
	}
}

private struct AudioOutputDraft {
	var format: SessionConfiguration.AudioFormat?
	var speed: Double?
	var voice: SessionConfiguration.Voice?

	func makeAudioOutput() -> SessionConfiguration.AudioOutput {
		.init(format: format, speed: speed, voice: voice)
	}
}
