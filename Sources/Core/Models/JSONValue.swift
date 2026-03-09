import Foundation

public indirect enum JSONValue: Equatable, Hashable, Sendable {
	case null
	case bool(Bool)
	case number(Double)
	case string(String)
	case array([JSONValue])
	case object([String: JSONValue])
}

extension JSONValue: Codable {
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

		if let value = try? container.decode([JSONValue].self) {
			self = .array(value)
			return
		}

		if let value = try? container.decode([String: JSONValue].self) {
			self = .object(value)
			return
		}

		throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
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
