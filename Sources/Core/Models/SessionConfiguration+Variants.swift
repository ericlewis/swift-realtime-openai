import Foundation

public extension SessionConfiguration {
	/// The configuration payload for a full realtime assistant session.
	struct Realtime: Equatable, Hashable, Codable, Sendable {
		/// Bundles input and output audio configuration for a realtime session.
		public struct Audio: Equatable, Hashable, Codable, Sendable {
			public var input: AudioInput?
			public var output: AudioOutput?

			public init(input: AudioInput? = nil, output: AudioOutput? = nil) {
				self.input = input
				self.output = output
			}
		}

		public var id: String?
		public var object: String?
		public var audio: Audio?
		public var include: [Include]?
		public var instructions: String?
		public var maxOutputTokens: MaxOutputTokens?
		public var model: Model?
		public var outputModalities: [OutputModality]?
		public var prompt: Prompt?
		public var toolChoice: ToolChoice?
		public var tools: [ToolDefinition]?
		public var tracing: Tracing?
		public var truncation: Truncation?

		public init(
			id: String? = nil,
			object: String? = nil,
			audio: Audio? = nil,
			include: [Include]? = nil,
			instructions: String? = nil,
			maxOutputTokens: MaxOutputTokens? = nil,
			model: Model? = nil,
			outputModalities: [OutputModality]? = nil,
			prompt: Prompt? = nil,
			toolChoice: ToolChoice? = nil,
			tools: [ToolDefinition]? = nil,
			tracing: Tracing? = nil,
			truncation: Truncation? = nil
		) {
			self.id = id
			self.object = object
			self.audio = audio
			self.include = include
			self.instructions = instructions
			self.maxOutputTokens = maxOutputTokens
			self.model = model
			self.outputModalities = outputModalities
			self.prompt = prompt
			self.toolChoice = toolChoice
			self.tools = tools
			self.tracing = tracing
			self.truncation = truncation
		}
	}

	/// The configuration payload for a transcription-only realtime session.
	struct Transcription: Equatable, Hashable, Codable, Sendable {
		/// Bundles audio input configuration for a transcription session.
		public struct Audio: Equatable, Hashable, Codable, Sendable {
			public var input: AudioInput?

			public init(input: AudioInput? = nil) {
				self.input = input
			}
		}

		public var id: String?
		public var object: String?
		public var audio: Audio?
		public var expiresAt: Double?
		public var include: [Include]?

		public init(id: String? = nil, object: String? = nil, audio: Audio? = nil, expiresAt: Double? = nil, include: [Include]? = nil) {
			self.id = id
			self.object = object
			self.audio = audio
			self.expiresAt = expiresAt
			self.include = include
		}
	}

	var id: String? {
		get {
			switch self {
				case let .realtime(session): session.id
				case let .transcription(session): session.id
			}
		}
		set {
			switch self {
				case var .realtime(session):
					session.id = newValue
					self = .realtime(session)
				case var .transcription(session):
					session.id = newValue
					self = .transcription(session)
			}
		}
	}

	var object: String? {
		get {
			switch self {
				case let .realtime(session): session.object
				case let .transcription(session): session.object
			}
		}
		set {
			switch self {
				case var .realtime(session):
					session.object = newValue
					self = .realtime(session)
				case var .transcription(session):
					session.object = newValue
					self = .transcription(session)
			}
		}
	}
}
