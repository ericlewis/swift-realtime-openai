import Foundation

/// Selects how MCP tool policy allow-lists are interpreted.
public struct ToolPolicyMode: Equatable, Hashable, Sendable {
	fileprivate enum Storage: Equatable, Hashable, Sendable {
		case explicitAllowList
		case allowAll
		case allow(prefix: String)
	}

	fileprivate let storage: Storage

	fileprivate init(_ storage: Storage) {
		self.storage = storage
	}

	public static let allowAll = Self(.allowAll)

	public static func allow(prefix: String) -> Self {
		.init(.allow(prefix: prefix))
	}
}

/// Declares policy for an individual MCP tool name.
public struct Tool {
	fileprivate let name: String
	fileprivate var approval: Approval?
	fileprivate var readOnly: Bool

	public init(_ name: String) {
		self.name = name
		self.approval = nil
		self.readOnly = false
	}

	public func approval(_ approval: Approval) -> Self {
		var copy = self
		copy.approval = approval
		return copy
	}

	public func readOnly(_ enabled: Bool = true) -> Self {
		var copy = self
		copy.readOnly = enabled
		return copy
	}
}

/// Configures MCP tool allow-lists and approval rules.
public struct ToolPolicies: MCPComponentConvertible {
	private let mode: ToolPolicyMode
	private let tools: [Tool]

	public init(@ToolPolicyBuilder _ content: () -> [Tool]) {
		self.mode = .init(.explicitAllowList)
		self.tools = content()
	}

	public init(_ mode: ToolPolicyMode, @ToolPolicyBuilder _ content: () -> [Tool] = { [] }) {
		self.mode = mode
		self.tools = content()
	}

	public var mcpComponent: MCPComponent {
		MCPComponent { definition in
			let candidateNames: [String]

			switch mode.storage {
				case .explicitAllowList:
					candidateNames = tools.map(\.name)
				case .allowAll:
					candidateNames = []
				case let .allow(prefix):
					candidateNames = tools.map(\.name).filter { $0.hasPrefix(prefix) }
			}

			if case .allowAll = mode.storage {
				definition.allowedTools = nil
			} else if !candidateNames.isEmpty {
				let readOnlyNames = Set(tools.filter(\.readOnly).map(\.name))
				if !readOnlyNames.isEmpty, readOnlyNames.count == candidateNames.count {
					definition.allowedTools = .filter(.init(readOnly: true, toolNames: candidateNames))
				} else {
					definition.allowedTools = .names(candidateNames)
				}
			}

			let alwaysNames = tools.compactMap { tool in
				tool.approval == .required ? tool.name : nil
			}

			let neverNames = tools.compactMap { tool in
				if tool.approval == .notRequired || (tool.readOnly && tool.approval == nil) {
					return tool.name
				}

				return nil
			}

			if !alwaysNames.isEmpty || !neverNames.isEmpty {
				definition.requireApproval = .rules(.init(
					always: alwaysNames.isEmpty ? nil : .init(toolNames: alwaysNames),
					never: neverNames.isEmpty ? nil : .init(toolNames: neverNames)
				))
			}
		}
	}
}

@resultBuilder
public enum ToolPolicyBuilder {
	public static func buildExpression(_ expression: Tool) -> [Tool] {
		[expression]
	}

	public static func buildBlock(_ components: [Tool]...) -> [Tool] {
		components.flatMap(\.self)
	}
}
