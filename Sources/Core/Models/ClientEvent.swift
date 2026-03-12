import Foundation

package enum ClientEvent: Equatable, Hashable, Sendable {
	case updateSession(eventId: String?, session: SessionConfiguration)
	case appendInputAudioBuffer(eventId: String?, audio: AudioData)
	case commitInputAudioBuffer(eventId: String?)
	case clearInputAudioBuffer(eventId: String?)
	case createConversationItem(eventId: String?, previousItemId: String?, item: Item)
	case retrieveConversationItem(eventId: String?, itemId: String)
	case truncateConversationItem(eventId: String?, itemId: String, contentIndex: Int, audioEndMs: Int)
	case deleteConversationItem(eventId: String?, itemId: String)
	case createResponse(eventId: String?, response: ResponseDTO.Config?)
	case cancelResponse(eventId: String?, responseId: String?)
	case outputAudioBufferClear(eventId: String?)
}

extension ClientEvent: Codable {
	private enum CodingKeys: String, CodingKey {
		case audio
		case audioEndMs
		case contentIndex
		case eventId
		case item
		case itemId
		case previousItemId
		case response
		case responseId
		case session
		case type
	}

	private var type: String {
		switch self {
			case .updateSession: "session.update"
			case .appendInputAudioBuffer: "input_audio_buffer.append"
			case .commitInputAudioBuffer: "input_audio_buffer.commit"
			case .clearInputAudioBuffer: "input_audio_buffer.clear"
			case .createConversationItem: "conversation.item.create"
			case .retrieveConversationItem: "conversation.item.retrieve"
			case .truncateConversationItem: "conversation.item.truncate"
			case .deleteConversationItem: "conversation.item.delete"
			case .createResponse: "response.create"
			case .cancelResponse: "response.cancel"
			case .outputAudioBufferClear: "output_audio_buffer.clear"
		}
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(type, forKey: .type)

		switch self {
			case let .updateSession(eventId, session):
				try container.encodeIfPresent(eventId, forKey: .eventId)
				try container.encode(session, forKey: .session)
			case let .appendInputAudioBuffer(eventId, audio):
				try container.encodeIfPresent(eventId, forKey: .eventId)
				try container.encode(audio, forKey: .audio)
			case let .commitInputAudioBuffer(eventId):
				try container.encodeIfPresent(eventId, forKey: .eventId)
			case let .clearInputAudioBuffer(eventId):
				try container.encodeIfPresent(eventId, forKey: .eventId)
			case let .createConversationItem(eventId, previousItemId, item):
				try container.encodeIfPresent(eventId, forKey: .eventId)
				try container.encodeIfPresent(previousItemId, forKey: .previousItemId)
				try container.encode(item, forKey: .item)
			case let .retrieveConversationItem(eventId, itemId):
				try container.encodeIfPresent(eventId, forKey: .eventId)
				try container.encode(itemId, forKey: .itemId)
			case let .truncateConversationItem(eventId, itemId, contentIndex, audioEndMs):
				try container.encodeIfPresent(eventId, forKey: .eventId)
				try container.encode(itemId, forKey: .itemId)
				try container.encode(contentIndex, forKey: .contentIndex)
				try container.encode(audioEndMs, forKey: .audioEndMs)
			case let .deleteConversationItem(eventId, itemId):
				try container.encodeIfPresent(eventId, forKey: .eventId)
				try container.encode(itemId, forKey: .itemId)
			case let .createResponse(eventId, response):
				try container.encodeIfPresent(eventId, forKey: .eventId)
				try container.encodeIfPresent(response, forKey: .response)
			case let .cancelResponse(eventId, responseId):
				try container.encodeIfPresent(eventId, forKey: .eventId)
				try container.encodeIfPresent(responseId, forKey: .responseId)
			case let .outputAudioBufferClear(eventId):
				try container.encodeIfPresent(eventId, forKey: .eventId)
		}
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(String.self, forKey: .type)

		switch type {
			case "session.update":
				self = .updateSession(
					eventId: try container.decodeIfPresent(String.self, forKey: .eventId),
					session: try container.decode(SessionConfiguration.self, forKey: .session)
				)
			case "input_audio_buffer.append":
				self = .appendInputAudioBuffer(
					eventId: try container.decodeIfPresent(String.self, forKey: .eventId),
					audio: try container.decode(AudioData.self, forKey: .audio)
				)
			case "input_audio_buffer.commit":
				self = .commitInputAudioBuffer(eventId: try container.decodeIfPresent(String.self, forKey: .eventId))
			case "input_audio_buffer.clear":
				self = .clearInputAudioBuffer(eventId: try container.decodeIfPresent(String.self, forKey: .eventId))
			case "conversation.item.create":
				self = .createConversationItem(
					eventId: try container.decodeIfPresent(String.self, forKey: .eventId),
					previousItemId: try container.decodeIfPresent(String.self, forKey: .previousItemId),
					item: try container.decode(Item.self, forKey: .item)
				)
			case "conversation.item.retrieve":
				self = .retrieveConversationItem(
					eventId: try container.decodeIfPresent(String.self, forKey: .eventId),
					itemId: try container.decode(String.self, forKey: .itemId)
				)
			case "conversation.item.truncate":
				self = .truncateConversationItem(
					eventId: try container.decodeIfPresent(String.self, forKey: .eventId),
					itemId: try container.decode(String.self, forKey: .itemId),
					contentIndex: try container.decode(Int.self, forKey: .contentIndex),
					audioEndMs: try container.decode(Int.self, forKey: .audioEndMs)
				)
			case "conversation.item.delete":
				self = .deleteConversationItem(
					eventId: try container.decodeIfPresent(String.self, forKey: .eventId),
					itemId: try container.decode(String.self, forKey: .itemId)
				)
			case "response.create":
				self = .createResponse(
					eventId: try container.decodeIfPresent(String.self, forKey: .eventId),
					response: try container.decodeIfPresent(ResponseDTO.Config.self, forKey: .response)
				)
			case "response.cancel":
				self = .cancelResponse(
					eventId: try container.decodeIfPresent(String.self, forKey: .eventId),
					responseId: try container.decodeIfPresent(String.self, forKey: .responseId)
				)
			case "output_audio_buffer.clear":
				self = .outputAudioBufferClear(eventId: try container.decodeIfPresent(String.self, forKey: .eventId))
			default:
				throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown client event type: \(type)")
		}
	}
}

package extension ClientEvent {
	static func updateSession(_ session: SessionConfiguration, withEventId eventId: String? = nil) -> ClientEvent {
		.updateSession(eventId: eventId, session: session)
	}

	static func updateSession(_ session: SessionConfiguration.Realtime, withEventId eventId: String? = nil) -> ClientEvent {
		.updateSession(.realtime(session), withEventId: eventId)
	}

	static func updateSession(_ session: SessionConfiguration.Transcription, withEventId eventId: String? = nil) -> ClientEvent {
		.updateSession(.transcription(session), withEventId: eventId)
	}

	static func appendInputAudioBuffer(encoding audio: Data, withEventId eventId: String? = nil) -> ClientEvent {
		.appendInputAudioBuffer(eventId: eventId, audio: AudioData(data: audio))
	}

	static func commitInputAudioBuffer(withEventId eventId: String? = nil) -> ClientEvent {
		.commitInputAudioBuffer(eventId: eventId)
	}

	static func clearInputAudioBuffer(withEventId eventId: String? = nil) -> ClientEvent {
		.clearInputAudioBuffer(eventId: eventId)
	}

	static func createConversationItem(after previousItemId: String? = nil, _ item: Item, withEventId eventId: String? = nil) -> ClientEvent {
		.createConversationItem(eventId: eventId, previousItemId: previousItemId, item: item)
	}

	static func retrieveConversationItem(by itemId: String, withEventId eventId: String? = nil) -> ClientEvent {
		.retrieveConversationItem(eventId: eventId, itemId: itemId)
	}

	static func truncateConversationItem(forItem itemId: String, at contentIndex: Int = 0, atAudioMs audioEndMs: Int, withEventId eventId: String? = nil) -> ClientEvent {
		.truncateConversationItem(eventId: eventId, itemId: itemId, contentIndex: contentIndex, audioEndMs: audioEndMs)
	}

	static func deleteConversationItem(by itemId: String, withEventId eventId: String? = nil) -> ClientEvent {
		.deleteConversationItem(eventId: eventId, itemId: itemId)
	}

	static func createResponse(using response: ResponseDTO.Config? = nil, withEventId eventId: String? = nil) -> ClientEvent {
		.createResponse(eventId: eventId, response: response)
	}

	static func cancelResponse(by responseId: String? = nil, withEventId eventId: String? = nil) -> ClientEvent {
		.cancelResponse(eventId: eventId, responseId: responseId)
	}

	static func outputAudioBufferClear(withEventId eventId: String? = nil) -> ClientEvent {
		.outputAudioBufferClear(eventId: eventId)
	}
}
