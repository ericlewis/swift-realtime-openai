import Foundation

extension SessionConfiguration.Prompt.VariableValue: Codable {
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
					detail: try container.decodeIfPresent(SessionConfiguration.Prompt.VariableValue.InputFile.Detail.self, forKey: .detail),
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

extension SessionConfiguration.Tracing.MetadataValue: Codable {
	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()

		if container.decodeNil() {
			self = .null
			return
		}

		if let value = try? container.decode(Bool.self) {
			self = .bool(value)
			return
		}

		if let value = try? container.decode(Double.self) {
			self = .number(value)
			return
		}

		if let value = try? container.decode(String.self) {
			self = .string(value)
			return
		}

		if let value = try? container.decode([SessionConfiguration.Tracing.MetadataValue].self) {
			self = .array(value)
			return
		}

		if let value = try? container.decode([String: SessionConfiguration.Tracing.MetadataValue].self) {
			self = .object(value)
			return
		}

		throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported tracing metadata value")
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()

		switch self {
			case .null:
				try container.encodeNil()
			case let .bool(value):
				try container.encode(value)
			case let .number(value):
				try container.encode(value)
			case let .string(value):
				try container.encode(value)
			case let .array(value):
				try container.encode(value)
			case let .object(value):
				try container.encode(value)
		}
	}
}

extension SessionConfiguration.Voice: Codable {
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

extension SessionConfiguration: Codable {
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
