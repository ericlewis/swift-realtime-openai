import Foundation

/// Describes whether a remote MCP tool requires approval.
public struct Approval: Equatable, Hashable, Sendable {
	fileprivate let value: ToolDefinition.MCP.RequireApproval

	private init(_ value: ToolDefinition.MCP.RequireApproval) {
		self.value = value
	}

	public static let required = Self(.setting(.always))
	public static let notRequired = Self(.setting(.never))
}

public protocol MCPConfigurableTool: ToolDefinitionConvertible {
	var mcpDefinition: ToolDefinition.MCP { get }
	init(mcpDefinition: ToolDefinition.MCP)
}

public extension MCPConfigurableTool {
	var toolDefinition: ToolDefinition { .mcp(mcpDefinition) }

	func deferred(_ isDeferred: Bool = true) -> Self {
		var definition = mcpDefinition
		definition.deferLoading = isDeferred
		return .init(mcpDefinition: definition)
	}

	func approval(_ approval: Approval) -> Self {
		var definition = mcpDefinition
		definition.requireApproval = approval.value
		return .init(mcpDefinition: definition)
	}

	func readOnly(_ enabled: Bool = true) -> Self {
		guard enabled else { return self }

		var definition = mcpDefinition

		switch definition.allowedTools {
			case .none:
				definition.allowedTools = .filter(.init(readOnly: true))
			case let .some(.names(names)):
				definition.allowedTools = .filter(.init(readOnly: true, toolNames: names))
			case let .some(.filter(filter)):
				definition.allowedTools = .filter(.init(readOnly: true, toolNames: filter.toolNames))
		}

		return .init(mcpDefinition: definition)
	}
}

/// Declares a remote MCP server or connector-backed tool source in the session DSL.
public struct MCP: MCPConfigurableTool {
	public let mcpDefinition: ToolDefinition.MCP
	private let validationErrors: [SessionConfigurationBuilderError]

	public init(_ serverLabel: String, server: String, @MCPBuilder _ content: () -> [MCPComponent] = { [] }) {
		guard
			let parsedURL = URL(string: server),
			parsedURL.scheme != nil,
			parsedURL.host != nil
		else {
			self.init(
				mcpDefinition: buildMCPDefinition(
					serverLabel: serverLabel,
					content: content
				),
				validationErrors: [.invalidMCPServerURL(server)]
			)
			return
		}

		self.init(serverLabel, server: parsedURL, content)
	}

	public init(_ serverLabel: String, server: URL, @MCPBuilder _ content: () -> [MCPComponent] = { [] }) {
		self.init(
			mcpDefinition: buildMCPDefinition(
				serverLabel: serverLabel,
				serverUrl: server,
				content: content
			),
			validationErrors: []
		)
	}

	public init(mcpDefinition: ToolDefinition.MCP) {
		self.init(mcpDefinition: mcpDefinition, validationErrors: [])
	}

	private init(mcpDefinition: ToolDefinition.MCP, validationErrors: [SessionConfigurationBuilderError]) {
		self.mcpDefinition = mcpDefinition
		self.validationErrors = validationErrors
	}

	public var toolDefinitionValidationErrors: [SessionConfigurationBuilderError] {
		validationErrors
	}
}

public struct Description: MCPComponentConvertible {
	private let value: String

	public init(@PromptBuilder _ content: () -> [String]) {
		self.value = content().joined(separator: "\n")
	}

	public var mcpComponent: MCPComponent {
		MCPComponent { definition in
			definition.serverDescription = value
		}
	}
}

public struct AuthorizationToken: MCPComponentConvertible {
	private let value: String

	public init(_ value: String) {
		self.value = value
	}

	public var mcpComponent: MCPComponent {
		MCPComponent { definition in
			definition.authorization = value
		}
	}
}

public struct Headers: MCPComponentConvertible {
	private let value: [String: String]

	public init(_ value: [String: String]) {
		self.value = value
	}

	public var mcpComponent: MCPComponent {
		MCPComponent { definition in
			definition.headers = value
		}
	}
}

public struct MCPComponent {
	let apply: (inout ToolDefinition.MCP) -> Void
	let validationErrors: [SessionConfigurationBuilderError]

	init(_ apply: @escaping (inout ToolDefinition.MCP) -> Void, validationErrors: [SessionConfigurationBuilderError] = []) {
		self.apply = apply
		self.validationErrors = validationErrors
	}
}

public protocol MCPComponentConvertible {
	var mcpComponent: MCPComponent { get }
}

@resultBuilder
public enum MCPBuilder {
	public static func buildExpression<T: MCPComponentConvertible>(_ expression: T) -> [MCPComponent] {
		[expression.mcpComponent]
	}

	public static func buildBlock(_ components: [MCPComponent]...) -> [MCPComponent] {
		components.flatMap(\.self)
	}
}

public struct DropboxConnector: MCPConfigurableTool {
	public let mcpDefinition: ToolDefinition.MCP

	public init(label: String = "dropbox_connector", @MCPBuilder _ content: () -> [MCPComponent] = { [] }) {
		self.mcpDefinition = buildMCPDefinition(
			serverLabel: label,
			connectorId: .dropbox,
			content: content
		)
	}

	public init(mcpDefinition: ToolDefinition.MCP) {
		self.mcpDefinition = mcpDefinition
	}
}

public struct GmailConnector: MCPConfigurableTool {
	public let mcpDefinition: ToolDefinition.MCP

	public init(label: String = "gmail_connector", @MCPBuilder _ content: () -> [MCPComponent] = { [] }) {
		self.mcpDefinition = buildMCPDefinition(
			serverLabel: label,
			connectorId: .gmail,
			content: content
		)
	}

	public init(mcpDefinition: ToolDefinition.MCP) {
		self.mcpDefinition = mcpDefinition
	}
}

public struct GoogleCalendarConnector: MCPConfigurableTool {
	public let mcpDefinition: ToolDefinition.MCP

	public init(label: String = "google_calendar_connector", @MCPBuilder _ content: () -> [MCPComponent] = { [] }) {
		self.mcpDefinition = buildMCPDefinition(
			serverLabel: label,
			connectorId: .googleCalendar,
			content: content
		)
	}

	public init(mcpDefinition: ToolDefinition.MCP) {
		self.mcpDefinition = mcpDefinition
	}
}

public struct GoogleDriveConnector: MCPConfigurableTool {
	public let mcpDefinition: ToolDefinition.MCP

	public init(label: String = "google_drive_connector", @MCPBuilder _ content: () -> [MCPComponent] = { [] }) {
		self.mcpDefinition = buildMCPDefinition(
			serverLabel: label,
			connectorId: .googleDrive,
			content: content
		)
	}

	public init(mcpDefinition: ToolDefinition.MCP) {
		self.mcpDefinition = mcpDefinition
	}
}

public struct MicrosoftTeamsConnector: MCPConfigurableTool {
	public let mcpDefinition: ToolDefinition.MCP

	public init(label: String = "microsoft_teams_connector", @MCPBuilder _ content: () -> [MCPComponent] = { [] }) {
		self.mcpDefinition = buildMCPDefinition(
			serverLabel: label,
			connectorId: .microsoftTeams,
			content: content
		)
	}

	public init(mcpDefinition: ToolDefinition.MCP) {
		self.mcpDefinition = mcpDefinition
	}
}

public struct OutlookCalendarConnector: MCPConfigurableTool {
	public let mcpDefinition: ToolDefinition.MCP

	public init(label: String = "outlook_calendar_connector", @MCPBuilder _ content: () -> [MCPComponent] = { [] }) {
		self.mcpDefinition = buildMCPDefinition(
			serverLabel: label,
			connectorId: .outlookCalendar,
			content: content
		)
	}

	public init(mcpDefinition: ToolDefinition.MCP) {
		self.mcpDefinition = mcpDefinition
	}
}

public struct OutlookEmailConnector: MCPConfigurableTool {
	public let mcpDefinition: ToolDefinition.MCP

	public init(label: String = "outlook_email_connector", @MCPBuilder _ content: () -> [MCPComponent] = { [] }) {
		self.mcpDefinition = buildMCPDefinition(
			serverLabel: label,
			connectorId: .outlookEmail,
			content: content
		)
	}

	public init(mcpDefinition: ToolDefinition.MCP) {
		self.mcpDefinition = mcpDefinition
	}
}

public struct SharePointConnector: MCPConfigurableTool {
	public let mcpDefinition: ToolDefinition.MCP

	public init(label: String = "sharepoint_connector", @MCPBuilder _ content: () -> [MCPComponent] = { [] }) {
		self.mcpDefinition = buildMCPDefinition(
			serverLabel: label,
			connectorId: .sharepoint,
			content: content
		)
	}

	public init(mcpDefinition: ToolDefinition.MCP) {
		self.mcpDefinition = mcpDefinition
	}
}

private func buildMCPDefinition(
	serverLabel: String,
	serverUrl: URL? = nil,
	connectorId: ToolDefinition.MCP.Connector? = nil,
	@MCPBuilder content: () -> [MCPComponent] = { [] }
) -> ToolDefinition.MCP {
	var definition = ToolDefinition.MCP(
		serverLabel: serverLabel,
		serverUrl: serverUrl,
		connectorId: connectorId
	)

	for component in content() {
		component.apply(&definition)
	}

	return definition
}
