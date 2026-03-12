import Foundation

public extension SessionConfiguration {
	/// The modalities a realtime session may produce.
	enum OutputModality: String, Equatable, Hashable, Codable, Sendable {
		case text, audio
	}

	/// Additional optional fields that can be requested in server output payloads.
	enum Include: String, Equatable, Hashable, Codable, Sendable {
		case inputAudioTranscriptionLogprobs = "item.input_audio_transcription.logprobs"
	}

	/// Controls the output token budget for a single response.
	enum MaxOutputTokens: Equatable, Hashable, Codable, Sendable {
		case inf
		case limited(Int)

		public static var max: Self { .inf }

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

	/// References a reusable prompt template and its bound variables.
	struct Prompt: Equatable, Hashable, Codable, Sendable {
		/// Values that can be substituted into a hosted prompt template.
		public enum VariableValue: Equatable, Hashable, Sendable {
			/// An image value supplied to a prompt variable.
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

			/// A file value supplied to a prompt variable.
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

	/// Selects a built-in or custom output voice for audio responses.
	enum Voice: Equatable, Hashable, Sendable {
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

	/// Describes an input or output audio wire format.
	struct AudioFormat: Equatable, Hashable, Codable, Sendable {
		public var rate: Int?
		public var type: String

		public init(type: String, rate: Int? = nil) {
			self.rate = rate
			self.type = type
		}

		public static let pcm24kMono = Self(type: "audio/pcm", rate: 24000)
		public static let pcmu = Self(type: "audio/pcmu")
		public static let pcma = Self(type: "audio/pcma")
		public static let pcm = Self.pcm24kMono
	}

	/// Controls trace emission to the OpenAI traces dashboard.
	enum Tracing: Equatable, Hashable, Codable, Sendable {
		public indirect enum MetadataValue: Equatable, Hashable, Sendable {
			case null
			case bool(Bool)
			case number(Double)
			case string(String)
			case array([MetadataValue])
			case object([String: MetadataValue])
		}

		public struct Configuration: Equatable, Hashable, Codable, Sendable {
			public var groupId: String?
			public var metadata: [String: MetadataValue]?
			public var workflowName: String?

			public init(groupId: String? = nil, metadata: [String: MetadataValue]? = nil, workflowName: String? = nil) {
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

	/// Controls how conversation history is truncated when the model context fills up.
	enum Truncation: Equatable, Hashable, Codable, Sendable {
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

	/// A lightweight representation of the backing conversation resource.
	struct ConversationResource: Equatable, Hashable, Codable, Sendable {
		public var id: String?
		public var object: String?

		public init(id: String? = nil, object: String? = nil) {
			self.id = id
			self.object = object
		}
	}
}
