import Foundation

// MARK: - Tool Protocol

public protocol Tool<Arguments>: Sendable {
	associatedtype Arguments: Decodable & Sendable
	associatedtype Output: Encodable & Sendable

	var name: String { get }
	var description: String { get }
	var parametersSchema: JSONSchema { get }

	func call(arguments: Arguments) async throws -> Output
}

public extension Tool {
	var definition: ToolDefinition {
		.function(.init(name: name, description: description, parameters: parametersSchema))
	}
}

public extension Tool where Arguments: Generable {
	var parametersSchema: JSONSchema {
		Arguments.generationSchema
	}
}

// MARK: - ToolRegistry

public struct ToolRegistry: Sendable {
	public enum Error: Swift.Error {
		case unknownTool(String)
		case invalidArguments(String, underlying: Swift.Error)
	}

	private let handlers: [String: @Sendable (String) async throws -> String]

	public let definitions: [ToolDefinition]

	public init(_ tools: [any Tool]) {
		var handlers = [String: @Sendable (String) async throws -> String]()
		var definitions = [ToolDefinition]()

		for tool in tools {
			definitions.append(tool.definition)
			Self.register(tool, into: &handlers)
		}

		self.handlers = handlers
		self.definitions = definitions
	}

	public func handle(name: String, callId: String, arguments: String) async throws -> Item.FunctionCallOutput {
		guard let handler = handlers[name] else {
			throw Error.unknownTool(name)
		}

		let output = try await handler(arguments)
		return Item.FunctionCallOutput(id: UUID().uuidString, callId: callId, output: output)
	}

	private static func register<T: Tool>(_ tool: T, into handlers: inout [String: @Sendable (String) async throws -> String]) {
		handlers[tool.name] = { arguments in
			let data = Data(arguments.utf8)
			let decoded: T.Arguments
			do {
				decoded = try JSONDecoder().decode(T.Arguments.self, from: data)
			} catch {
				throw Error.invalidArguments(tool.name, underlying: error)
			}
			return try encodeToolOutput(try await tool.call(arguments: decoded))
		}
	}

	private static func encodeToolOutput<T: Encodable>(_ output: T) throws -> String {
		if let string = output as? String {
			return string
		}

		let data = try JSONEncoder().encode(output)
		guard let string = String(data: data, encoding: .utf8) else {
			throw EncodingError.invalidValue(output, .init(codingPath: [], debugDescription: "Unable to encode tool output as UTF-8 string"))
		}

		return string
	}
}

// MARK: - ToolChoice

public enum ToolChoice: Equatable, Hashable, Sendable {
	case none
	case auto
	case required
	case function(name: String)
	case mcp(server: String, tool: String?)
}

// MARK: - ToolDefinition

public enum ToolDefinition: Equatable, Hashable, Sendable {
	public struct Function: Equatable, Hashable, Codable, Sendable {
		public var name: String
		public var description: String?
		public var parameters: JSONSchema

		public init(name: String, description: String? = nil, parameters: JSONSchema) {
			self.name = name
			self.description = description
			self.parameters = parameters
		}
	}

	public struct MCP: Equatable, Hashable, Codable, Sendable {
		public enum Connector: String, Equatable, Hashable, Codable, Sendable {
			case dropbox = "connector_dropbox"
			case gmail = "connector_gmail"
			case googleCalendar = "connector_googlecalendar"
			case googleDrive = "connector_googledrive"
			case microsoftTeams = "connector_microsoftteams"
			case outlookCalendar = "connector_outlookcalendar"
			case outlookEmail = "connector_outlookemail"
			case sharepoint = "connector_sharepoint"
		}

		public struct Filter: Equatable, Hashable, Codable, Sendable {
			public var readOnly: Bool?
			public var toolNames: [String]?

			public init(readOnly: Bool? = nil, toolNames: [String]? = nil) {
				self.readOnly = readOnly
				self.toolNames = toolNames
			}
		}

		public enum AllowedTools: Equatable, Hashable, Sendable {
			case names([String])
			case filter(Filter)
		}

		public enum RequireApproval: Equatable, Hashable, Sendable {
			public enum Setting: String, CaseIterable, Equatable, Hashable, Codable, Sendable {
				case always
				case never
			}

			public struct Rules: Equatable, Hashable, Codable, Sendable {
				public var always: Filter?
				public var never: Filter?

				public init(always: Filter? = nil, never: Filter? = nil) {
					self.always = always
					self.never = never
				}
			}

			case setting(Setting)
			case rules(Rules)
		}

		private enum CodingKeys: String, CodingKey {
			case serverLabel
			case serverUrl
			case connectorId
			case authorization
			case allowedTools
			case deferLoading
			case headers
			case requireApproval
			case serverDescription
		}

		public var serverLabel: String
		public var serverUrl: URL?
		public var connectorId: Connector?
		public var authorization: String?
		public var allowedTools: AllowedTools?
		public var deferLoading: Bool?
		public var headers: [String: String]?
		public var requireApproval: RequireApproval?
		public var serverDescription: String?

		public init(
			serverLabel: String,
			serverUrl: URL? = nil,
			connectorId: Connector? = nil,
			authorization: String? = nil,
			allowedTools: AllowedTools? = nil,
			deferLoading: Bool? = nil,
			headers: [String: String]? = nil,
			requireApproval: RequireApproval? = nil,
			serverDescription: String? = nil
		) {
			self.serverLabel = serverLabel
			self.serverUrl = serverUrl
			self.connectorId = connectorId
			self.authorization = authorization
			self.allowedTools = allowedTools
			self.deferLoading = deferLoading
			self.headers = headers
			self.requireApproval = requireApproval
			self.serverDescription = serverDescription
		}
	}

	case function(Function)
	case mcp(MCP)
}

extension ToolDefinition: Codable {
	private enum CodingKeys: String, CodingKey {
		case type
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(String.self, forKey: .type)

		switch type {
			case "function":
				self = .function(try Function(from: decoder))
			case "mcp":
				self = .mcp(try MCP(from: decoder))
			default:
				throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown tool type: \(type)")
		}
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		switch self {
			case let .function(function):
				try container.encode("function", forKey: .type)
				try function.encode(to: encoder)
			case let .mcp(mcp):
				try container.encode("mcp", forKey: .type)
				try mcp.encode(to: encoder)
		}
	}
}

extension ToolChoice: Codable {
	private enum CodingKeys: String, CodingKey {
		case type, name, serverLabel
	}

	public func encode(to encoder: any Encoder) throws {
		switch self {
			case .none:
				try "none".encode(to: encoder)
			case .auto:
				try "auto".encode(to: encoder)
			case .required:
				try "required".encode(to: encoder)
			case let .function(name):
				var container = encoder.container(keyedBy: CodingKeys.self)
				try container.encode("function", forKey: .type)
				try container.encode(name, forKey: .name)
			case let .mcp(server, tool):
				var container = encoder.container(keyedBy: CodingKeys.self)
				try container.encode("mcp", forKey: .type)
				try container.encode(server, forKey: .serverLabel)
				try container.encodeIfPresent(tool, forKey: .name)
		}
	}

	public init(from decoder: any Decoder) throws {
		if let string = try? String(from: decoder) {
			switch string {
				case "none": self = .none
				case "auto": self = .auto
				case "required": self = .required
				default:
					throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid tool choice: \(string)"))
			}
			return
		}

		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(String.self, forKey: .type)

		switch type {
			case "function":
				self = .function(name: try container.decode(String.self, forKey: .name))
			case "mcp":
				self = .mcp(
					server: try container.decode(String.self, forKey: .serverLabel),
					tool: try container.decodeIfPresent(String.self, forKey: .name)
				)
			default:
				throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid tool choice: \(type)")
		}
	}
}

extension ToolDefinition.MCP.AllowedTools: Codable {
	public func encode(to encoder: any Encoder) throws {
		switch self {
			case let .names(names):
				try names.encode(to: encoder)
			case let .filter(filter):
				try filter.encode(to: encoder)
		}
	}

	public init(from decoder: any Decoder) throws {
		if let names = try? [String](from: decoder) {
			self = .names(names)
			return
		}

		self = .filter(try ToolDefinition.MCP.Filter(from: decoder))
	}
}

extension ToolDefinition.MCP.RequireApproval: Codable {
	public func encode(to encoder: any Encoder) throws {
		switch self {
			case let .setting(setting):
				try setting.encode(to: encoder)
			case let .rules(rules):
				try rules.encode(to: encoder)
		}
	}

	public init(from decoder: any Decoder) throws {
		if let setting = try? Setting(from: decoder) {
			self = .setting(setting)
			return
		}

		self = .rules(try Rules(from: decoder))
	}
}
