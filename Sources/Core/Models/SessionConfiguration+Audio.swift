import Foundation

public extension SessionConfiguration {
	/// Input-audio settings shared by realtime and transcription session variants.
	struct AudioInput: Equatable, Hashable, Codable, Sendable {
		/// Configures asynchronous transcription for input audio.
		public struct Transcription: Equatable, Hashable, Codable, Sendable {
			public var language: String?
			public var model: Model.Transcription?
			public var prompt: String?

			public init(language: String? = nil, model: Model.Transcription? = nil, prompt: String? = nil) {
				self.language = language
				self.model = model
				self.prompt = prompt
			}
		}

		/// Configures input noise reduction before audio reaches VAD or transcription.
		public struct NoiseReduction: Equatable, Hashable, Codable, Sendable {
			/// The noise-reduction profile tuned for the expected microphone distance.
			public enum Kind: String, Equatable, Hashable, Codable, Sendable {
				case nearField = "near_field"
				case farField = "far_field"
			}

			public var type: Kind

			public init(type: Kind) {
				self.type = type
			}

			public static let nearField = Self(type: .nearField)
			public static let farField = Self(type: .farField)
		}

		/// Configures turn detection for input audio.
		public struct TurnDetection: Equatable, Hashable, Codable, Sendable {
			/// The turn-detection strategy used for input audio.
			public enum Kind: String, Equatable, Hashable, Codable, Sendable {
				case serverVAD = "server_vad"
				case semanticVAD = "semantic_vad"
			}

			/// Controls how aggressively semantic VAD decides that a turn has ended.
			public enum Eagerness: String, Equatable, Hashable, Codable, Sendable {
				case auto, low, medium, high
			}

			public var type: Kind
			public var createResponse: Bool?
			public var eagerness: Eagerness?
			public var idleTimeoutMs: Int?
			public var interruptResponse: Bool?
			public var prefixPaddingMs: Int?
			public var silenceDurationMs: Int?
			public var threshold: Double?

			public init(
				type: Kind,
				createResponse: Bool? = nil,
				eagerness: Eagerness? = nil,
				idleTimeoutMs: Int? = nil,
				interruptResponse: Bool? = nil,
				prefixPaddingMs: Int? = nil,
				silenceDurationMs: Int? = nil,
				threshold: Double? = nil
			) {
				self.type = type
				self.createResponse = createResponse
				self.eagerness = eagerness
				self.idleTimeoutMs = idleTimeoutMs
				self.interruptResponse = interruptResponse
				self.prefixPaddingMs = prefixPaddingMs
				self.silenceDurationMs = silenceDurationMs
				self.threshold = threshold
			}

			public static func serverVAD(
				createResponse: Bool? = nil,
				idleTimeoutMs: Int? = nil,
				interruptResponse: Bool? = nil,
				prefixPaddingMs: Int? = nil,
				silenceDurationMs: Int? = nil,
				threshold: Double? = nil
			) -> Self {
				.init(
					type: .serverVAD,
					createResponse: createResponse,
					idleTimeoutMs: idleTimeoutMs,
					interruptResponse: interruptResponse,
					prefixPaddingMs: prefixPaddingMs,
					silenceDurationMs: silenceDurationMs,
					threshold: threshold
				)
			}

			public static func semanticVAD(
				createResponse: Bool? = nil,
				eagerness: Eagerness? = nil,
				interruptResponse: Bool? = nil
			) -> Self {
				.init(
					type: .semanticVAD,
					createResponse: createResponse,
					eagerness: eagerness,
					interruptResponse: interruptResponse
				)
			}
		}

		public var format: AudioFormat?
		public var noiseReduction: NoiseReduction?
		public var transcription: Transcription?
		public var turnDetection: TurnDetection?

		public init(
			format: AudioFormat? = nil,
			noiseReduction: NoiseReduction? = nil,
			transcription: Transcription? = nil,
			turnDetection: TurnDetection? = nil
		) {
			self.format = format
			self.noiseReduction = noiseReduction
			self.transcription = transcription
			self.turnDetection = turnDetection
		}
	}

	/// Output-audio settings for spoken model responses.
	struct AudioOutput: Equatable, Hashable, Codable, Sendable {
		public var format: AudioFormat?
		public var speed: Double?
		public var voice: Voice?

		public init(format: AudioFormat? = nil, speed: Double? = nil, voice: Voice? = nil) {
			self.format = format
			self.speed = speed
			self.voice = voice
		}
	}
}
