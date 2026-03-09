public enum Model: RawRepresentable, Equatable, Hashable, Codable, Sendable {
	case gptRealtime
	case gptRealtime1_5
	case gptRealtime2025_08_28
	case gpt4oRealtimePreview
	case gpt4oRealtimePreview2024_10_01
	case gpt4oRealtimePreview2024_12_17
	case gpt4oRealtimePreview2025_06_03
	case gpt4oMiniRealtimePreview
	case gpt4oMiniRealtimePreview2024_12_17
	case gptRealtimeMini
	case gptRealtimeMini2025_10_06
	case gptRealtimeMini2025_12_15
	case gptAudio1_5
	case gptAudioMini
	case gptAudioMini2025_10_06
	case gptAudioMini2025_12_15
	case custom(String)

	public var rawValue: String {
		switch self {
			case .gptRealtime: "gpt-realtime"
			case .gptRealtime1_5: "gpt-realtime-1.5"
			case .gptRealtime2025_08_28: "gpt-realtime-2025-08-28"
			case .gpt4oRealtimePreview: "gpt-4o-realtime-preview"
			case .gpt4oRealtimePreview2024_10_01: "gpt-4o-realtime-preview-2024-10-01"
			case .gpt4oRealtimePreview2024_12_17: "gpt-4o-realtime-preview-2024-12-17"
			case .gpt4oRealtimePreview2025_06_03: "gpt-4o-realtime-preview-2025-06-03"
			case .gpt4oMiniRealtimePreview: "gpt-4o-mini-realtime-preview"
			case .gpt4oMiniRealtimePreview2024_12_17: "gpt-4o-mini-realtime-preview-2024-12-17"
			case .gptRealtimeMini: "gpt-realtime-mini"
			case .gptRealtimeMini2025_10_06: "gpt-realtime-mini-2025-10-06"
			case .gptRealtimeMini2025_12_15: "gpt-realtime-mini-2025-12-15"
			case .gptAudio1_5: "gpt-audio-1.5"
			case .gptAudioMini: "gpt-audio-mini"
			case .gptAudioMini2025_10_06: "gpt-audio-mini-2025-10-06"
			case .gptAudioMini2025_12_15: "gpt-audio-mini-2025-12-15"
			case let .custom(value): value
		}
	}

	public init?(rawValue: String) {
		switch rawValue {
			case "gpt-realtime": self = .gptRealtime
			case "gpt-realtime-1.5": self = .gptRealtime1_5
			case "gpt-realtime-2025-08-28": self = .gptRealtime2025_08_28
			case "gpt-4o-realtime-preview": self = .gpt4oRealtimePreview
			case "gpt-4o-realtime-preview-2024-10-01": self = .gpt4oRealtimePreview2024_10_01
			case "gpt-4o-realtime-preview-2024-12-17": self = .gpt4oRealtimePreview2024_12_17
			case "gpt-4o-realtime-preview-2025-06-03": self = .gpt4oRealtimePreview2025_06_03
			case "gpt-4o-mini-realtime-preview": self = .gpt4oMiniRealtimePreview
			case "gpt-4o-mini-realtime-preview-2024-12-17": self = .gpt4oMiniRealtimePreview2024_12_17
			case "gpt-realtime-mini": self = .gptRealtimeMini
			case "gpt-realtime-mini-2025-10-06": self = .gptRealtimeMini2025_10_06
			case "gpt-realtime-mini-2025-12-15": self = .gptRealtimeMini2025_12_15
			case "gpt-audio-1.5": self = .gptAudio1_5
			case "gpt-audio-mini": self = .gptAudioMini
			case "gpt-audio-mini-2025-10-06": self = .gptAudioMini2025_10_06
			case "gpt-audio-mini-2025-12-15": self = .gptAudioMini2025_12_15
			default: self = .custom(rawValue)
		}
	}
}

public extension Model {
	enum Transcription: RawRepresentable, Equatable, Hashable, Codable, Sendable {
		case whisper1
		case gpt4oTranscribeLatest
		case gpt4oMiniTranscribe
		case gpt4oMiniTranscribe2025_12_15
		case gpt4oTranscribe
		case gpt4oTranscribeDiarize
		case custom(String)

		public var rawValue: String {
			switch self {
				case .whisper1: "whisper-1"
				case .gpt4oTranscribeLatest: "gpt-4o-transcribe-latest"
				case .gpt4oMiniTranscribe: "gpt-4o-mini-transcribe"
				case .gpt4oMiniTranscribe2025_12_15: "gpt-4o-mini-transcribe-2025-12-15"
				case .gpt4oTranscribe: "gpt-4o-transcribe"
				case .gpt4oTranscribeDiarize: "gpt-4o-transcribe-diarize"
				case let .custom(value): value
			}
		}

		public init?(rawValue: String) {
			switch rawValue {
				case "whisper-1": self = .whisper1
				case "gpt-4o-mini-transcribe": self = .gpt4oMiniTranscribe
				case "gpt-4o-mini-transcribe-2025-12-15": self = .gpt4oMiniTranscribe2025_12_15
				case "gpt-4o-transcribe": self = .gpt4oTranscribe
				case "gpt-4o-transcribe-diarize": self = .gpt4oTranscribeDiarize
				default: self = .custom(rawValue)
			}
		}
	}
}
