import Core
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension RealtimeAPI {
	/// Connect to the OpenAI WebRTC Realtime API with the given request.
	static func webRTC(connectingTo request: URLRequest) async throws -> RealtimeAPI {
		try RealtimeAPI(connector: await WebRTCConnector.create(connectingTo: request))
	}

	/// Connect to the OpenAI WebRTC Realtime API with the given GA client secret.
	static func webRTC(clientSecret: String) async throws -> RealtimeAPI {
		try await webRTC(connectingTo: .webRTCConnectionRequest(clientSecret: clientSecret))
	}

	/// Connect to the OpenAI WebRTC Realtime API with the given GA client secret object.
	static func webRTC(clientSecret: RealtimeClientSecret) async throws -> RealtimeAPI {
		try await webRTC(clientSecret: clientSecret.value)
	}

	/// Connect to the OpenAI WebRTC Realtime API using the unified interface.
	///
	/// This flow uses a standard API key (not an ephemeral key) and sends the session configuration
	/// alongside the SDP offer as multipart form data. Use this when your app server authenticates
	/// directly with the OpenAI API.
	static func webRTC(apiKey: String, session: Session) async throws -> RealtimeAPI {
		try RealtimeAPI(connector: await WebRTCConnector.create(connectingTo: .webRTCCallRequest(apiKey: apiKey), session: session))
	}
}
