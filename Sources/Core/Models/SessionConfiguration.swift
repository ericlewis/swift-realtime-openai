import Foundation

/// A realtime or transcription session configuration used by the high-level runtime and client-secret APIs.
public enum SessionConfiguration: Equatable, Hashable, Sendable {
	case realtime(Realtime)
	case transcription(Transcription)
}
