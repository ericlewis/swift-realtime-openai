import Core
import Foundation

extension Session {
	func handleEvent(_ event: ServerEvent) async throws {
		if debug {
			Self.logger.debug("\(String(describing: event), privacy: .public)")
		}

		switch event {
			case let .error(_, error):
				errorStream.yield(error)
			case let .sessionCreated(_, configuration):
				try await handleConfiguration(configuration)
			case let .sessionUpdated(_, configuration):
				storeConfiguration(configuration)
			case let .conversationCreated(_, conversation):
				storeConversationID(conversation.id)
			case let .conversationItemCreated(_, item, previousItemId):
				upsertEntry(item, after: previousItemId)
			case let .conversationItemAdded(_, item, previousItemId):
				upsertEntry(item, after: previousItemId)
			case let .conversationItemDone(_, item, previousItemId):
				upsertEntry(item, after: previousItemId)
			case let .conversationItemDeleted(_, itemId):
				entryRecords.removeAll { $0.item.id == itemId }
				rebuildEntryIndexes()
				markConversationChanged()
			case let .conversationItemInputAudioTranscriptionCompleted(_, itemId, contentIndex, transcript, _, _):
				updateMessage(id: itemId) { message in
					guard message.content.indices.contains(contentIndex) else { return }
					guard case let .inputAudio(audio) = message.content[contentIndex] else { return }
					message.content[contentIndex] = .inputAudio(.init(audio: audio.audio, transcript: transcript))
				}
			case let .conversationItemInputAudioTranscriptionFailed(_, _, _, error):
				errorStream.yield(error)
			case let .responseCreated(_, response):
				storeResponseConversationIDIfNeeded(response.conversationId)
			case let .responseContentPartAdded(_, _, itemId, _, contentIndex, part):
				updateMessage(id: itemId) { message in
					insertOrAppend(messageContent(for: part), at: contentIndex, in: &message.content)
				}
			case let .responseContentPartDone(_, _, itemId, _, contentIndex, part):
				updateMessage(id: itemId) { message in
					setOrAppend(messageContent(for: part), at: contentIndex, in: &message.content)
				}
			case let .responseOutputTextDelta(_, _, itemId, _, contentIndex, delta):
				updateMessage(id: itemId) { message in
					guard message.content.indices.contains(contentIndex) else {
						message.content.append(.outputText(delta))
						return
					}

					switch message.content[contentIndex] {
						case let .outputText(text):
							message.content[contentIndex] = .outputText(text + delta)
						default:
							message.content[contentIndex] = .outputText(delta)
					}
				}
			case let .responseOutputTextDone(_, _, itemId, _, contentIndex, text):
				updateMessage(id: itemId) { message in
					setOrAppend(.outputText(text), at: contentIndex, in: &message.content)
				}
			case let .responseOutputAudioTranscriptDelta(_, _, itemId, _, contentIndex, delta):
				updateMessage(id: itemId) { message in
					guard message.content.indices.contains(contentIndex) else {
						message.content.append(.outputAudio(Item.Audio(audio: AudioData?.none, transcript: delta)))
						return
					}

					switch message.content[contentIndex] {
						case let .outputAudio(audio):
							message.content[contentIndex] = .outputAudio(Item.Audio(audio: audio.audio, transcript: (audio.transcript ?? "") + delta))
						default:
							message.content[contentIndex] = .outputAudio(Item.Audio(audio: AudioData?.none, transcript: delta))
					}
				}
			case let .responseOutputAudioTranscriptDone(_, _, itemId, _, contentIndex, transcript):
				updateMessage(id: itemId) { message in
					guard message.content.indices.contains(contentIndex) else {
						message.content.append(.outputAudio(Item.Audio(audio: AudioData?.none, transcript: transcript)))
						return
					}

					switch message.content[contentIndex] {
						case let .outputAudio(audio):
							message.content[contentIndex] = .outputAudio(Item.Audio(audio: audio.audio, transcript: transcript))
						default:
							message.content[contentIndex] = .outputAudio(Item.Audio(audio: AudioData?.none, transcript: transcript))
					}
				}
			case let .responseOutputAudioDelta(_, _, itemId, _, contentIndex, delta):
				updateMessage(id: itemId) { message in
					guard message.content.indices.contains(contentIndex) else {
						message.content.append(.outputAudio(Item.Audio(audio: delta.data)))
						return
					}

					switch message.content[contentIndex] {
						case let .outputAudio(audio):
							let combinedAudio = (audio.audio?.data ?? Data()) + delta.data
							message.content[contentIndex] = .outputAudio(Item.Audio(audio: combinedAudio, transcript: audio.transcript))
						default:
							message.content[contentIndex] = .outputAudio(Item.Audio(audio: delta.data))
					}
				}
			case let .responseFunctionCallArgumentsDelta(_, _, itemId, _, _, delta):
				updateFunctionCall(id: itemId) { functionCall in
					functionCall.arguments.append(delta)
				}
			case let .responseFunctionCallArgumentsDone(_, _, itemId, _, callId, arguments):
				updateFunctionCall(id: itemId) { functionCall in
					functionCall.arguments = arguments
				}
				try await dispatchToolIfNeeded(forItemId: itemId, callId: callId, arguments: arguments)
			case .inputAudioBufferSpeechStarted:
				storeIsUserSpeaking(true)
			case .inputAudioBufferSpeechStopped:
				storeIsUserSpeaking(false)
			case .outputAudioBufferStarted:
				storeIsModelSpeaking(true)
			case .outputAudioBufferStopped:
				storeIsModelSpeaking(false)
			case let .responseOutputItemAdded(_, _, _, item):
				replaceEntryIfPresent(item)
			case let .responseOutputItemDone(_, _, _, item):
				replaceEntryIfPresent(item)
			default:
				break
		}

		publishSnapshotIfNeeded()
	}

	func handleConfiguration(_ configuration: SessionConfiguration) async throws {
		var configuration = configuration
		var needsUpdate = false

		if case var .realtime(realtimeConfiguration) = configuration, let toolRegistry {
			realtimeConfiguration.tools = (realtimeConfiguration.tools ?? []) + toolRegistry.definitions
			configuration = .realtime(realtimeConfiguration)
			needsUpdate = true
		}

		if let configurationTransform {
			configuration = configurationTransform(configuration)
			needsUpdate = true
		}

		storeConfiguration(configuration)

		if needsUpdate {
			try await setConfiguration(configuration)
		}
	}

	func dispatchToolIfNeeded(forItemId itemId: String, callId: String, arguments: String) async throws {
		guard let toolRegistry else { return }
		guard
			let item = entryRecords.first(where: { matches($0, id: itemId) })?.item,
			case let .functionCall(functionCall) = item
		else {
			return
		}

		do {
			let output = try await toolRegistry.handle(name: functionCall.name, callId: callId, arguments: arguments)
			try await send(result: output)
			try await send(event: .createResponse())
		} catch {
			failureStream.yield(.toolCallFailed(name: functionCall.name))
		}
	}
}
