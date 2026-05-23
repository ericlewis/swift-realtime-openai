import AVFAudio
import Core
import Foundation
import WebSocket
import WebRTC

extension Session {
	/// Connect the session using a fully prepared request.
	///
	/// This is the lowest-level connection entry point exposed by ``Session``.
	public func connect(using request: URLRequest) async throws {
		prepareForConnection()
		if connectionTransport == .webRTC {
			await AVAudioApplication.requestRecordPermission()
		}
		try await transport.connect(request)
	}

	/// Connect the session using a client secret.
	public func connect(clientSecret: String) async throws {
		switch connectionTransport {
			case .webRTC:
				do {
					try await connect(using: .webRTCConnectionRequest(clientSecret: clientSecret))
				} catch let error as WebRTCConnector.WebRTCError {
					guard case .invalidClientSecret = error else { throw error }
					throw SessionError.invalidClientSecret
				}
			case .webSocket:
				try await connect(using: .webSocketConnectionRequest(authToken: clientSecret))
		}
	}

	/// Connect the session using a client secret model object.
	public func connect(clientSecret: RealtimeClientSecret) async throws {
		try await connect(clientSecret: clientSecret.value)
	}

	/// Connect a WebSocket-backed session using a bearer token.
	public func connect(authToken: String) async throws {
		guard connectionTransport == .webSocket else {
			throw SessionError.webSocketTransportRequired
		}
		try await connect(using: .webSocketConnectionRequest(authToken: authToken))
	}

	/// Wait for the connection to be established.
	public func waitForConnection(timeout: Duration = .seconds(30)) async throws {
		try await withThrowingTaskGroup(of: Void.self) { group in
			group.addTask { try await self.awaitConnectionStatus() }
			group.addTask {
				try await Task.sleep(for: timeout)
				throw SessionError.connectionTimedOut
			}

			let result: Void = try await group.next()!
			group.cancelAll()
			return result
		}
	}

	/// Execute a block of code when the connection is established.
	public func whenConnected(_ callback: @Sendable () async throws -> Void) async throws {
		try await waitForConnection()
		try await callback()
	}

	/// Update the active realtime configuration by returning a transformed copy.
	public func updateConfiguration(
		_ transform: (SessionConfiguration.Realtime) throws -> SessionConfiguration.Realtime
	) async throws {
		guard case var .realtime(configuration) = self.configuration else {
			if self.configuration == nil { throw SessionError.configurationNotFound }
			throw SessionError.realtimeConfigurationRequired
		}
		configuration = try transform(configuration)
		try await setConfiguration(configuration)
	}

	/// Update the active transcription configuration by returning a transformed copy.
	public func updateTranscriptionConfiguration(
		_ transform: (SessionConfiguration.Transcription) throws -> SessionConfiguration.Transcription
	) async throws {
		guard case var .transcription(configuration) = self.configuration else {
			if self.configuration == nil { throw SessionError.configurationNotFound }
			throw SessionError.transcriptionConfigurationRequired
		}
		configuration = try transform(configuration)
		try await setConfiguration(configuration)
	}

	/// Replace the current configuration with a realtime session configuration.
	public func setConfiguration(_ configuration: SessionConfiguration.Realtime) async throws {
		try await setConfiguration(.realtime(configuration))
	}

	/// Replace the current configuration with a transcription session configuration.
	public func setConfiguration(_ configuration: SessionConfiguration.Transcription) async throws {
		try await setConfiguration(.transcription(configuration))
	}

	/// Replace the current configuration with a fully constructed ``SessionConfiguration``.
	public func setConfiguration(_ configuration: SessionConfiguration) async throws {
		var configuration = configuration
		configuration.id = nil
		configuration.object = nil
		try await transport.send(.updateSession(configuration))
	}

	package func send(event: ClientEvent) async throws {
		try await transport.send(event)
	}

	/// Append audio bytes to the input buffer and optionally commit them immediately.
	public func send(audioDelta audio: Data, commit: Bool = false) async throws {
		try await send(event: .appendInputAudioBuffer(encoding: audio))
		if commit {
			try await send(event: .commitInputAudioBuffer())
		}
	}

	/// Stop the model mid-response.
	///
	/// Cancels the streaming response and drops any audio the server has already
	/// queued for playback. Use this when the user wants the assistant to stop
	/// speaking immediately rather than waiting for the turn to finish.
	public func interruptResponse(responseId: String? = nil) async throws {
		try await send(event: .cancelResponse(by: responseId))
		try await send(event: .outputAudioBufferClear())
	}
}
