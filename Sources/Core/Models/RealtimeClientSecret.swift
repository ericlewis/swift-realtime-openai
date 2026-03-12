import Foundation

/// A short-lived client secret used to authenticate browser or device clients to the Realtime API.
public struct RealtimeClientSecret: Equatable, Hashable, Codable, Sendable {
	public struct ExpiresAfter: Equatable, Hashable, Codable, Sendable {
		public enum Anchor: String, Equatable, Hashable, Codable, Sendable {
			case createdAt = "created_at"
		}

		public var anchor: Anchor
		public var seconds: Int

		public init(anchor: Anchor = .createdAt, seconds: Int) {
			self.anchor = anchor
			self.seconds = seconds
		}
	}

	public struct Request: Equatable, Hashable, Codable, Sendable {
		private enum CodingKeys: String, CodingKey {
			case expiresAfter
			case configuration = "session"
		}

		public var expiresAfter: ExpiresAfter?
		public var configuration: SessionConfiguration?

		public init(expiresAfter: ExpiresAfter? = nil, configuration: SessionConfiguration? = nil) {
			self.expiresAfter = expiresAfter
			self.configuration = configuration
		}
	}

	private enum CodingKeys: String, CodingKey {
		case value
		case expiresAt
		case configuration = "session"
	}

	public var value: String
	public var expiresAt: Double
	public var configuration: SessionConfiguration

	public init(value: String, expiresAt: Double, configuration: SessionConfiguration) {
		self.value = value
		self.expiresAt = expiresAt
		self.configuration = configuration
	}
}
