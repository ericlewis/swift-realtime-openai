import Core
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

fileprivate let baseURL = URL(string: "https://api.openai.com/v1/realtime/calls")!

package extension URLRequest {
	/// Creates a request for the GA client secret flow.
	///
	/// The client authenticates directly with a client secret. The session configuration
	/// is already embedded in that secret, so the request does not include a `model` query item.
	/// The SDP offer is sent as the raw body with `application/sdp` content type during the handshake.
	static func webRTCConnectionRequest(clientSecret: String) -> URLRequest {
		var request = URLRequest(url: baseURL)

		request.httpMethod = "POST"
		request.setValue("Bearer \(clientSecret)", forHTTPHeaderField: "Authorization")

		return request
	}

	static func webRTCConnectionRequest(clientSecret: RealtimeClientSecret) -> URLRequest {
		webRTCConnectionRequest(clientSecret: clientSecret.value)
	}

	/// Creates a request for the unified interface flow.
	///
	/// The server authenticates with a standard API key. The SDP offer and session configuration
	/// are sent as multipart form data during the handshake.
	static func webRTCCallRequest(apiKey: String) -> URLRequest {
		var request = URLRequest(url: baseURL)

		request.httpMethod = "POST"
		request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

		return request
	}
}
