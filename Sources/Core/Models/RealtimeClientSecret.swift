import Foundation

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
		public var expiresAfter: ExpiresAfter?
		public var session: Session?

		public init(expiresAfter: ExpiresAfter? = nil, session: Session? = nil) {
			self.expiresAfter = expiresAfter
			self.session = session
		}
	}

	public var value: String
	public var expiresAt: Double
	public var session: Session

	public init(value: String, expiresAt: Double, session: Session) {
		self.value = value
		self.expiresAt = expiresAt
		self.session = session
	}
}
