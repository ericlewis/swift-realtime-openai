import Core
import Foundation
import OSLog

/// Describes failures emitted by the high-level ``Session`` runtime.
///
/// These cases represent connection lifecycle failures, runtime coordination failures,
/// or configuration mismatches in the session wrapper itself.
public enum SessionError: Error, Equatable {
	/// The runtime tried to update configuration before the session had received any session configuration.
	case configurationNotFound
	/// WebRTC rejected the supplied client secret during connection setup.
	case invalidClientSecret
	/// The session attempted to use a transport that has not been connected yet.
	case connectionNotEstablished
	/// `waitForConnection` timed out before the session reached a connected state.
	case connectionTimedOut
	/// The session disconnected before a pending connection attempt completed.
	case disconnectedWhileWaitingForConnection
	/// The runtime could not construct the requested transport.
	case connectorInitializationFailed
	/// A server event reached the runtime, but the runtime failed while processing it.
	case eventHandlingFailed
	/// The underlying server event stream failed.
	case eventStreamFailed
	/// A locally registered tool failed while handling a model tool call.
	case toolCallFailed(name: String)
	/// A realtime-only API was used while the session currently holds transcription configuration.
	case realtimeConfigurationRequired
	/// A transcription-only API was used while the session currently holds realtime configuration.
	case transcriptionConfigurationRequired
	/// A WebSocket-only connection API was used on a non-WebSocket session.
	case webSocketTransportRequired
}

/// A high-level runtime for realtime and transcription sessions.
///
/// ``Session`` owns transport lifecycle, conversation state, observation streams, and optional
/// local tool dispatch. Most applications should treat it as the main entry point after creating
/// a client secret with ``RealtimeAPI/createClientSecret(apiKey:configuration:expiresAfter:using:)``.
@MainActor @Observable
public final class Session {
	/// A transform applied to the full session configuration before the runtime sends its first update.
	public typealias ConfigurationTransform = (SessionConfiguration) -> SessionConfiguration

	/// The transport used by the session runtime.
	public enum ConnectionTransport: String, CaseIterable, Equatable, Hashable, Sendable {
		case webRTC
		case webSocket
	}

	/// A lightweight snapshot of runtime state for observation-driven consumers.
	public struct Snapshot: Sendable, Equatable {
		/// The current transport connection state.
		public var status: RealtimeAPI.Status
		/// Whether the server is currently detecting user speech.
		public var isUserSpeaking: Bool
		/// Whether the model is currently producing output audio.
		public var isModelSpeaking: Bool
		/// The backing conversation identifier when available.
		public var conversationID: String?
		/// A monotonically increasing revision that changes whenever conversation content changes.
		public var conversationRevision: UInt64

		public init(
			status: RealtimeAPI.Status,
			isUserSpeaking: Bool,
			isModelSpeaking: Bool,
			conversationID: String?,
			conversationRevision: UInt64
		) {
			self.status = status
			self.isUserSpeaking = isUserSpeaking
			self.isModelSpeaking = isModelSpeaking
			self.conversationID = conversationID
			self.conversationRevision = conversationRevision
		}
	}

	struct EntryRecord: Sendable {
		let localId: String
		var item: Item
	}

	struct Transport: Sendable {
		let events: AsyncThrowingStream<ServerEvent, Error>
		let statusUpdates: AsyncStream<RealtimeAPI.Status>
		let status: @MainActor @Sendable () -> RealtimeAPI.Status
		let connect: @Sendable (URLRequest) async throws -> Void
		let send: @Sendable (ClientEvent) async throws -> Void
		let disconnect: @Sendable () -> Void
		let setMuted: @Sendable (Bool) -> Void
	}

	static let logger = Logger(subsystem: "RealtimeAPI", category: "Session")

	var transport: Transport
	let transportFactory: (() -> (Transport, [SessionError]))?
	let connectionTransport: ConnectionTransport
	var task: Task<Void, Never>?
	var statusTask: Task<Void, Never>?
	let toolRegistry: ToolRegistry?
	let configurationTransform: ConfigurationTransform?
	let errorStream: AsyncStream<ServerError>.Continuation
	let failureStream: AsyncStream<SessionError>.Continuation
	var serverEventStream: AsyncThrowingStream<ServerEvent, Error>.Continuation!
	let updateStream: AsyncStream<Snapshot>.Continuation
	var lastPublishedSnapshot: Snapshot?
	var statusObservers: [UUID: AsyncStream<RealtimeAPI.Status>.Continuation] = [:]
	var conversationRevision: UInt64 = 0
	var entryIndexesByItemID: [String: Int] = [:]
	var entryIndexesByLocalID: [String: Int] = [:]
	var cachedEntries: [Item]?
	var cachedMessages: [Item.Message]?

	/// Whether to print debug information to the console.
	public var debug: Bool

	/// Whether to mute the user's microphone.
	public var muted: Bool = false {
		didSet {
			transport.setMuted(muted)
		}
	}

	/// The unique ID of the backing conversation.
	public private(set) var conversationID: String?

	/// A stream of errors that occur during the session.
	public let errors: AsyncStream<ServerError>

	/// A stream of runtime failures that occur within the high-level session wrapper.
	public let failures: AsyncStream<SessionError>

	/// A read-only stream of raw server events for advanced observation and debugging.
	public let serverEvents: AsyncThrowingStream<ServerEvent, Error>

	/// A stream of state snapshots for consumers that prefer explicit async updates over Observation.
	public let updates: AsyncStream<Snapshot>

	/// The current session configuration for this session.
	public private(set) var configuration: SessionConfiguration?

	/// The current realtime configuration when the session is running in realtime mode.
	public var realtimeConfiguration: SessionConfiguration.Realtime? {
		guard case let .realtime(configuration) = configuration else { return nil }
		return configuration
	}

	/// The current transcription configuration when the session is running in transcription mode.
	public var transcriptionConfiguration: SessionConfiguration.Transcription? {
		guard case let .transcription(configuration) = configuration else { return nil }
		return configuration
	}

	/// A list of items in the session conversation.
	var entryRecords: [EntryRecord] = []

	public var entries: [Item] {
		if let cachedEntries {
			return cachedEntries
		}

		let entries = entryRecords.map(\.item)
		cachedEntries = entries
		return entries
	}

	public private(set) var status: RealtimeAPI.Status

	/// Whether the user is currently speaking.
	/// This only works when using the server's voice detection.
	public private(set) var isUserSpeaking: Bool = false

	/// Whether the model is currently speaking.
	public private(set) var isModelSpeaking: Bool = false

	/// A list of messages in the session conversation.
	/// Note that this doesn't include function call events. To get a complete list, use `entries`.
	public var messages: [Item.Message] {
		if let cachedMessages {
			return cachedMessages
		}

		let messages: [Item.Message] = entryRecords.compactMap {
			guard case let .message(message) = $0.item else { return nil }
			return message
		}
		cachedMessages = messages
		return messages
	}

	public convenience init(
		using connectionTransport: ConnectionTransport = .webRTC,
		debug: Bool = false,
		configuring configurationTransform: ConfigurationTransform? = nil
	) {
		let transportFactory = { Self.makeDefaultTransport(using: connectionTransport) }
		let (transport, pendingFailures) = transportFactory()
		self.init(
			transport: transport,
			transportFactory: transportFactory,
			connectionTransport: connectionTransport,
			debug: debug,
			configuring: configurationTransform,
			pendingFailures: pendingFailures
		)
	}

	/// Creates a new live session with the given tools and optional configuration callback.
	///
	/// Tools registered here are automatically dispatched when the model invokes them.
	/// The tool definitions are injected into the session configuration on connect.
	///
	/// - Parameter tools: An array of ``FunctionTool`` instances to register.
	/// - Parameter debug: Whether to print debug information to the console.
	/// - Parameter configurationTransform: An optional transform to configure the session.
	public convenience init(
		tools: [any FunctionTool],
		using connectionTransport: ConnectionTransport = .webRTC,
		debug: Bool = false,
		configuring configurationTransform: ConfigurationTransform? = nil
	) throws {
		let transportFactory = { Self.makeDefaultTransport(using: connectionTransport) }
		let (transport, pendingFailures) = transportFactory()
		try self.init(
			transport: transport,
			transportFactory: transportFactory,
			connectionTransport: connectionTransport,
			toolRegistry: ToolRegistry(tools),
			debug: debug,
			configuring: configurationTransform,
			pendingFailures: pendingFailures
		)
	}

	init(
		transport: Transport,
		transportFactory: (() -> (Transport, [SessionError]))? = nil,
		connectionTransport: ConnectionTransport = .webRTC,
		toolRegistry: ToolRegistry? = nil,
		debug: Bool = false,
		configuring configurationTransform: ConfigurationTransform? = nil,
		pendingFailures: [SessionError] = []
	) {
		self.transport = transport
		self.transportFactory = transportFactory
		self.connectionTransport = connectionTransport
		self.debug = debug
		self.toolRegistry = toolRegistry
		self.configurationTransform = configurationTransform
		self.status = transport.status()
		(errors, errorStream) = AsyncStream.makeStream(of: ServerError.self)
		(failures, failureStream) = AsyncStream.makeStream(of: SessionError.self)
		var serverEventContinuation: AsyncThrowingStream<ServerEvent, Error>.Continuation!
		serverEvents = AsyncThrowingStream(bufferingPolicy: .bufferingNewest(64)) { continuation in
			serverEventContinuation = continuation
		}
		serverEventStream = serverEventContinuation
		(updates, updateStream) = AsyncStream.makeStream(of: Snapshot.self)
		startRuntimeTasks(using: transport)
		for failure in pendingFailures {
			failureStream.yield(failure)
		}
		publishSnapshotIfNeeded()
	}

	deinit {
		MainActor.assumeIsolated {
			transport.disconnect()
			errorStream.finish()
			failureStream.finish()
			serverEventStream.finish()
			updateStream.finish()
		}
	}

	public func disconnect() {
		transport.disconnect()
		task?.cancel()
		statusTask?.cancel()
		task = nil
		statusTask = nil
		storeStatus(.disconnected)
		storeIsUserSpeaking(false)
		storeIsModelSpeaking(false)
		for observer in statusObservers.values {
			observer.yield(.disconnected)
		}
		publishSnapshotIfNeeded()
		for observer in statusObservers.values {
			observer.finish()
		}
		statusObservers.removeAll()
	}

	/// Send a text message and wait for a response.
	///
	/// Use this helper for the common “append a message and ask the model to respond” flow.
	/// Optionally provide a ``ResponseDTO/Config`` to customize response generation.
	public func send(from role: Item.Message.Role, text: String, response: ResponseDTO.Config? = nil) async throws {
		let content: Item.Message.Content = switch role {
			case .assistant: .outputText(text)
			case .user, .system: .inputText(text)
		}

		let item = Item.message(.init(id: String(randomLength: 32), role: role, content: [content]))
		try await send(event: .createConversationItem(item))
		try await send(event: .createResponse(using: response))
	}

	/// Send the response of a function call.
	public func send(result output: Item.FunctionCallOutput) async throws {
		try await send(event: .createConversationItem(.functionCallOutput(output)))
	}

	func receive(serverEvent event: ServerEvent) async throws {
		try await handleEvent(event)
	}

	func storeConversationID(_ value: String?) {
		conversationID = value
	}

	func storeResponseConversationIDIfNeeded(_ value: String?) {
		guard conversationID == nil else { return }
		conversationID = value
	}

	func storeConfiguration(_ value: SessionConfiguration) {
		configuration = value
	}

	func storeStatus(_ value: RealtimeAPI.Status) {
		status = value
	}

	func storeIsUserSpeaking(_ value: Bool) {
		isUserSpeaking = value
	}

	func storeIsModelSpeaking(_ value: Bool) {
		isModelSpeaking = value
	}
}
