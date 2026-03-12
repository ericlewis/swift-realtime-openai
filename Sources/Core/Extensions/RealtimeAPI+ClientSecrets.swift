import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension RealtimeAPI {
	enum ClientSecretError: Swift.Error {
		case badServerResponse(statusCode: Int?, body: String?)
	}

	static func createClientSecret(
		apiKey: String,
		configuration: SessionConfiguration? = nil,
		expiresAfter: RealtimeClientSecret.ExpiresAfter? = nil,
		using urlSession: URLSession = .shared
	) async throws -> RealtimeClientSecret {
		try await createClientSecret(
			apiKey: apiKey,
			request: .init(expiresAfter: expiresAfter, configuration: configuration),
			using: urlSession
		)
	}

	static func createClientSecret(
		apiKey: String,
		request: RealtimeClientSecret.Request = .init(),
		using urlSession: URLSession = .shared
	) async throws -> RealtimeClientSecret {
		var urlRequest = URLRequest(url: URL(string: "https://api.openai.com/v1/realtime/client_secrets")!)
		urlRequest.httpMethod = "POST"
		urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
		urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

		let encoder = JSONEncoder()
		encoder.keyEncodingStrategy = .convertToSnakeCase
		urlRequest.httpBody = try encoder.encode(request)

		let (data, response) = try await urlSession.data(for: urlRequest)

		guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
			throw ClientSecretError.badServerResponse(
				statusCode: (response as? HTTPURLResponse)?.statusCode,
				body: String(data: data, encoding: .utf8)
			)
		}

		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode(RealtimeClientSecret.self, from: data)
	}
}
