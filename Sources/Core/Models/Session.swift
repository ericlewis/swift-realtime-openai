import Foundation

public enum Session: Equatable, Hashable, Sendable {
	public enum OutputModality: String, Equatable, Hashable, Codable, Sendable {
		case text, audio
	}

	public enum Include: String, Equatable, Hashable, Codable, Sendable {
		case inputAudioTranscriptionLogprobs = "item.input_audio_transcription.logprobs"
	}

	public enum MaxOutputTokens: Equatable, Hashable, Codable, Sendable {
		case inf
		case limited(Int)

		public func encode(to encoder: any Encoder) throws {
			var container = encoder.singleValueContainer()

			switch self {
				case .inf:
					try container.encode("inf")
				case let .limited(value):
					try container.encode(value)
			}
		}

		public init(from decoder: any Decoder) throws {
			let container = try decoder.singleValueContainer()

			if let stringValue = try? container.decode(String.self), stringValue == "inf" {
				self = .inf
				return
			}

			self = .limited(try container.decode(Int.self))
		}
	}

	public struct Prompt: Equatable, Hashable, Codable, Sendable {
		public enum VariableValue: Equatable, Hashable, Sendable {
			public struct InputImage: Equatable, Hashable, Codable, Sendable {
				public var detail: Item.Message.InputImage.Detail?
				public var fileId: String?
				public var imageUrl: String?

				public init(detail: Item.Message.InputImage.Detail? = nil, fileId: String? = nil, imageUrl: String? = nil) {
					self.detail = detail
					self.fileId = fileId
					self.imageUrl = imageUrl
				}
			}

			public struct InputFile: Equatable, Hashable, Codable, Sendable {
				public enum Detail: String, Equatable, Hashable, Codable, Sendable {
					case low
					case high
				}

				public var detail: Detail?
				public var fileData: String?
				public var fileId: String?
				public var fileUrl: String?
				public var filename: String?

				public init(
					detail: Detail? = nil,
					fileData: String? = nil,
					fileId: String? = nil,
					fileUrl: String? = nil,
					filename: String? = nil
				) {
					self.detail = detail
					self.fileData = fileData
					self.fileId = fileId
					self.fileUrl = fileUrl
					self.filename = filename
				}
			}

			case string(String)
			case inputText(String)
			case inputImage(InputImage)
			case inputFile(InputFile)
		}

		public var id: String
		public var version: String?
		public var variables: [String: VariableValue]?

		public init(id: String, version: String? = nil, variables: [String: VariableValue]? = nil) {
			self.id = id
			self.version = version
			self.variables = variables
		}
	}

	public enum Voice: Equatable, Hashable, Sendable {
		public enum BuiltIn: String, Equatable, Hashable, Codable, Sendable {
			case alloy
			case ash
			case ballad
			case coral
			case echo
			case sage
			case shimmer
			case verse
			case marin
			case cedar
		}

		case builtIn(BuiltIn)
		case string(String)
		case custom(id: String)

		public static var alloy: Self { .builtIn(.alloy) }
		public static var ash: Self { .builtIn(.ash) }
		public static var ballad: Self { .builtIn(.ballad) }
		public static var coral: Self { .builtIn(.coral) }
		public static var echo: Self { .builtIn(.echo) }
		public static var sage: Self { .builtIn(.sage) }
		public static var shimmer: Self { .builtIn(.shimmer) }
		public static var verse: Self { .builtIn(.verse) }
		public static var marin: Self { .builtIn(.marin) }
		public static var cedar: Self { .builtIn(.cedar) }

		public var stringValue: String? {
			switch self {
				case let .builtIn(value):
					value.rawValue
				case let .string(value):
					value
				case .custom:
					nil
			}
		}
	}

	public struct AudioFormat: Equatable, Hashable, Codable, Sendable {
		public var rate: Int?
		public var type: String

		public init(type: String, rate: Int? = nil) {
			self.rate = rate
			self.type = type
		}

		public static let pcm24kMono = Self(type: "audio/pcm", rate: 24000)
		public static let pcmu = Self(type: "audio/pcmu")
		public static let pcma = Self(type: "audio/pcma")
	}

	public enum Tracing: Equatable, Hashable, Codable, Sendable {
		public struct Configuration: Equatable, Hashable, Codable, Sendable {
			public var groupId: String?
			public var metadata: JSONValue?
			public var workflowName: String?

			public init(groupId: String? = nil, metadata: JSONValue? = nil, workflowName: String? = nil) {
				self.groupId = groupId
				self.metadata = metadata
				self.workflowName = workflowName
			}
		}

		case auto
		case configuration(Configuration)

		public func encode(to encoder: any Encoder) throws {
			switch self {
				case .auto:
					try "auto".encode(to: encoder)
				case let .configuration(configuration):
					try configuration.encode(to: encoder)
			}
		}

		public init(from decoder: any Decoder) throws {
			if let value = try? String(from: decoder), value == "auto" {
				self = .auto
				return
			}

			self = .configuration(try Configuration(from: decoder))
		}
	}

	public enum Truncation: Equatable, Hashable, Codable, Sendable {
		public struct RetentionRatio: Equatable, Hashable, Codable, Sendable {
			public struct TokenLimits: Equatable, Hashable, Codable, Sendable {
				public var postInstructions: Int?

				public init(postInstructions: Int? = nil) {
					self.postInstructions = postInstructions
				}
			}

			public var retentionRatio: Double
			public var tokenLimits: TokenLimits?

			public init(retentionRatio: Double, tokenLimits: TokenLimits? = nil) {
				self.retentionRatio = retentionRatio
				self.tokenLimits = tokenLimits
			}
		}

		case auto
		case disabled
		case retentionRatio(RetentionRatio)

		private enum CodingKeys: String, CodingKey {
			case type
		}

		public func encode(to encoder: any Encoder) throws {
			switch self {
				case .auto:
					try "auto".encode(to: encoder)
				case .disabled:
					try "disabled".encode(to: encoder)
				case let .retentionRatio(value):
					var container = encoder.container(keyedBy: CodingKeys.self)
					try container.encode("retention_ratio", forKey: .type)
					try value.encode(to: encoder)
			}
		}

		public init(from decoder: any Decoder) throws {
			if let value = try? String(from: decoder) {
				switch value {
					case "auto": self = .auto
					case "disabled": self = .disabled
					default:
						throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid truncation strategy: \(value)"))
				}
				return
			}

			let container = try decoder.container(keyedBy: CodingKeys.self)
			let type = try container.decode(String.self, forKey: .type)
			guard type == "retention_ratio" else {
				throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid truncation strategy: \(type)")
			}

			self = .retentionRatio(try RetentionRatio(from: decoder))
		}
	}

	public struct ConversationResource: Equatable, Hashable, Codable, Sendable {
		public var id: String?
		public var object: String?

		public init(id: String? = nil, object: String? = nil) {
			self.id = id
			self.object = object
		}
	}

	public struct AudioInput: Equatable, Hashable, Codable, Sendable {
		public struct Transcription: Equatable, Hashable, Codable, Sendable {
			public var language: String?
			public var model: Model.Transcription?
			public var prompt: String?

			public init(language: String? = nil, model: Model.Transcription? = nil, prompt: String? = nil) {
				self.language = language
				self.model = model
				self.prompt = prompt
			}
		}

		public struct NoiseReduction: Equatable, Hashable, Codable, Sendable {
			public enum Kind: String, Equatable, Hashable, Codable, Sendable {
				case nearField = "near_field"
				case farField = "far_field"
			}

			public var type: Kind

			public init(type: Kind) {
				self.type = type
			}

			public static let nearField = Self(type: .nearField)
			public static let farField = Self(type: .farField)
		}

		public struct TurnDetection: Equatable, Hashable, Codable, Sendable {
			public enum Kind: String, Equatable, Hashable, Codable, Sendable {
				case serverVAD = "server_vad"
				case semanticVAD = "semantic_vad"
			}

			public enum Eagerness: String, Equatable, Hashable, Codable, Sendable {
				case auto, low, medium, high
			}

			public var type: Kind
			public var createResponse: Bool?
			public var eagerness: Eagerness?
			public var idleTimeoutMs: Int?
			public var interruptResponse: Bool?
			public var prefixPaddingMs: Int?
			public var silenceDurationMs: Int?
			public var threshold: Double?

			public init(
				type: Kind,
				createResponse: Bool? = nil,
				eagerness: Eagerness? = nil,
				idleTimeoutMs: Int? = nil,
				interruptResponse: Bool? = nil,
				prefixPaddingMs: Int? = nil,
				silenceDurationMs: Int? = nil,
				threshold: Double? = nil
			) {
				self.type = type
				self.createResponse = createResponse
				self.eagerness = eagerness
				self.idleTimeoutMs = idleTimeoutMs
				self.interruptResponse = interruptResponse
				self.prefixPaddingMs = prefixPaddingMs
				self.silenceDurationMs = silenceDurationMs
				self.threshold = threshold
			}

			public static func serverVAD(
				createResponse: Bool? = nil,
				idleTimeoutMs: Int? = nil,
				interruptResponse: Bool? = nil,
				prefixPaddingMs: Int? = nil,
				silenceDurationMs: Int? = nil,
				threshold: Double? = nil
			) -> Self {
				.init(
					type: .serverVAD,
					createResponse: createResponse,
					idleTimeoutMs: idleTimeoutMs,
					interruptResponse: interruptResponse,
					prefixPaddingMs: prefixPaddingMs,
					silenceDurationMs: silenceDurationMs,
					threshold: threshold
				)
			}

			public static func semanticVAD(
				createResponse: Bool? = nil,
				eagerness: Eagerness? = nil,
				interruptResponse: Bool? = nil
			) -> Self {
				.init(
					type: .semanticVAD,
					createResponse: createResponse,
					eagerness: eagerness,
					interruptResponse: interruptResponse
				)
			}
		}

		public var format: AudioFormat?
		public var noiseReduction: NoiseReduction?
		public var transcription: Transcription?
		public var turnDetection: TurnDetection?

		public init(
			format: AudioFormat? = nil,
			noiseReduction: NoiseReduction? = nil,
			transcription: Transcription? = nil,
			turnDetection: TurnDetection? = nil
		) {
			self.format = format
			self.noiseReduction = noiseReduction
			self.transcription = transcription
			self.turnDetection = turnDetection
		}
	}

	public struct AudioOutput: Equatable, Hashable, Codable, Sendable {
		public var format: AudioFormat?
		public var speed: Double?
		public var voice: Voice?

		public init(format: AudioFormat? = nil, speed: Double? = nil, voice: Voice? = nil) {
			self.format = format
			self.speed = speed
			self.voice = voice
		}
	}

	public struct Realtime: Equatable, Hashable, Codable, Sendable {
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
		public var toolChoice: Tool.Choice?
		public var tools: [Tool]?
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
			toolChoice: Tool.Choice? = nil,
			tools: [Tool]? = nil,
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

	public struct Transcription: Equatable, Hashable, Codable, Sendable {
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

	case realtime(Realtime)
	case transcription(Transcription)

	public var id: String? {
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

	public var object: String? {
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

extension Session.Prompt.VariableValue: Codable {
	private enum CodingKeys: String, CodingKey {
		case detail
		case fileData
		case fileId
		case fileUrl
		case filename
		case imageUrl
		case text
		case type
	}

	public init(from decoder: any Decoder) throws {
		if let value = try? String(from: decoder) {
			self = .string(value)
			return
		}

		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(String.self, forKey: .type)

		switch type {
			case "input_text":
				self = .inputText(try container.decode(String.self, forKey: .text))
			case "input_image":
				self = .inputImage(.init(
					detail: try container.decodeIfPresent(Item.Message.InputImage.Detail.self, forKey: .detail),
					fileId: try container.decodeIfPresent(String.self, forKey: .fileId),
					imageUrl: try container.decodeIfPresent(String.self, forKey: .imageUrl)
				))
			case "input_file":
				self = .inputFile(.init(
					detail: try container.decodeIfPresent(Session.Prompt.VariableValue.InputFile.Detail.self, forKey: .detail),
					fileData: try container.decodeIfPresent(String.self, forKey: .fileData),
					fileId: try container.decodeIfPresent(String.self, forKey: .fileId),
					fileUrl: try container.decodeIfPresent(String.self, forKey: .fileUrl),
					filename: try container.decodeIfPresent(String.self, forKey: .filename)
				))
			default:
				throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unsupported prompt variable value type: \(type)")
		}
	}

	public func encode(to encoder: any Encoder) throws {
		switch self {
			case let .string(value):
				try value.encode(to: encoder)
			case let .inputText(value):
				var container = encoder.container(keyedBy: CodingKeys.self)
				try container.encode("input_text", forKey: .type)
				try container.encode(value, forKey: .text)
			case let .inputImage(value):
				var container = encoder.container(keyedBy: CodingKeys.self)
				try container.encode("input_image", forKey: .type)
				try container.encodeIfPresent(value.detail, forKey: .detail)
				try container.encodeIfPresent(value.fileId, forKey: .fileId)
				try container.encodeIfPresent(value.imageUrl, forKey: .imageUrl)
			case let .inputFile(value):
				var container = encoder.container(keyedBy: CodingKeys.self)
				try container.encode("input_file", forKey: .type)
				try container.encodeIfPresent(value.detail, forKey: .detail)
				try container.encodeIfPresent(value.fileData, forKey: .fileData)
				try container.encodeIfPresent(value.fileId, forKey: .fileId)
				try container.encodeIfPresent(value.fileUrl, forKey: .fileUrl)
				try container.encodeIfPresent(value.filename, forKey: .filename)
		}
	}
}

extension Session.Voice: Codable {
	private enum CodingKeys: String, CodingKey {
		case id
	}

	public init(from decoder: any Decoder) throws {
		if let value = try? String(from: decoder) {
			if let builtIn = BuiltIn(rawValue: value) {
				self = .builtIn(builtIn)
			} else {
				self = .string(value)
			}
			return
		}

		let container = try decoder.container(keyedBy: CodingKeys.self)
		self = .custom(id: try container.decode(String.self, forKey: .id))
	}

	public func encode(to encoder: any Encoder) throws {
		switch self {
			case let .builtIn(value):
				try value.rawValue.encode(to: encoder)
			case let .string(value):
				try value.encode(to: encoder)
			case let .custom(id):
				var container = encoder.container(keyedBy: CodingKeys.self)
				try container.encode(id, forKey: .id)
		}
	}
}

extension Session: Codable {
	private enum CodingKeys: String, CodingKey {
		case type
	}

	public func encode(to encoder: any Encoder) throws {
		switch self {
			case let .realtime(session):
				var container = encoder.container(keyedBy: CodingKeys.self)
				try container.encode("realtime", forKey: .type)
				try session.encode(to: encoder)
			case let .transcription(session):
				var container = encoder.container(keyedBy: CodingKeys.self)
				try container.encode("transcription", forKey: .type)
				try session.encode(to: encoder)
		}
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(String.self, forKey: .type)

		switch type {
			case "realtime":
				self = .realtime(try Realtime(from: decoder))
			case "transcription":
				self = .transcription(try Transcription(from: decoder))
			default:
				throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown session type: \(type)")
		}
	}
}
