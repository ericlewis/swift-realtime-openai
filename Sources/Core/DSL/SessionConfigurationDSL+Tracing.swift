import Foundation

/// Configures tracing for the session DSL.
public struct Tracing: SessionComponentConvertible {
	private let value: SessionConfiguration.Tracing
	private let validationErrors: [SessionConfigurationBuilderError]

	public init(_ value: SessionConfiguration.Tracing = .auto) {
		self.value = value
		self.validationErrors = []
	}

	public init(@TracingBuilder _ content: () -> [TracingComponent]) {
		var draft = TracingDraft()
		let components = content()

		for component in components {
			component.apply(&draft)
		}

		self.value = .configuration(draft.makeConfiguration())
		self.validationErrors = components.flatMap(\.validationErrors)
	}

	public var sessionComponent: SessionComponent {
		SessionComponent({ draft in
			draft.tracing = value
		}, validationErrors: validationErrors)
	}
}

public struct TracingComponent {
	fileprivate let apply: (inout TracingDraft) -> Void
	fileprivate let validationErrors: [SessionConfigurationBuilderError]

	fileprivate init(_ apply: @escaping (inout TracingDraft) -> Void, validationErrors: [SessionConfigurationBuilderError] = []) {
		self.apply = apply
		self.validationErrors = validationErrors
	}
}

public protocol TracingComponentConvertible {
	var tracingComponent: TracingComponent { get }
}

@resultBuilder
public enum TracingBuilder {
	public static func buildExpression<T: TracingComponentConvertible>(_ expression: T) -> [TracingComponent] {
		[expression.tracingComponent]
	}

	public static func buildBlock(_ components: [TracingComponent]...) -> [TracingComponent] {
		components.flatMap(\.self)
	}
}

/// Sets the workflow name attached to emitted traces.
public struct Workflow: TracingComponentConvertible {
	private let value: String

	public init(_ value: String) {
		self.value = value
	}

	public var tracingComponent: TracingComponent {
		TracingComponent { draft in
			draft.workflow = value
		}
	}
}

/// Sets the trace grouping identifier.
public struct Group: TracingComponentConvertible {
	private let value: String

	public init(_ value: String) {
		self.value = value
	}

	public var tracingComponent: TracingComponent {
		TracingComponent { draft in
			draft.group = value
		}
	}
}

/// Attaches arbitrary metadata to emitted traces.
public struct Metadata: TracingComponentConvertible {
	private let value: [String: SessionConfiguration.Tracing.MetadataValue]

	public init(_ value: [String: SessionConfiguration.Tracing.MetadataValue]) {
		self.value = value
	}

	public init(_ value: [String: String]) {
		self.value = value.mapValues(SessionConfiguration.Tracing.MetadataValue.string)
	}

	public var tracingComponent: TracingComponent {
		TracingComponent { draft in
			draft.metadata = value
		}
	}
}

private struct TracingDraft {
	var workflow: String?
	var group: String?
	var metadata: [String: SessionConfiguration.Tracing.MetadataValue]?

	func makeConfiguration() -> SessionConfiguration.Tracing.Configuration {
		.init(groupId: group, metadata: metadata, workflowName: workflow)
	}
}
