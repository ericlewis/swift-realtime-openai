import AVFAudio
import Core
import Foundation
import WebRTC

public enum ConversationError: Error {
	case sessionNotFound
	case invalidClientSecret
	case converterInitializationFailed
}

@MainActor @Observable
public final class Conversation: @unchecked Sendable {
	public typealias SessionUpdateCallback = (inout Session.Realtime) -> Void

	public struct Snapshot: Sendable, Equatable {
		public var status: RealtimeAPI.Status
		public var isUserSpeaking: Bool
		public var isModelSpeaking: Bool
		public var entries: [Item]
		public var messages: [Item.Message]

		public init(
			status: RealtimeAPI.Status,
			isUserSpeaking: Bool,
			isModelSpeaking: Bool,
			entries: [Item],
			messages: [Item.Message]
		) {
			self.status = status
			self.isUserSpeaking = isUserSpeaking
			self.isModelSpeaking = isModelSpeaking
			self.entries = entries
			self.messages = messages
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
		let send: @Sendable (ClientEvent) throws -> Void
		let disconnect: @Sendable () -> Void
		let setMuted: @Sendable (Bool) -> Void
	}

	private let transport: Transport
	private var task: Task<Void, Never>!
	private var statusTask: Task<Void, Never>!
	private let toolRegistry: ToolRegistry?
	private let sessionUpdateCallback: SessionUpdateCallback?
	private let errorStream: AsyncStream<ServerError>.Continuation
	private let updateStream: AsyncStream<Snapshot>.Continuation
	private var lastPublishedSnapshot: Snapshot?

	/// Whether to print debug information to the console.
	public var debug: Bool

	/// Whether to mute the user's microphone.
	public var muted: Bool = false {
		didSet {
			transport.setMuted(muted)
		}
	}

	/// The unique ID of the conversation.
	public private(set) var id: String?

	/// A stream of errors that occur during the conversation.
	public let errors: AsyncStream<ServerError>

	/// A stream of state snapshots for consumers that prefer explicit async updates over Observation.
	public let updates: AsyncStream<Snapshot>

	/// The current realtime session for this conversation.
	public private(set) var session: Session.Realtime?

	/// A list of items in the conversation.
	private var entryRecords: [EntryRecord] = []

	public var entries: [Item] {
		entryRecords.map(\.item)
	}

	public private(set) var status: RealtimeAPI.Status

	/// Whether the user is currently speaking.
	/// This only works when using the server's voice detection.
	public private(set) var isUserSpeaking: Bool = false

	/// Whether the model is currently speaking.
	public private(set) var isModelSpeaking: Bool = false

	/// A list of messages in the conversation.
	/// Note that this doesn't include function call events. To get a complete list, use `entries`.
	public var messages: [Item.Message] {
		entryRecords.compactMap {
			guard case let .message(message) = $0.item else { return nil }
			return message
		}
	}

	public required init(debug: Bool = false, configuring sessionUpdateCallback: SessionUpdateCallback? = nil) {
		let client = try! WebRTCConnector.create()
		self.transport = Self.makeLiveTransport(from: client)
		self.debug = debug
		self.toolRegistry = nil
		self.sessionUpdateCallback = sessionUpdateCallback
		self.status = transport.status()
		(errors, errorStream) = AsyncStream.makeStream(of: ServerError.self)
		(updates, updateStream) = AsyncStream.makeStream(of: Snapshot.self)
		task = Self.makeEventTask(transport: transport) { [weak self] event in
			guard let self else { return }
			try await self.handleEvent(event)
		}
		statusTask = Self.makeStatusTask(transport: transport) { [weak self] status in
			guard let self else { return }
			self.status = status
			self.publishSnapshotIfNeeded()
		}
		publishSnapshotIfNeeded()
	}

	/// Creates a new conversation with the given tools and optional session configuration.
	///
	/// Tools registered here are automatically dispatched when the model invokes them.
	/// The tool definitions are injected into the session configuration on connect.
	///
	/// - Parameter tools: An array of ``RealtimeTool`` instances to register.
	/// - Parameter debug: Whether to print debug information to the console.
	/// - Parameter sessionUpdateCallback: An optional callback to configure the session.
	public init(tools: [any RealtimeTool], debug: Bool = false, configuring sessionUpdateCallback: SessionUpdateCallback? = nil) {
		let client = try! WebRTCConnector.create()
		self.transport = Self.makeLiveTransport(from: client)
		self.debug = debug
		self.toolRegistry = ToolRegistry(tools)
		self.sessionUpdateCallback = sessionUpdateCallback
		self.status = transport.status()
		(errors, errorStream) = AsyncStream.makeStream(of: ServerError.self)
		(updates, updateStream) = AsyncStream.makeStream(of: Snapshot.self)
		task = Self.makeEventTask(transport: transport) { [weak self] event in
			guard let self else { return }
			try await self.handleEvent(event)
		}
		statusTask = Self.makeStatusTask(transport: transport) { [weak self] status in
			guard let self else { return }
			self.status = status
			self.publishSnapshotIfNeeded()
		}
		publishSnapshotIfNeeded()
	}

	init(
		transport: Transport,
		toolRegistry: ToolRegistry? = nil,
		debug: Bool = false,
		configuring sessionUpdateCallback: SessionUpdateCallback? = nil
	) {
		self.transport = transport
		self.debug = debug
		self.toolRegistry = toolRegistry
		self.sessionUpdateCallback = sessionUpdateCallback
		self.status = transport.status()
		(errors, errorStream) = AsyncStream.makeStream(of: ServerError.self)
		(updates, updateStream) = AsyncStream.makeStream(of: Snapshot.self)
		task = Self.makeEventTask(transport: transport) { [weak self] event in
			guard let self else { return }
			try await self.handleEvent(event)
		}
		statusTask = Self.makeStatusTask(transport: transport) { [weak self] status in
			guard let self else { return }
			self.status = status
			self.publishSnapshotIfNeeded()
		}
		publishSnapshotIfNeeded()
	}

	deinit {
		transport.disconnect()
		errorStream.finish()
		updateStream.finish()
	}

	public func connect(using request: URLRequest) async throws {
		await AVAudioApplication.requestRecordPermission()
		try await transport.connect(request)
	}

	public func connect(clientSecret: String) async throws {
		do {
			try await connect(using: .webRTCConnectionRequest(clientSecret: clientSecret))
		} catch let error as WebRTCConnector.WebRTCError {
			guard case .invalidClientSecret = error else { throw error }
			throw ConversationError.invalidClientSecret
		}
	}

	public func connect(clientSecret: RealtimeClientSecret) async throws {
		try await connect(clientSecret: clientSecret.value)
	}

	/// Wait for the connection to be established.
	public func waitForConnection() async {
		while status != .connected {
			try? await Task.sleep(for: .milliseconds(500))
		}
	}

	/// Execute a block of code when the connection is established.
	public func whenConnected<E>(_ callback: @Sendable () async throws(E) -> Void) async throws(E) {
		await waitForConnection()
		try await callback()
	}

	/// Make changes to the current session.
	/// Note that this will fail if the session hasn't started yet. Use `whenConnected` to ensure the session is ready.
	public func updateSession(withChanges callback: (inout Session.Realtime) throws -> Void) throws {
		guard var session else { throw ConversationError.sessionNotFound }
		try callback(&session)
		try setSession(session)
	}

	/// Set the configuration of the current session.
	public func setSession(_ session: Session.Realtime) throws {
		var session = session
		session.id = nil
		session.object = nil
		try transport.send(.updateSession(session))
	}

	/// Send a client event to the server.
	/// > Warning: This function is intended for advanced use cases. Use the other functions to send messages and audio data.
	public func send(event: ClientEvent) throws {
		try transport.send(event)
	}

	/// Manually append audio bytes to the conversation.
	/// Commit the audio to trigger a model response when server turn detection is disabled.
	/// > Note: The `Conversation` class can automatically handle listening to the user's mic and playing back model responses.
	/// > To get started, call the `startListening` function.
	public func send(audioDelta audio: Data, commit: Bool = false) throws {
		try send(event: .appendInputAudioBuffer(encoding: audio))
		if commit {
			try send(event: .commitInputAudioBuffer())
		}
	}

	/// Send a text message and wait for a response.
	/// Optionally, you can provide a response configuration to customize the model's behavior.
	public func send(from role: Item.Message.Role, text: String, response: Response.Config? = nil) throws {
		let content: Item.Message.Content = switch role {
			case .assistant: .outputText(text)
			case .user, .system: .inputText(text)
		}

		let item = Item.message(.init(id: String(randomLength: 32), role: role, content: [content]))
		try send(event: .createConversationItem(item))
		try send(event: .createResponse(using: response))
	}

	/// Send the response of a function call.
	public func send(result output: Item.FunctionCallOutput) throws {
		try send(event: .createConversationItem(.functionCallOutput(output)))
	}

	func receive(serverEvent event: ServerEvent) async throws {
		try await handleEvent(event)
	}
}

private extension Conversation {
	static func makeLiveTransport(from client: WebRTCConnector) -> Transport {
		.init(
			events: client.events,
			statusUpdates: client.statusUpdates,
			status: { client.status },
			connect: { request in try await client.connect(using: request) },
			send: { event in try client.send(event: event) },
			disconnect: { client.disconnect() },
			setMuted: { muted in client.audioTrack.isEnabled = !muted }
		)
	}

	static func makeEventTask(
		transport: Transport,
		handleEvent: @escaping @Sendable (ServerEvent) async throws -> Void
	) -> Task<Void, Never> {
		Task { @MainActor in
			do {
				for try await event in transport.events {
					do { try await handleEvent(event) }
					catch { print("Unhandled error in event handler: \(error)") }

					guard !Task.isCancelled else { break }
				}
			} catch {
				print("Unhandled error in conversation task: \(error)")
			}
		}
	}

	static func makeStatusTask(
		transport: Transport,
		handleStatus: @escaping @MainActor @Sendable (RealtimeAPI.Status) -> Void
	) -> Task<Void, Never> {
		Task { @MainActor in
			for await status in transport.statusUpdates {
				handleStatus(status)

				guard !Task.isCancelled else { break }
			}
		}
	}

	func handleEvent(_ event: ServerEvent) async throws {
		if debug { print(event) }

		switch event {
			case let .error(_, error):
				errorStream.yield(error)
			case let .sessionCreated(_, session):
				try handleSession(session)
			case let .sessionUpdated(_, session):
				guard case let .realtime(realtimeSession) = session else { break }
				self.session = realtimeSession
			case let .conversationCreated(_, conversation):
				id = conversation.id
			case let .conversationItemCreated(_, item, previousItemId):
				upsertEntry(item, after: previousItemId)
			case let .conversationItemAdded(_, item, previousItemId):
				upsertEntry(item, after: previousItemId)
			case let .conversationItemDone(_, item, previousItemId):
				upsertEntry(item, after: previousItemId)
			case let .conversationItemDeleted(_, itemId):
				entryRecords.removeAll { $0.item.id == itemId }
			case let .conversationItemInputAudioTranscriptionCompleted(_, itemId, contentIndex, transcript, _, _):
				updateMessage(id: itemId) { message in
					guard message.content.indices.contains(contentIndex) else { return }
					guard case let .inputAudio(audio) = message.content[contentIndex] else { return }
					message.content[contentIndex] = .inputAudio(.init(audio: audio.audio, transcript: transcript))
				}
			case let .conversationItemInputAudioTranscriptionFailed(_, _, _, error):
				errorStream.yield(error)
			case let .responseCreated(_, response):
				if id == nil {
					id = response.conversationId
				}
			case let .responseContentPartAdded(_, _, itemId, _, contentIndex, part):
				updateMessage(id: itemId) { message in
					insertOrAppend(messageContent(for: part), at: contentIndex, in: &message.content)
				}
			case let .responseContentPartDone(_, _, itemId, _, contentIndex, part):
				updateMessage(id: itemId) { message in
					setOrAppend(messageContent(for: part), at: contentIndex, in: &message.content)
				}
			case let .responseOutputTextDelta(_, _, itemId, _, contentIndex, delta):
				updateMessage(id: itemId) { message in
					guard message.content.indices.contains(contentIndex) else {
						message.content.append(.outputText(delta))
						return
					}

					switch message.content[contentIndex] {
						case let .outputText(text):
							message.content[contentIndex] = .outputText(text + delta)
						default:
							message.content[contentIndex] = .outputText(delta)
					}
				}
			case let .responseOutputTextDone(_, _, itemId, _, contentIndex, text):
				updateMessage(id: itemId) { message in
					setOrAppend(.outputText(text), at: contentIndex, in: &message.content)
				}
			case let .responseOutputAudioTranscriptDelta(_, _, itemId, _, contentIndex, delta):
				updateMessage(id: itemId) { message in
					guard message.content.indices.contains(contentIndex) else {
						message.content.append(.outputAudio(Item.Audio(audio: AudioData?.none, transcript: delta)))
						return
					}

					switch message.content[contentIndex] {
						case let .outputAudio(audio):
							message.content[contentIndex] = .outputAudio(Item.Audio(audio: audio.audio, transcript: (audio.transcript ?? "") + delta))
						default:
							message.content[contentIndex] = .outputAudio(Item.Audio(audio: AudioData?.none, transcript: delta))
					}
				}
			case let .responseOutputAudioTranscriptDone(_, _, itemId, _, contentIndex, transcript):
				updateMessage(id: itemId) { message in
					guard message.content.indices.contains(contentIndex) else {
						message.content.append(.outputAudio(Item.Audio(audio: AudioData?.none, transcript: transcript)))
						return
					}

					switch message.content[contentIndex] {
						case let .outputAudio(audio):
							message.content[contentIndex] = .outputAudio(Item.Audio(audio: audio.audio, transcript: transcript))
						default:
							message.content[contentIndex] = .outputAudio(Item.Audio(audio: AudioData?.none, transcript: transcript))
					}
				}
			case let .responseOutputAudioDelta(_, _, itemId, _, contentIndex, delta):
				updateMessage(id: itemId) { message in
					guard message.content.indices.contains(contentIndex) else {
						message.content.append(.outputAudio(Item.Audio(audio: delta.data)))
						return
					}

					switch message.content[contentIndex] {
						case let .outputAudio(audio):
							let combinedAudio = (audio.audio?.data ?? Data()) + delta.data
							message.content[contentIndex] = .outputAudio(Item.Audio(audio: combinedAudio, transcript: audio.transcript))
						default:
							message.content[contentIndex] = .outputAudio(Item.Audio(audio: delta.data))
					}
				}
			case let .responseFunctionCallArgumentsDelta(_, _, itemId, _, _, delta):
				updateFunctionCall(id: itemId) { functionCall in
					functionCall.arguments.append(delta)
				}
			case let .responseFunctionCallArgumentsDone(_, _, itemId, _, callId, arguments):
				updateFunctionCall(id: itemId) { functionCall in
					functionCall.arguments = arguments
				}
				try await dispatchToolIfNeeded(forItemId: itemId, callId: callId, arguments: arguments)
			case .inputAudioBufferSpeechStarted:
				isUserSpeaking = true
			case .inputAudioBufferSpeechStopped:
				isUserSpeaking = false
			case .outputAudioBufferStarted:
				isModelSpeaking = true
			case .outputAudioBufferStopped:
				isModelSpeaking = false
			case let .responseOutputItemAdded(_, _, _, item):
				replaceEntryIfPresent(item)
			case let .responseOutputItemDone(_, _, _, item):
				replaceEntryIfPresent(item)
			default:
				break
		}

		publishSnapshotIfNeeded()
	}

	func handleSession(_ session: Session) throws {
		guard case let .realtime(realtimeSession) = session else { return }

		self.session = realtimeSession

		var updatedSession = realtimeSession
		var needsUpdate = false

		if let toolRegistry {
			updatedSession.tools = (updatedSession.tools ?? []) + toolRegistry.definitions
			needsUpdate = true
		}

		if let sessionUpdateCallback {
			sessionUpdateCallback(&updatedSession)
			needsUpdate = true
		}

		if needsUpdate {
			try setSession(updatedSession)
		}
	}

	func dispatchToolIfNeeded(forItemId itemId: String, callId: String, arguments: String) async throws {
		guard let toolRegistry else { return }
		guard
			let item = entryRecords.first(where: { matches($0, id: itemId) })?.item,
			case let .functionCall(functionCall) = item
		else {
			return
		}

		do {
			let output = try await toolRegistry.handle(name: functionCall.name, callId: callId, arguments: arguments)
			try send(result: output)
			try send(event: .createResponse())
		} catch {
			print("Tool call failed for '\(functionCall.name)': \(error)")
		}
	}

	func upsertEntry(_ item: Item, after previousItemId: String?) {
		if let itemId = item.id, let index = entryRecords.firstIndex(where: { $0.item.id == itemId }) {
			entryRecords[index].item = item
			return
		}

		let record = EntryRecord(localId: UUID().uuidString, item: item)

		guard let previousItemId else {
			entryRecords.append(record)
			return
		}

		if previousItemId == "root" {
			entryRecords.insert(record, at: 0)
			return
		}

		guard let previousIndex = entryRecords.firstIndex(where: { $0.item.id == previousItemId }) else {
			entryRecords.append(record)
			return
		}

		entryRecords.insert(record, at: previousIndex + 1)
	}

	func replaceEntryIfPresent(_ item: Item) {
		guard let itemId = item.id,
		      let index = entryRecords.firstIndex(where: { $0.item.id == itemId })
		else {
			return
		}
		entryRecords[index].item = item
	}

	func updateMessage(id: String, modifying closure: (inout Item.Message) -> Void) {
		guard let index = entryRecords.firstIndex(where: { matches($0, id: id) }),
		      case var .message(message) = entryRecords[index].item
		else {
			return
		}

		closure(&message)
		entryRecords[index].item = .message(message)
	}

	func updateFunctionCall(id: String, modifying closure: (inout Item.FunctionCall) -> Void) {
		guard let index = entryRecords.firstIndex(where: { matches($0, id: id) }),
		      case var .functionCall(functionCall) = entryRecords[index].item
		else {
			return
		}

		closure(&functionCall)
		entryRecords[index].item = .functionCall(functionCall)
	}

	func messageContent(for part: Response.ContentPart) -> Item.Message.Content {
		switch part {
			case let .outputText(text):
				.outputText(text)
			case let .outputAudio(audio):
				.outputAudio(audio)
		}
	}

	func matches(_ record: EntryRecord, id: String) -> Bool {
		record.localId == id || record.item.id == id
	}

	func insertOrAppend(_ content: Item.Message.Content, at index: Int, in contents: inout [Item.Message.Content]) {
		if index <= contents.count {
			contents.insert(content, at: index)
		} else {
			contents.append(content)
		}
	}

	func setOrAppend(_ content: Item.Message.Content, at index: Int, in contents: inout [Item.Message.Content]) {
		if contents.indices.contains(index) {
			contents[index] = content
		} else {
			contents.append(content)
		}
	}

	func publishSnapshotIfNeeded() {
		let snapshot = Snapshot(
			status: status,
			isUserSpeaking: isUserSpeaking,
			isModelSpeaking: isModelSpeaking,
			entries: entries,
			messages: messages
		)

		guard snapshot != lastPublishedSnapshot else { return }
		lastPublishedSnapshot = snapshot
		updateStream.yield(snapshot)
	}
}
