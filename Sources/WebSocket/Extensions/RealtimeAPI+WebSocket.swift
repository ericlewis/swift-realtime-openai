import Core
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension RealtimeAPI {
	/// Connect to the OpenAI WebSocket Realtime API with the given request.
	static func webSocket(connectingTo request: URLRequest) -> RealtimeAPI {
		RealtimeAPI(connector: WebSocketConnector(connectingTo: request))
	}

	/// Connect to the OpenAI WebSocket Realtime API with the given GA client secret.
	static func webSocket(clientSecret: String) -> RealtimeAPI {
		webSocket(connectingTo: .webSocketConnectionRequest(authToken: clientSecret))
	}

	/// Connect to the OpenAI WebSocket Realtime API with the given authentication token.
	///
	/// Configure the session after connecting with `session.update`.
	static func webSocket(authToken: String) -> RealtimeAPI {
		webSocket(connectingTo: .webSocketConnectionRequest(authToken: authToken))
	}
}
