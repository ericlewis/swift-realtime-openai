import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

fileprivate let webSocketBaseURL = URL(string: "wss://api.openai.com/v1/realtime")!

package extension URLRequest {
	static func webSocketConnectionRequest(authToken: String, queryItems: [URLQueryItem] = []) -> URLRequest {
		var components = URLComponents(url: webSocketBaseURL, resolvingAgainstBaseURL: false)!
		components.queryItems = queryItems.isEmpty ? nil : queryItems

		var request = URLRequest(url: components.url!)
		request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

		return request
	}
}
