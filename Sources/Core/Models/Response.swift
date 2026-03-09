public struct Response: Identifiable, Equatable, Hashable, Codable, Sendable {
	public struct Config: Equatable, Hashable, Codable, Sendable {
		public enum Conversation: String, Equatable, Hashable, Codable, Sendable {
			case auto
			case none
		}

		public struct Audio: Equatable, Hashable, Codable, Sendable {
			public var output: Session.AudioOutput?

			public init(output: Session.AudioOutput? = nil) {
				self.output = output
			}
		}

		public var audio: Audio?
		public var conversation: Conversation?
		public var input: [InputItem]?
		public var instructions: String?
		public var maxOutputTokens: Session.MaxOutputTokens?
		public var metadata: [String: String]?
		public var outputModalities: [Session.OutputModality]?
		public var prompt: Session.Prompt?
		public var temperature: Double?
		public var toolChoice: ToolChoice?
		public var tools: [ToolDefinition]?

		public init(
			audio: Audio? = nil,
			conversation: Conversation? = nil,
			input: [InputItem]? = nil,
			instructions: String? = nil,
			maxOutputTokens: Session.MaxOutputTokens? = nil,
			metadata: [String: String]? = nil,
			outputModalities: [Session.OutputModality]? = nil,
			prompt: Session.Prompt? = nil,
			temperature: Double? = nil,
			toolChoice: ToolChoice? = nil,
			tools: [ToolDefinition]? = nil
		) {
			self.audio = audio
			self.conversation = conversation
			self.input = input
			self.instructions = instructions
			self.maxOutputTokens = maxOutputTokens
			self.metadata = metadata
			self.outputModalities = outputModalities
			self.prompt = prompt
			self.temperature = temperature
			self.toolChoice = toolChoice
			self.tools = tools
		}
	}

	public enum InputItem: Equatable, Hashable, Sendable {
		public struct Message: Equatable, Hashable, Codable, Sendable {
			public enum Content: Equatable, Hashable, Sendable {
				case inputText(String)
				case inputAudio(Item.Audio)
				case inputImage(Item.Message.InputImage)
				case text(String)
				case itemReference(id: String)
			}

			public var content: [Content]
			public var id: String?
			public var object: String?
			public var role: Item.Message.Role
			public var status: Item.Status?

			public init(
				id: String? = nil,
				object: String? = nil,
				role: Item.Message.Role,
				status: Item.Status? = nil,
				content: [Content]
			) {
				self.content = content
				self.id = id
				self.object = object
				self.role = role
				self.status = status
			}
		}

		public struct FunctionCall: Equatable, Hashable, Codable, Sendable {
			public var arguments: String
			public var callId: String?
			public var id: String?
			public var name: String
			public var object: String?
			public var status: Item.Status?

			public init(
				id: String? = nil,
				object: String? = nil,
				status: Item.Status? = nil,
				callId: String? = nil,
				name: String,
				arguments: String
			) {
				self.arguments = arguments
				self.callId = callId
				self.id = id
				self.name = name
				self.object = object
				self.status = status
			}
		}

		public struct FunctionCallOutput: Equatable, Hashable, Codable, Sendable {
			public var callId: String
			public var id: String?
			public var object: String?
			public var output: String
			public var status: Item.Status?

			public init(id: String? = nil, object: String? = nil, status: Item.Status? = nil, callId: String, output: String) {
				self.callId = callId
				self.id = id
				self.object = object
				self.output = output
				self.status = status
			}
		}

		case message(Message)
		case functionCall(FunctionCall)
		case functionCallOutput(FunctionCallOutput)
		case itemReference(id: String)
	}

	public enum ContentPart: Equatable, Hashable, Sendable {
		case outputText(String)
		case outputAudio(Item.Audio)
	}

	public enum Status: String, Equatable, Hashable, Codable, Sendable {
		case failed
		case completed
		case cancelled
		case incomplete
		case inProgress = "in_progress"
	}

	public enum Usage: Equatable, Hashable, Sendable {
		public struct TokenUsage: Equatable, Hashable, Codable, Sendable {
			public struct InputTokenDetails: Equatable, Hashable, Codable, Sendable {
				public struct CachedTokensDetails: Equatable, Hashable, Codable, Sendable {
					public let audioTokens: Int?
					public let textTokens: Int?

					public init(audioTokens: Int? = nil, textTokens: Int? = nil) {
						self.audioTokens = audioTokens
						self.textTokens = textTokens
					}
				}

				public let audioTokens: Int?
				public let cachedTokens: Int?
				public let cachedTokensDetails: CachedTokensDetails?
				public let textTokens: Int?

				public init(audioTokens: Int? = nil, cachedTokens: Int? = nil, cachedTokensDetails: CachedTokensDetails? = nil, textTokens: Int? = nil) {
					self.audioTokens = audioTokens
					self.cachedTokens = cachedTokens
					self.cachedTokensDetails = cachedTokensDetails
					self.textTokens = textTokens
				}
			}

			public struct OutputTokenDetails: Equatable, Hashable, Codable, Sendable {
				public let audioTokens: Int?
				public let textTokens: Int?

				public init(audioTokens: Int? = nil, textTokens: Int? = nil) {
					self.audioTokens = audioTokens
					self.textTokens = textTokens
				}
			}

			public let inputTokenDetails: InputTokenDetails?
			public let inputTokens: Int
			public let outputTokenDetails: OutputTokenDetails?
			public let outputTokens: Int
			public let totalTokens: Int

			public init(
				inputTokenDetails: InputTokenDetails? = nil,
				inputTokens: Int,
				outputTokenDetails: OutputTokenDetails? = nil,
				outputTokens: Int,
				totalTokens: Int
			) {
				self.inputTokenDetails = inputTokenDetails
				self.inputTokens = inputTokens
				self.outputTokenDetails = outputTokenDetails
				self.outputTokens = outputTokens
				self.totalTokens = totalTokens
			}
		}

		public struct DurationUsage: Equatable, Hashable, Codable, Sendable {
			public let seconds: Double

			public init(seconds: Double) {
				self.seconds = seconds
			}
		}

		case tokens(TokenUsage)
		case duration(DurationUsage)
	}

	public let conversationId: String?
	public let id: String
	public let metadata: [String: String]?
	public let object: String?
	public let output: [Item]
	public let status: Status
	public let statusDetails: JSONValue?
	public let usage: Usage?

	public init(
		conversationId: String? = nil,
		id: String,
		metadata: [String: String]? = nil,
		object: String? = nil,
		output: [Item],
		status: Status,
		statusDetails: JSONValue? = nil,
		usage: Usage? = nil
	) {
		self.conversationId = conversationId
		self.id = id
		self.metadata = metadata
		self.object = object
		self.output = output
		self.status = status
		self.statusDetails = statusDetails
		self.usage = usage
	}
}

extension Response.InputItem: Codable {
	private enum CodingKeys: String, CodingKey {
		case id
		case type
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(String.self, forKey: .type)

		switch type {
			case "message":
				self = .message(try Message(from: decoder))
			case "function_call":
				self = .functionCall(try FunctionCall(from: decoder))
			case "function_call_output":
				self = .functionCallOutput(try FunctionCallOutput(from: decoder))
			case "item_reference":
				self = .itemReference(id: try container.decode(String.self, forKey: .id))
			default:
				throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown response input item type: \(type)")
		}
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		switch self {
			case let .message(message):
				try container.encode("message", forKey: .type)
				try message.encode(to: encoder)
			case let .functionCall(functionCall):
				try container.encode("function_call", forKey: .type)
				try functionCall.encode(to: encoder)
			case let .functionCallOutput(functionCallOutput):
				try container.encode("function_call_output", forKey: .type)
				try functionCallOutput.encode(to: encoder)
			case let .itemReference(id):
				try container.encode("item_reference", forKey: .type)
				try container.encode(id, forKey: .id)
		}
	}
}

extension Response.InputItem.Message.Content: Codable {
	private enum CodingKeys: String, CodingKey {
		case audio
		case detail
		case id
		case imageUrl
		case text
		case transcript
		case type
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(String.self, forKey: .type)

		switch type {
			case "input_text":
				self = .inputText(try container.decode(String.self, forKey: .text))
			case "input_audio":
				self = .inputAudio(try Item.Audio(from: decoder))
			case "input_image":
				self = .inputImage(.init(
					imageUrl: try container.decode(String.self, forKey: .imageUrl),
					detail: try container.decodeIfPresent(Item.Message.InputImage.Detail.self, forKey: .detail)
				))
			case "text":
				self = .text(try container.decode(String.self, forKey: .text))
			case "item_reference":
				self = .itemReference(id: try container.decode(String.self, forKey: .id))
			default:
				throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown response input content type: \(type)")
		}
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		switch self {
			case let .inputText(text):
				try container.encode("input_text", forKey: .type)
				try container.encode(text, forKey: .text)
			case let .inputAudio(audio):
				try container.encode("input_audio", forKey: .type)
				try container.encode(audio.audio, forKey: .audio)
				try container.encodeIfPresent(audio.transcript, forKey: .transcript)
			case let .inputImage(image):
				try container.encode("input_image", forKey: .type)
				try container.encode(image.imageUrl, forKey: .imageUrl)
				try container.encodeIfPresent(image.detail, forKey: .detail)
			case let .text(text):
				try container.encode("text", forKey: .type)
				try container.encode(text, forKey: .text)
			case let .itemReference(id):
				try container.encode("item_reference", forKey: .type)
				try container.encode(id, forKey: .id)
		}
	}
}

extension Response.ContentPart: Codable {
	private enum CodingKeys: String, CodingKey {
		case audio
		case text
		case transcript
		case type
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(String.self, forKey: .type)

		switch type {
			case "output_text":
				self = .outputText(try container.decodeIfPresent(String.self, forKey: .text) ?? "")
			case "output_audio":
				self = .outputAudio(try Item.Audio(from: decoder))
			default:
				throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown response content part type: \(type)")
		}
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		switch self {
			case let .outputText(text):
				try container.encode("output_text", forKey: .type)
				try container.encode(text, forKey: .text)
			case let .outputAudio(audio):
				try container.encode("output_audio", forKey: .type)
				try container.encode(audio.audio, forKey: .audio)
				try container.encodeIfPresent(audio.transcript, forKey: .transcript)
		}
	}
}

extension Response.Usage: Codable {
	private enum CodingKeys: String, CodingKey {
		case type
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(String.self, forKey: .type)

		switch type {
			case "tokens":
				self = .tokens(try TokenUsage(from: decoder))
			case "duration":
				self = .duration(try DurationUsage(from: decoder))
			default:
				throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown usage type: \(type)")
		}
	}

	public func encode(to encoder: any Encoder) throws {
		switch self {
			case let .tokens(usage):
				var container = encoder.container(keyedBy: CodingKeys.self)
				try container.encode("tokens", forKey: .type)
				try usage.encode(to: encoder)
			case let .duration(usage):
				var container = encoder.container(keyedBy: CodingKeys.self)
				try container.encode("duration", forKey: .type)
				try usage.encode(to: encoder)
		}
	}
}
