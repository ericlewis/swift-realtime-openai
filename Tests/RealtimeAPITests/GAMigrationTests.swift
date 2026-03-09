import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Observation
import Testing
@testable import Core
@testable import UI

struct GAClientEventEncodingTests {
	@Test
	func sessionUpdateEncodesRealtimeSessionShape() throws {
		let session = Session.Realtime(
			audio: .init(output: .init(voice: .marin)),
			instructions: "Be extra nice today!",
			model: .gptRealtime,
			outputModalities: [.audio]
		)

		let payload = try encodedJSONObject(for: ClientEvent.updateSession(session))
		let sessionJSON = try #require(payload["session"] as? [String: Any])
		let audioJSON = try #require(sessionJSON["audio"] as? [String: Any])
		let outputJSON = try #require(audioJSON["output"] as? [String: Any])

		#expect(payload["type"] as? String == "session.update")
		#expect(sessionJSON["type"] as? String == "realtime")
		#expect(sessionJSON["model"] as? String == "gpt-realtime")
		#expect(sessionJSON["instructions"] as? String == "Be extra nice today!")
		#expect(outputJSON["voice"] as? String == "marin")
		#expect(sessionJSON["output_modalities"] as? [String] == ["audio"])
	}

	@Test
	func transcriptionSessionUpdateEncodesTranscriptionSessionShape() throws {
		let session = Session.Transcription(
			audio: .init(input: .init(
				transcription: .init(language: "en", model: .gpt4oTranscribe),
				turnDetection: .serverVAD(threshold: 0.6)
			)),
			include: [.inputAudioTranscriptionLogprobs]
		)

		let payload = try encodedJSONObject(for: ClientEvent.updateSession(session))
		let sessionJSON = try #require(payload["session"] as? [String: Any])
		let audioJSON = try #require(sessionJSON["audio"] as? [String: Any])
		let inputJSON = try #require(audioJSON["input"] as? [String: Any])
		let transcriptionJSON = try #require(inputJSON["transcription"] as? [String: Any])
		let turnDetectionJSON = try #require(inputJSON["turn_detection"] as? [String: Any])

		#expect(payload["type"] as? String == "session.update")
		#expect(sessionJSON["type"] as? String == "transcription")
		#expect((sessionJSON["include"] as? [String])?.first == "item.input_audio_transcription.logprobs")
		#expect(transcriptionJSON["language"] as? String == "en")
		#expect(transcriptionJSON["model"] as? String == "gpt-4o-transcribe")
		#expect(turnDetectionJSON["type"] as? String == "server_vad")
		#expect(abs((turnDetectionJSON["threshold"] as? Double ?? 0) - 0.6) < 0.0001)
	}

	@Test
	func responseCreateEncodesOutOfBandItemReferenceInput() throws {
		let response = Response.Config(
			conversation: Response.Config.Conversation.none,
			input: [
				.itemReference(id: "item_12345"),
				.message(.init(
					id: "msg_123",
					role: .user,
					content: [.inputText("Summarize the above message in one sentence.")]
				)),
				.message(.init(
					role: .assistant,
					content: [.text("Keep it brief.")]
				)),
				.message(.init(
					role: .user,
					content: [.itemReference(id: "item_nested")]
				)),
			],
			instructions: "Provide a concise answer.",
			metadata: ["response_purpose": "summarization"],
			outputModalities: [.text],
			tools: []
		)

		let payload = try encodedJSONObject(for: ClientEvent.createResponse(using: response))
		let responseJSON = try #require(payload["response"] as? [String: Any])
		let inputJSON = try #require(responseJSON["input"] as? [[String: Any]])
		let referencedItem = try #require(inputJSON.first)
		let inlineMessage = inputJSON[1]
		let inlineContent = try #require(inlineMessage["content"] as? [[String: Any]])
		let assistantMessage = try #require(inputJSON[2]["content"] as? [[String: Any]])
		let nestedReference = try #require(inputJSON[3]["content"] as? [[String: Any]])

		#expect(payload["type"] as? String == "response.create")
		#expect(responseJSON["conversation"] as? String == "none")
		#expect(responseJSON["instructions"] as? String == "Provide a concise answer.")
		#expect(responseJSON["output_modalities"] as? [String] == ["text"])
		#expect(referencedItem["type"] as? String == "item_reference")
		#expect(referencedItem["id"] as? String == "item_12345")
		#expect(inlineMessage["type"] as? String == "message")
		#expect(inlineMessage["role"] as? String == "user")
		#expect(inlineContent.first?["type"] as? String == "input_text")
		#expect(assistantMessage.first?["type"] as? String == "text")
		#expect(assistantMessage.first?["text"] as? String == "Keep it brief.")
		#expect(nestedReference.first?["type"] as? String == "item_reference")
		#expect(nestedReference.first?["id"] as? String == "item_nested")
	}

	@Test
	func responseCancelEncodesResponseIdentifier() throws {
		let payload = try encodedJSONObject(for: ClientEvent.cancelResponse(by: "resp_12345"))
		#expect(payload["type"] as? String == "response.cancel")
		#expect(payload["response_id"] as? String == "resp_12345")
	}

	@Test
	func outputAudioBufferClearEncodesGAEvent() throws {
		let payload = try encodedJSONObject(for: ClientEvent.outputAudioBufferClear())
		#expect(payload["type"] as? String == "output_audio_buffer.clear")
	}

	@Test
	func conversationItemCreateOmitsOptionalIdsAndCallIds() throws {
		let messagePayload = try encodedJSONObject(for: ClientEvent.createConversationItem(.message(.init(
			role: .user,
			content: [.inputText("hello")]
		))))
		let messageJSON = try #require(messagePayload["item"] as? [String: Any])

		#expect(messageJSON["id"] == nil)

		let functionCallPayload = try encodedJSONObject(for: ClientEvent.createConversationItem(.functionCall(.init(
			name: "echo",
			arguments: #"{"value":"hi"}"#
		))))
		let functionCallJSON = try #require(functionCallPayload["item"] as? [String: Any])

		#expect(functionCallJSON["id"] == nil)
		#expect(functionCallJSON["call_id"] == nil)
	}
}

struct GADomainRoundTripTests {
	@Test
	func promptVariablesRoundTripStructuredValues() throws {
		let prompt = Session.Prompt(
			id: "pmpt_123",
			variables: [
				"title": .string("Daily Summary"),
				"body": .inputText("Summarize today's events."),
				"image": .inputImage(.init(detail: .high, imageUrl: "data:image/png;base64,abcd")),
				"file": .inputFile(.init(detail: .high, fileId: "file_123", filename: "brief.txt")),
			]
		)

		let roundTripped = try roundTrip(prompt)
		#expect(roundTripped == prompt)
	}

	@Test
	func voiceRoundTripsForStringAndObjectForms() throws {
		#expect(try roundTrip(Session.Voice.marin) == .marin)
		#expect(try roundTrip(Session.Voice.string("custom-voice-name")) == .string("custom-voice-name"))
		#expect(try roundTrip(Session.Voice.custom(id: "voice_1234")) == .custom(id: "voice_1234"))
	}
}

struct GAServerEventDecodingTests {
	@Test
	func decodesConversationCreatedEvent() throws {
		let event = try decodeServerEvent("""
		{
		  "event_id": "event_1",
		  "type": "conversation.created",
		  "conversation": {
		    "id": "conv_1",
		    "object": "realtime.conversation"
		  }
		}
		""")

		switch event {
			case let .conversationCreated(eventId, conversation):
				#expect(eventId == "event_1")
				#expect(conversation.id == "conv_1")
				#expect(conversation.object == "realtime.conversation")
			default:
				Issue.record("Expected conversation.created")
		}
	}

	@Test
	func decodesTranscriptionSessionUpdatedEvent() throws {
		let event = try decodeServerEvent("""
		{
		  "event_id": "event_session",
		  "type": "session.updated",
		  "session": {
		    "type": "transcription",
		    "audio": {
		      "input": {
		        "transcription": {
		          "model": "gpt-4o-transcribe"
		        }
		      }
		    }
		  }
		}
		""")

		switch event {
			case let .sessionUpdated(eventId, session):
				#expect(eventId == "event_session")
				guard case let .transcription(transcriptionSession) = session else {
					Issue.record("Expected transcription session payload")
					return
				}
				#expect(transcriptionSession.audio?.input?.transcription?.model == .gpt4oTranscribe)
			default:
				Issue.record("Expected session.updated")
		}
	}

	@Test
	func rejectsDeprecatedTranscriptionSessionUpdatedEvent() throws {
		#expect(throws: DecodingError.self) {
			try decodeServerEvent("""
			{
			  "event_id": "event_session",
			  "type": "transcription_session.updated",
			  "session": {
			    "type": "transcription"
			  }
			}
			""")
		}
	}

	@Test
	func decodesConversationItemLifecycleEventsWithGAContentTypes() throws {
		let created = try decodeServerEvent("""
		{
		  "event_id": "event_created",
		  "type": "conversation.item.created",
		  "previous_item_id": "msg_0",
		  "item": {
		    "id": "msg_text",
		    "object": "realtime.item",
		    "type": "message",
		    "role": "assistant",
		    "status": "completed",
		    "content": [
		      {
		        "type": "output_text",
		        "text": "hello"
		      }
		    ]
		  }
		}
		""")

		switch created {
			case let .conversationItemCreated(eventId, item, previousItemId):
				#expect(eventId == "event_created")
				#expect(previousItemId == "msg_0")

				guard case let .message(message) = item,
				      case let .outputText(text) = message.content.first
				else {
					Issue.record("Expected assistant output_text item")
					return
				}

				#expect(text == "hello")
			default:
				Issue.record("Expected conversation.item.created")
		}

		let added = try decodeServerEvent("""
		{
		  "event_id": "event_added",
		  "type": "conversation.item.added",
		  "item": {
		    "id": "msg_audio",
		    "object": "realtime.item",
		    "type": "message",
		    "role": "assistant",
		    "status": "in_progress",
		    "content": [
		      {
		        "type": "output_audio",
		        "transcript": "hi"
		      }
		    ]
		  }
		}
		""")

		switch added {
			case let .conversationItemAdded(eventId, item, _):
				#expect(eventId == "event_added")

				guard case let .message(message) = item,
				      case let .outputAudio(audio) = message.content.first
				else {
					Issue.record("Expected assistant output_audio item")
					return
				}

				#expect(audio.transcript == "hi")
			default:
				Issue.record("Expected conversation.item.added")
		}

		let done = try decodeServerEvent("""
		{
		  "event_id": "event_done",
		  "type": "conversation.item.done",
		  "item": {
		    "id": "msg_done",
		    "object": "realtime.item",
		    "type": "message",
		    "role": "assistant",
		    "status": "completed",
		    "content": [
		      {
		        "type": "output_text",
		        "text": "done"
		      }
		    ]
		  }
		}
		""")

		switch done {
			case let .conversationItemDone(eventId, item, _):
				#expect(eventId == "event_done")

				guard case let .message(message) = item,
				      case let .outputText(text) = message.content.first
				else {
					Issue.record("Expected final assistant output_text item")
					return
				}

				#expect(text == "done")
			default:
				Issue.record("Expected conversation.item.done")
		}
	}

	@Test
	func decodesMCPCallItemAndDTMFEvent() throws {
		let event = try decodeServerEvent("""
		{
		  "event_id": "event_mcp",
		  "type": "conversation.item.added",
		  "item": {
		    "id": "mcp_1",
		    "type": "mcp_call",
		    "server_label": "calendar",
		    "name": "lookup",
		    "arguments": "{\\"day\\":\\"monday\\"}",
		    "output": "available"
		  }
		}
		""")

		switch event {
			case let .conversationItemAdded(_, item, _):
				guard case let .mcpCall(call) = item else {
					Issue.record("Expected mcp_call item")
					return
				}

				#expect(call.serverLabel == "calendar")
				#expect(call.name == "lookup")
				#expect(call.output == "available")
			default:
				Issue.record("Expected conversation.item.added")
		}

		let dtmf = try decodeServerEvent("""
		{
		  "event_id": "event_dtmf",
		  "type": "input_audio_buffer.dtmf_event_received",
		  "event": "#",
		  "received_at": 1731111111
		}
		""")

		switch dtmf {
			case let .inputAudioBufferDTMFEventReceived(key, receivedAt, eventId):
				#expect(key == "#")
				#expect(receivedAt == 1_731_111_111)
				#expect(eventId == "event_dtmf")
			default:
				Issue.record("Expected input_audio_buffer.dtmf_event_received")
		}
	}

	@Test
	func decodesTranscriptionCompletedWithTokenUsage() throws {
		let event = try decodeServerEvent("""
		{
		  "event_id": "event_tokens",
		  "type": "conversation.item.input_audio_transcription.completed",
		  "item_id": "item_1",
		  "content_index": 0,
		  "transcript": "hello",
		  "usage": {
		    "type": "tokens",
		    "input_tokens": 12,
		    "output_tokens": 4,
		    "total_tokens": 16
		  }
		}
		""")

		switch event {
			case let .conversationItemInputAudioTranscriptionCompleted(_, itemId, contentIndex, transcript, _, usage):
				#expect(itemId == "item_1")
				#expect(contentIndex == 0)
				#expect(transcript == "hello")

				guard case let .tokens(tokenUsage) = usage else {
					Issue.record("Expected token usage")
					return
				}

				#expect(tokenUsage.totalTokens == 16)
			default:
				Issue.record("Expected transcription completed event")
		}
	}

	@Test
	func decodesTranscriptionCompletedWithDurationUsage() throws {
		let event = try decodeServerEvent("""
		{
		  "event_id": "event_duration",
		  "type": "conversation.item.input_audio_transcription.completed",
		  "item_id": "item_2",
		  "content_index": 0,
		  "transcript": "hello",
		  "usage": {
		    "type": "duration",
		    "seconds": 1.75
		  }
		}
		""")

		switch event {
			case let .conversationItemInputAudioTranscriptionCompleted(_, _, _, _, _, usage):
				guard case let .duration(durationUsage) = usage else {
					Issue.record("Expected duration usage")
					return
				}

				#expect(abs(durationUsage.seconds - 1.75) < 0.0001)
			default:
				Issue.record("Expected transcription completed event")
		}
	}

	@Test
	func decodesResponseOutputTextEvents() throws {
		let delta = try decodeServerEvent("""
		{
		  "event_id": "event_delta",
		  "type": "response.output_text.delta",
		  "response_id": "resp_1",
		  "item_id": "msg_1",
		  "output_index": 0,
		  "content_index": 0,
		  "delta": "hel"
		}
		""")

		switch delta {
			case let .responseOutputTextDelta(eventId, responseId, itemId, outputIndex, contentIndex, textDelta):
				#expect(eventId == "event_delta")
				#expect(responseId == "resp_1")
				#expect(itemId == "msg_1")
				#expect(outputIndex == 0)
				#expect(contentIndex == 0)
				#expect(textDelta == "hel")
			default:
				Issue.record("Expected response.output_text.delta")
		}

		let done = try decodeServerEvent("""
		{
		  "event_id": "event_done",
		  "type": "response.output_text.done",
		  "response_id": "resp_1",
		  "item_id": "msg_1",
		  "output_index": 0,
		  "content_index": 0,
		  "text": "hello"
		}
		""")

		switch done {
			case let .responseOutputTextDone(_, _, _, _, _, text):
				#expect(text == "hello")
			default:
				Issue.record("Expected response.output_text.done")
		}
	}

	@Test
	func decodesResponseContentPartEventsWithCanonicalTypes() throws {
		let canonical = try decodeServerEvent("""
		{
		  "event_id": "event_part_canonical",
		  "type": "response.content_part.added",
		  "response_id": "resp_1",
		  "item_id": "msg_1",
		  "output_index": 0,
		  "content_index": 0,
		  "part": {
		    "type": "output_text",
		    "text": "hello"
		  }
		}
		""")

		switch canonical {
			case let .responseContentPartAdded(_, _, _, _, _, part):
				guard case let .outputText(text) = part else {
					Issue.record("Expected canonical output_text content part")
					return
				}
				#expect(text == "hello")
			default:
				Issue.record("Expected response.content_part.added")
		}
	}

	@Test
	func rejectsLegacyResponseContentPartAliasTypes() throws {
		#expect(throws: DecodingError.self) {
			_ = try decodeServerEvent("""
		{
		  "event_id": "event_part_alias",
		  "type": "response.content_part.done",
		  "response_id": "resp_1",
		  "item_id": "msg_1",
		  "output_index": 0,
		  "content_index": 0,
		  "part": {
		    "type": "text",
		    "text": "hello"
		  }
		}
		""")
		}
	}

	@Test
	func decodesResponseOutputAudioEvents() throws {
		let delta = try decodeServerEvent("""
		{
		  "event_id": "event_audio_delta",
		  "type": "response.output_audio.delta",
		  "response_id": "resp_1",
		  "item_id": "msg_1",
		  "output_index": 0,
		  "content_index": 0,
		  "delta": "AQI="
		}
		""")

		switch delta {
			case let .responseOutputAudioDelta(_, _, _, _, _, audioDelta):
				#expect(audioDelta.data == Data([0x01, 0x02]))
			default:
				Issue.record("Expected response.output_audio.delta")
		}

		let done = try decodeServerEvent("""
		{
		  "event_id": "event_audio_done",
		  "type": "response.output_audio.done",
		  "response_id": "resp_1",
		  "item_id": "msg_1",
		  "output_index": 0,
		  "content_index": 0
		}
		""")

		switch done {
			case .responseOutputAudioDone:
				break
			default:
				Issue.record("Expected response.output_audio.done")
		}
	}

	@Test
	func decodesResponseOutputAudioTranscriptEvents() throws {
		let delta = try decodeServerEvent("""
		{
		  "event_id": "event_transcript_delta",
		  "type": "response.output_audio_transcript.delta",
		  "response_id": "resp_1",
		  "item_id": "msg_1",
		  "output_index": 0,
		  "content_index": 0,
		  "delta": "hel"
		}
		""")

		switch delta {
			case let .responseOutputAudioTranscriptDelta(_, _, _, _, _, transcriptDelta):
				#expect(transcriptDelta == "hel")
			default:
				Issue.record("Expected response.output_audio_transcript.delta")
		}

		let done = try decodeServerEvent("""
		{
		  "event_id": "event_transcript_done",
		  "type": "response.output_audio_transcript.done",
		  "response_id": "resp_1",
		  "item_id": "msg_1",
		  "output_index": 0,
		  "content_index": 0,
		  "transcript": "hello"
		}
		""")

		switch done {
			case let .responseOutputAudioTranscriptDone(_, _, _, _, _, transcript):
				#expect(transcript == "hello")
			default:
				Issue.record("Expected response.output_audio_transcript.done")
		}
	}

	@Test
	func decodesRateLimitsUpdatedWithPartialEntries() throws {
		let event = try decodeServerEvent("""
		{
		  "event_id": "event_rate_limits",
		  "type": "rate_limits.updated",
		  "rate_limits": [
		    {
		      "name": "requests",
		      "remaining": 10
		    },
		    {
		      "limit": 1000,
		      "reset_seconds": 2.5
		    }
		  ]
		}
		""")

		switch event {
			case let .rateLimitsUpdated(eventId, rateLimits):
				#expect(eventId == "event_rate_limits")
				#expect(rateLimits.count == 2)
				#expect(rateLimits[0].name == "requests")
				#expect(rateLimits[0].remaining == 10)
				#expect(rateLimits[0].limit == nil)
				#expect(rateLimits[1].limit == 1000)
				#expect(rateLimits[1].name == nil)
			default:
				Issue.record("Expected rate_limits.updated")
		}
	}

	@Test
	func responseRoundTripsObjectAndStatusDetails() throws {
		let response = try decodeValue(Response.self, from: """
		{
		  "id": "resp_123",
		  "object": "realtime.response",
		  "status": "in_progress",
		  "status_details": {
		    "type": "incomplete",
		    "reason": "max_output_tokens"
		  },
		  "output": []
		}
		""")

		#expect(response.object == "realtime.response")
		#expect(response.status == .inProgress)

		guard case let .object(details)? = response.statusDetails else {
			Issue.record("Expected status_details object")
			return
		}

		#expect(details["type"] == .string("incomplete"))
		#expect(details["reason"] == .string("max_output_tokens"))
	}
}

struct GAClientSecretHelperTests {
	@Test
	func createClientSecretPostsUnifiedRequestAndDecodesResponse() async throws {
		let requestSession = Session.realtime(.init(
			audio: .init(input: .init(
				noiseReduction: .nearField,
				transcription: .init(model: .gpt4oTranscribe),
				turnDetection: .semanticVAD()
			)),
			instructions: "Be helpful.",
			model: .gptRealtime,
			outputModalities: [.audio]
		))
		let expiresAfter = RealtimeClientSecret.ExpiresAfter(seconds: 600)
		let urlSession = makeClientSecretURLSession()

		ClientSecretURLProtocol.requestHandler = { request in
			#expect(request.url?.absoluteString == "https://api.openai.com/v1/realtime/client_secrets")
			#expect(request.httpMethod == "POST")
			#expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
			#expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

			let body = try #require(requestBodyData(for: request))
			let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
			let expiresAfterJSON = try #require(json["expires_after"] as? [String: Any])
			let sessionJSON = try #require(json["session"] as? [String: Any])
			let audioJSON = try #require(sessionJSON["audio"] as? [String: Any])
			let inputJSON = try #require(audioJSON["input"] as? [String: Any])
			let noiseReductionJSON = try #require(inputJSON["noise_reduction"] as? [String: Any])
			let transcriptionJSON = try #require(inputJSON["transcription"] as? [String: Any])
			let turnDetectionJSON = try #require(inputJSON["turn_detection"] as? [String: Any])

			#expect(expiresAfterJSON["anchor"] as? String == "created_at")
			#expect(expiresAfterJSON["seconds"] as? Int == 600)
			#expect(sessionJSON["type"] as? String == "realtime")
			#expect(sessionJSON["model"] as? String == "gpt-realtime")
			#expect(sessionJSON["instructions"] as? String == "Be helpful.")
			#expect(noiseReductionJSON["type"] as? String == "near_field")
			#expect(transcriptionJSON["model"] as? String == "gpt-4o-transcribe")
			#expect(turnDetectionJSON["type"] as? String == "semantic_vad")

			let response = HTTPURLResponse(
				url: try #require(request.url),
				statusCode: 200,
				httpVersion: nil,
				headerFields: nil
			)!

			let bodyJSON = """
			{
			  "value": "ek_test_123",
			  "expires_at": 1756310470,
			  "session": {
			    "type": "realtime",
			    "object": "realtime.session",
			    "id": "sess_123",
			    "model": "gpt-realtime",
			    "output_modalities": ["audio"],
			    "instructions": "Be helpful."
			  }
			}
			"""

			return (response, Data(bodyJSON.utf8))
		}

		defer { ClientSecretURLProtocol.requestHandler = nil }

		let clientSecret = try await RealtimeAPI.createClientSecret(
			apiKey: "sk-test",
			session: requestSession,
			expiresAfter: expiresAfter,
			using: urlSession
		)

		#expect(clientSecret.value == "ek_test_123")
		#expect(clientSecret.expiresAt == 1_756_310_470)

		guard case let .realtime(session) = clientSecret.session else {
			Issue.record("Expected realtime client secret session")
			return
		}

		#expect(session.id == "sess_123")
		#expect(session.object == "realtime.session")
		#expect(session.model == Model.gptRealtime)
		#expect(session.instructions == "Be helpful.")
	}
}

@MainActor
struct ConversationGATests {
	@Test
	func conversationItemsWithoutWireIdsDoNotCollide() async throws {
		let recorder = TransportRecorder()
		let conversation = Conversation(transport: recorder.transport)

		try await conversation.receive(serverEvent: .conversationItemAdded(
			eventId: "event_added_1",
			item: .message(.init(role: .assistant, status: .inProgress, content: [.outputText("one")])),
			previousItemId: nil
		))

		try await conversation.receive(serverEvent: .conversationItemAdded(
			eventId: "event_added_2",
			item: .message(.init(role: .assistant, status: .inProgress, content: [.outputText("two")])),
			previousItemId: nil
		))

		#expect(conversation.entries.count == 2)
	}

	@Test
	func conversationItemAddedAndDoneUpsertWithoutDuplicates() async throws {
		let recorder = TransportRecorder()
		let conversation = Conversation(transport: recorder.transport)

		try await conversation.receive(serverEvent: .conversationItemAdded(
			eventId: "event_added",
			item: .message(.init(id: "msg_1", role: .assistant, status: .inProgress, content: [.outputText("hel")])),
			previousItemId: nil
		))

		try await conversation.receive(serverEvent: .conversationItemDone(
			eventId: "event_done",
			item: .message(.init(id: "msg_1", role: .assistant, status: .completed, content: [.outputText("hello")])),
			previousItemId: nil
		))

		#expect(conversation.entries.count == 1)

		guard case let .message(message) = conversation.entries[0],
		      case let .outputText(text) = message.content.first
		else {
			Issue.record("Expected a single assistant message")
			return
		}

		#expect(message.status == .completed)
		#expect(text == "hello")
	}

	@Test
	func conversationAccumulatesOutputTextDeltas() async throws {
		let recorder = TransportRecorder()
		let conversation = Conversation(transport: recorder.transport)

		try await conversation.receive(serverEvent: .conversationItemAdded(
			eventId: "event_added",
			item: .message(.init(id: "msg_1", role: .assistant, status: .inProgress, content: [])),
			previousItemId: nil
		))
		try await conversation.receive(serverEvent: .responseContentPartAdded(
			eventId: "event_part",
			responseId: "resp_1",
			itemId: "msg_1",
			outputIndex: 0,
			contentIndex: 0,
			part: .outputText("")
		))
		try await conversation.receive(serverEvent: .responseOutputTextDelta(
			eventId: "event_delta_1",
			responseId: "resp_1",
			itemId: "msg_1",
			outputIndex: 0,
			contentIndex: 0,
			delta: "Hel"
		))
		try await conversation.receive(serverEvent: .responseOutputTextDelta(
			eventId: "event_delta_2",
			responseId: "resp_1",
			itemId: "msg_1",
			outputIndex: 0,
			contentIndex: 0,
			delta: "lo"
		))
		try await conversation.receive(serverEvent: .responseOutputTextDone(
			eventId: "event_done",
			responseId: "resp_1",
			itemId: "msg_1",
			outputIndex: 0,
			contentIndex: 0,
			text: "Hello"
		))

		guard case let .message(message) = conversation.entries[0],
		      case let .outputText(text) = message.content.first
		else {
			Issue.record("Expected assistant output_text content")
			return
		}

		#expect(text == "Hello")
	}

	@Test
	func conversationAccumulatesOutputAudioTranscriptAndAudio() async throws {
		let recorder = TransportRecorder()
		let conversation = Conversation(transport: recorder.transport)

		try await conversation.receive(serverEvent: .conversationItemAdded(
			eventId: "event_added",
			item: .message(.init(id: "msg_1", role: .assistant, status: .inProgress, content: [])),
			previousItemId: nil
		))
		try await conversation.receive(serverEvent: .responseContentPartAdded(
			eventId: "event_part",
			responseId: "resp_1",
			itemId: "msg_1",
			outputIndex: 0,
			contentIndex: 0,
			part: .outputAudio(.init(audio: AudioData?.none, transcript: ""))
		))
		try await conversation.receive(serverEvent: .responseOutputAudioTranscriptDelta(
			eventId: "event_transcript_delta_1",
			responseId: "resp_1",
			itemId: "msg_1",
			outputIndex: 0,
			contentIndex: 0,
			delta: "Hel"
		))
		try await conversation.receive(serverEvent: .responseOutputAudioTranscriptDelta(
			eventId: "event_transcript_delta_2",
			responseId: "resp_1",
			itemId: "msg_1",
			outputIndex: 0,
			contentIndex: 0,
			delta: "lo"
		))
		try await conversation.receive(serverEvent: .responseOutputAudioDelta(
			eventId: "event_audio_delta_1",
			responseId: "resp_1",
			itemId: "msg_1",
			outputIndex: 0,
			contentIndex: 0,
			delta: .init(data: Data([0x01]))
		))
		try await conversation.receive(serverEvent: .responseOutputAudioDelta(
			eventId: "event_audio_delta_2",
			responseId: "resp_1",
			itemId: "msg_1",
			outputIndex: 0,
			contentIndex: 0,
			delta: .init(data: Data([0x02]))
		))
		try await conversation.receive(serverEvent: .responseOutputAudioTranscriptDone(
			eventId: "event_transcript_done",
			responseId: "resp_1",
			itemId: "msg_1",
			outputIndex: 0,
			contentIndex: 0,
			transcript: "Hello"
		))

		guard case let .message(message) = conversation.entries[0],
		      case let .outputAudio(audio) = message.content.first
		else {
			Issue.record("Expected assistant output_audio content")
			return
		}

		#expect(audio.transcript == "Hello")
		#expect(audio.audio?.data == Data([0x01, 0x02]))
	}

	@Test
	func functionCallCompletionDispatchesToolResultAndFollowUpResponse() async throws {
		let recorder = TransportRecorder()
		let registry = ToolRegistry([EchoTool()])
		let conversation = Conversation(transport: recorder.transport, toolRegistry: registry)

		try await conversation.receive(serverEvent: .conversationItemAdded(
			eventId: "event_added",
			item: .functionCall(.init(
				id: "fc_1",
				status: .inProgress,
				callId: "call_1",
				name: "echo",
				arguments: ""
			)),
			previousItemId: nil
		))

		try await conversation.receive(serverEvent: .responseFunctionCallArgumentsDone(
			eventId: "event_done",
			responseId: "resp_1",
			itemId: "fc_1",
			outputIndex: 0,
			callId: "call_1",
			arguments: #"{"value":"hello"}"#
		))

		#expect(recorder.sentEvents.count == 2)

		guard case let .createConversationItem(_, _, item) = recorder.sentEvents[0],
		      case let .functionCallOutput(output) = item
		else {
			Issue.record("Expected function_call_output event")
			return
		}

		#expect(output.callId == "call_1")
		#expect(output.output == "HELLO")

		guard case .createResponse = recorder.sentEvents[1] else {
			Issue.record("Expected response.create event")
			return
		}
	}

	@Test
	func generableArgumentsSynthesizeSchemaAndTypedOutputEncoding() async throws {
		let tool = FindContactsTool()
		let expectedSchema: JSONSchema = .object(
			properties: [
				"count": .integer(minimum: 1, maximum: 10, description: "The number of contacts to get"),
				"query": .string(description: "Optional search text"),
			],
			required: ["count"]
		)

		#expect(tool.parametersSchema == expectedSchema)

		let registry = ToolRegistry([tool])
		let output = try await registry.handle(
			name: "findContacts",
			callId: "call_1",
			arguments: #"{"count":2,"query":"friends"}"#
		)

		#expect(output.output == #"["Ada Lovelace","Grace Hopper"]"#)
	}

	@Test
	func generableSupportsFullGuideConstraintSurface() {
		let tool = SearchDirectoryTool()
		let expectedSchema: JSONSchema = .object(
			properties: [
				"prefix": .string(pattern: "^[A-Za-z]+$", minLength: 2, maxLength: 24, description: "Name prefix to search"),
				"email": .string(format: .email, description: "Optional contact email"),
				"score": .number(minimum: 0.25, maximum: 0.75, description: "Minimum match score"),
				"tags": .array(of: .string(), minItems: 1, maxItems: 3, description: "Tags to include"),
				"aliases": .array(of: .string(), minItems: 1, maxItems: 5, description: "Aliases to include"),
				"kind": .enum(cases: ["family", "friend"]),
				"filters": .object(
					properties: [
						"city": .string(description: "City filter"),
					],
					required: ["city"]
				),
			],
			required: ["prefix", "score", "tags", "kind"],
			description: "Search directory contacts"
		)

		#expect(tool.parametersSchema == expectedSchema)
	}

	@Test
	func describedPreservesNumericBounds() {
		#expect(
			JSONSchema.number(minimum: 0.25, maximum: 0.75)
				.described("Score") == .number(minimum: 0.25, maximum: 0.75, description: "Score")
		)
		#expect(
			JSONSchema.integer(minimum: 1, maximum: 10)
				.described("Count") == .integer(minimum: 1, maximum: 10, description: "Count")
		)
	}

	@Test
	func streamedEventsInvalidateObservationTracking() async throws {
		let recorder = TransportRecorder()
		let conversation = Conversation(transport: recorder.transport)
		let (changes, continuation) = AsyncStream.makeStream(of: Void.self)

		withObservationTracking {
			_ = conversation.isUserSpeaking
		} onChange: {
			continuation.yield()
			continuation.finish()
		}

		recorder.yield(.inputAudioBufferSpeechStarted(
			eventId: "event_speech_started",
			itemId: "item_1",
			audioStartMs: 0
		))

		var iterator = changes.makeAsyncIterator()
		let observedChange: Void? = await iterator.next()

		#expect(observedChange != nil)
		#expect(conversation.isUserSpeaking)
	}

	@Test
	func streamedStatusUpdatesInvalidateObservationTracking() async throws {
		let recorder = TransportRecorder(status: .disconnected)
		let conversation = Conversation(transport: recorder.transport)
		let (changes, continuation) = AsyncStream.makeStream(of: Void.self)

		withObservationTracking {
			_ = conversation.status
		} onChange: {
			continuation.yield()
			continuation.finish()
		}

		recorder.yield(status: .connected)

		var iterator = changes.makeAsyncIterator()
		let observedChange: Void? = await iterator.next()

		#expect(observedChange != nil)
		#expect(conversation.status == .connected)
	}

	@Test
	func updatesStreamEmitsInitialAndChangedSnapshots() async throws {
		let recorder = TransportRecorder(status: .disconnected)
		let conversation = Conversation(transport: recorder.transport)
		var iterator = conversation.updates.makeAsyncIterator()

		let initial = await iterator.next()
		#expect(initial?.status == .disconnected)
		#expect(initial?.isUserSpeaking == false)

		recorder.yield(status: .connected)
		try await conversation.receive(serverEvent: .inputAudioBufferSpeechStarted(
			eventId: "event_speech_started",
			itemId: "item_1",
			audioStartMs: 0
		))

		var observedConnected = false
		var observedSpeaking = false

		for _ in 0..<4 {
			guard let snapshot = await iterator.next() else { break }
			observedConnected = observedConnected || snapshot.status == .connected
			observedSpeaking = observedSpeaking || snapshot.isUserSpeaking

			if observedConnected, observedSpeaking {
				break
			}
		}

		#expect(observedConnected)
		#expect(observedSpeaking)
	}
}

private func encodedJSONObject(for event: ClientEvent) throws -> [String: Any] {
	let encoder = JSONEncoder()
	encoder.keyEncodingStrategy = .convertToSnakeCase
	let data = try encoder.encode(event)
	return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func decodeServerEvent(_ json: String) throws -> ServerEvent {
	let decoder = JSONDecoder()
	decoder.keyDecodingStrategy = .convertFromSnakeCase
	return try decoder.decode(ServerEvent.self, from: Data(json.utf8))
}

private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
	let encoder = JSONEncoder()
	encoder.keyEncodingStrategy = .convertToSnakeCase

	let decoder = JSONDecoder()
	decoder.keyDecodingStrategy = .convertFromSnakeCase

	return try decoder.decode(T.self, from: encoder.encode(value))
}

private func makeClientSecretURLSession() -> URLSession {
	let configuration = URLSessionConfiguration.ephemeral
	configuration.protocolClasses = [ClientSecretURLProtocol.self]
	return URLSession(configuration: configuration)
}

private func requestBodyData(for request: URLRequest) -> Data? {
	if let body = request.httpBody {
		return body
	}

	guard let stream = request.httpBodyStream else {
		return nil
	}

	stream.open()
	defer { stream.close() }

	var data = Data()
	let bufferSize = 1024
	let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
	defer { buffer.deallocate() }

	while stream.hasBytesAvailable {
		let bytesRead = stream.read(buffer, maxLength: bufferSize)
		if bytesRead < 0 {
			return nil
		}
		if bytesRead == 0 {
			break
		}
		data.append(buffer, count: bytesRead)
	}

	return data
}

private func decodeValue<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
	let decoder = JSONDecoder()
	decoder.keyDecodingStrategy = .convertFromSnakeCase
	return try decoder.decode(T.self, from: Data(json.utf8))
}

private final class TransportRecorder: @unchecked Sendable {
	private final class Storage: @unchecked Sendable {
		var sentEvents: [ClientEvent] = []
	}

	private let storage: Storage
	private let continuation: AsyncThrowingStream<ServerEvent, Error>.Continuation
	private let statusContinuation: AsyncStream<RealtimeAPI.Status>.Continuation
	var sentEvents: [ClientEvent] {
		storage.sentEvents
	}

	let transport: Conversation.Transport

	init(status: RealtimeAPI.Status = .connected) {
		let (events, continuation) = AsyncThrowingStream.makeStream(of: ServerEvent.self)
		let (statusUpdates, statusContinuation) = AsyncStream.makeStream(of: RealtimeAPI.Status.self)
		let storage = Storage()

		self.storage = storage
		self.continuation = continuation
		self.statusContinuation = statusContinuation

		transport = Conversation.Transport(
			events: events,
			statusUpdates: statusUpdates,
			status: { status },
			connect: { _ in },
			send: { event in
				storage.sentEvents.append(event)
			},
			disconnect: {},
			setMuted: { _ in }
		)
	}

	func yield(_ event: ServerEvent) {
		continuation.yield(event)
	}

	func yield(status: RealtimeAPI.Status) {
		statusContinuation.yield(status)
	}
}

private struct EchoTool: Tool {
	@Generable
	struct Arguments: Codable, Sendable {
		@Guide(description: "The value to echo.")
		let value: String
	}

	let name = "echo"
	let description = "Echoes the provided value."

	func call(arguments: Arguments) async throws -> String {
		arguments.value.uppercased()
	}
}

private struct FindContactsTool: Tool {
	@Generable
	struct Arguments: Codable, Sendable {
		@Guide(description: "The number of contacts to get", .range(1...10))
		let count: Int

		@Guide(description: "Optional search text")
		let query: String?
	}

	let name = "findContacts"
	let description = "Find a specific number of contacts"

	func call(arguments _: Arguments) async throws -> [String] {
		["Ada Lovelace", "Grace Hopper"]
	}
}

private struct SearchDirectoryTool: Tool {
	@Generable(description: "Search directory contacts")
	struct Arguments: Codable, Sendable {
		@Guide(description: "Name prefix to search", .pattern("^[A-Za-z]+$"), .length(2...24))
		let prefix: String

		@Guide(description: "Optional contact email", .format(.email))
		let email: String?

		@Guide(description: "Minimum match score", .minimum(0.25), .maximum(0.75))
		let score: Double

		@Guide(description: "Tags to include", .count(1...3))
		let tags: [String]

		@Guide(description: "Aliases to include", .minimumCount(1), .maximumCount(5))
		let aliases: [String]?

		let kind: ContactKind
		let filters: Filters?
	}

	@Generable
	enum ContactKind: String, Codable, Sendable {
		case family
		case friend
	}

	@Generable
	struct Filters: Codable, Sendable {
		@Guide(description: "City filter")
		let city: String
	}

	let name = "searchDirectory"
	let description = "Searches directory contacts."

	func call(arguments _: Arguments) async throws -> [String] {
		["Ada Lovelace"]
	}
}

private final class ClientSecretURLProtocol: URLProtocol, @unchecked Sendable {
	nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

	override class func canInit(with request: URLRequest) -> Bool {
		true
	}

	override class func canonicalRequest(for request: URLRequest) -> URLRequest {
		request
	}

	override func startLoading() {
		guard let handler = Self.requestHandler else {
			client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
			return
		}

		do {
			let (response, data) = try handler(request)
			client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
			client?.urlProtocol(self, didLoad: data)
			client?.urlProtocolDidFinishLoading(self)
		} catch {
			client?.urlProtocol(self, didFailWithError: error)
		}
	}

	override func stopLoading() {}
}
