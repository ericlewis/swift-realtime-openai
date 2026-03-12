import Foundation

struct SessionDraft {
	let model: Model
	var instructions: String?
	var prompt: SessionConfiguration.Prompt?
	var outputModalities: [SessionConfiguration.OutputModality]?
	var maxOutputTokens: SessionConfiguration.MaxOutputTokens?
	var audioInput: SessionConfiguration.AudioInput?
	var audioOutput: SessionConfiguration.AudioOutput?
	var include: [SessionConfiguration.Include] = []
	var toolChoice: ToolChoice?
	var tools: [ToolDefinition] = []
	var tracing: SessionConfiguration.Tracing?
	var truncation: SessionConfiguration.Truncation?

	func makeSession() -> SessionConfiguration {
		let audio: SessionConfiguration.Realtime.Audio? = if audioInput == nil, audioOutput == nil {
			nil
		} else {
			.init(input: audioInput, output: audioOutput)
		}

		return .realtime(.init(
			audio: audio,
			include: include.orderedUnique.nilIfEmpty,
			instructions: instructions,
			maxOutputTokens: maxOutputTokens,
			model: model,
			outputModalities: outputModalities,
			prompt: prompt,
			toolChoice: toolChoice,
			tools: tools.nilIfEmpty,
			tracing: tracing,
			truncation: truncation
		))
	}
}

private extension Array where Element: Hashable {
	var orderedUnique: [Element] {
		var seen = Set<Element>()
		return filter { seen.insert($0).inserted }
	}
}

private extension Array {
	var nilIfEmpty: Self? {
		isEmpty ? nil : self
	}
}

extension SessionConfiguration.Prompt.VariableValue: ExpressibleByStringLiteral {
	public init(stringLiteral value: StringLiteralType) {
		self = .string(value)
	}
}

extension String: InstructionsRepresentable {
	public var instructionsRepresentation: Instructions {
		Instructions(self)
	}
}

extension String: PromptRepresentable {
	public var promptRepresentation: Prompt {
		Prompt(self)
	}
}

extension Prompt: InstructionsRepresentable {
	public var instructionsRepresentation: Instructions {
		Instructions(text)
	}
}

public extension SessionConfiguration.Include {
	static let inputAudioTranscriptionLogProbs = Self.inputAudioTranscriptionLogprobs
}
