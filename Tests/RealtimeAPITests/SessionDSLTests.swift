import Foundation
import Testing
@testable import Core

struct SessionDSLTests {
	@Test
	func supportsFoundationStyleInstructionsAndPromptValues() throws {
		let system = Instructions {
			"You are Cosmos speaking through smart glasses."
			Prompt {
				"Keep responses concise."
				"Be natural."
			}
			SafetyRail("Never mention internal implementation details.")
		}

		let transcriptionPrompt = Prompt {
			"Street names"
			"Navigation terms"
			DirectoryContext("Colleague names")
		}

		let session = try SessionConfiguration(.gptRealtime) {
			system

			Response(.audio) {
				MaxTokens(400)
			}

			AudioInput(.pcm) {
				Transcription(.gpt4oTranscribe) {
					Language(.english)
					transcriptionPrompt
				}
			}
		}

		let realtime = try #require(realtimeSession(from: session))

		#expect(realtime.instructions == """
		You are Cosmos speaking through smart glasses.
		Keep responses concise.
		Be natural.
		Never mention internal implementation details.
		""")
		#expect(realtime.audio?.input?.transcription?.prompt == """
		Street names
		Navigation terms
		Colleague names
		""")
	}

	@Test
	func encodesInlineDSLToRealtimeSessionCreateJSON() throws {
		let session = try SessionConfiguration(.gptRealtime) {
			Instructions {
				"You are Cosmos speaking through smart glasses."
				"Keep responses concise and conversational."
			}

			Response(.audio) {
				MaxTokens(400)
				Truncation(.auto)
			}
			.include(.field(.inputAudioTranscriptionLogProbs))

			Tracing {
				Workflow("cosmos")
				Group("workday-session")
				Metadata([
					"surface": "glasses",
					"environment": "prod",
				])
			}

			AudioInput(.pcm) {
				NoiseReduction(.nearField)

				Transcription(.gpt4oTranscribe) {
					Language(.english)
					Prompt("Street names, navigation terms")
				}

				TurnDetection {
					Semantic(interrupts: false, responds: true) {
						Eagerness(.auto)
					}
				}
			}

			AudioOutput(.pcm) {
				Voice(.marin).speed(1.05)
			}

			Tools(choice: .auto) {
				SearchTool()
				DropboxConnector()
					.deferred()
					.approval(.required)
			}
		}

		#expect(try encodedSessionJSON(session) == canonicalJSON("""
		{
		  "audio": {
		    "input": {
		      "format": {
		        "rate": 24000,
		        "type": "audio/pcm"
		      },
		      "noise_reduction": {
		        "type": "near_field"
		      },
		      "transcription": {
		        "language": "en",
		        "model": "gpt-4o-transcribe",
		        "prompt": "Street names, navigation terms"
		      },
		      "turn_detection": {
		        "create_response": true,
		        "eagerness": "auto",
		        "interrupt_response": false,
		        "type": "semantic_vad"
		      }
		    },
		    "output": {
		      "format": {
		        "rate": 24000,
		        "type": "audio/pcm"
		      },
		      "speed": 1.05,
		      "voice": "marin"
		    }
		  },
		  "include": [
		    "item.input_audio_transcription.logprobs"
		  ],
		  "instructions": "You are Cosmos speaking through smart glasses.\\nKeep responses concise and conversational.",
		  "max_output_tokens": 400,
		  "model": "gpt-realtime",
		  "output_modalities": [
		    "audio"
		  ],
		  "tool_choice": "auto",
		  "tools": [
		    {
		      "description": "Search the web.",
		      "name": "search",
		      "parameters": {
		        "additional_properties": false,
		        "properties": {
		          "query": {
		            "description": "Search query",
		            "type": "string"
		          }
		        },
		        "required": [
		          "query"
		        ],
		        "type": "object"
		      },
		      "type": "function"
		    },
		    {
		      "connector_id": "connector_dropbox",
		      "defer_loading": true,
		      "require_approval": "always",
		      "server_label": "dropbox_connector",
		      "type": "mcp"
		    }
		  ],
		  "tracing": {
		    "group_id": "workday-session",
		    "metadata": {
		      "environment": "prod",
		      "surface": "glasses"
		    },
		    "workflow_name": "cosmos"
		  },
		  "truncation": "auto",
		  "type": "realtime"
		}
		"""))
	}

	@Test
	func encodesHostedInstructionsDSLToPromptJSON() throws {
		let session = try SessionConfiguration(.gptRealtime) {
			Instructions("cosmos_glasses", version: 2) {
				Variables([
					"location": "office",
					"mode": "focused",
					"profile": .inputText("work"),
					"badge": .inputFile(.init(fileId: "file_123", filename: "badge.txt")),
				])
			}

			Response(.text) {
				MaxTokens(.max)
				Truncation(.disabled)
			}

			Tools(choice: .required(CalendarTool.self)) {
				SearchTool()
				CalendarTool()
			}
		}

		#expect(try encodedSessionJSON(session) == canonicalJSON("""
		{
		  "max_output_tokens": "inf",
		  "model": "gpt-realtime",
		  "output_modalities": [
		    "text"
		  ],
		  "prompt": {
		    "id": "cosmos_glasses",
		    "variables": {
		      "badge": {
		        "file_id": "file_123",
		        "filename": "badge.txt",
		        "type": "input_file"
		      },
		      "location": "office",
		      "mode": "focused",
		      "profile": {
		        "text": "work",
		        "type": "input_text"
		      }
		    },
		    "version": "2"
		  },
		  "tool_choice": {
		    "name": "calendar",
		    "type": "function"
		  },
		  "tools": [
		    {
		      "description": "Search the web.",
		      "name": "search",
		      "parameters": {
		        "additional_properties": false,
		        "properties": {
		          "query": {
		            "description": "Search query",
		            "type": "string"
		          }
		        },
		        "required": [
		          "query"
		        ],
		        "type": "object"
		      },
		      "type": "function"
		    },
		    {
		      "description": "Manage calendar events.",
		      "name": "calendar",
		      "parameters": {
		        "additional_properties": false,
		        "properties": {
		          "action": {
		            "description": "Calendar action",
		            "type": "string"
		          }
		        },
		        "required": [
		          "action"
		        ],
		        "type": "object"
		      },
		      "type": "function"
		    }
		  ],
		  "truncation": "disabled",
		  "type": "realtime"
		}
		"""))
	}

	@Test
	func buildsMinimalRealtimeSession() throws {
		let session = try SessionConfiguration(.gptRealtime) {
			Instructions {
				"You are Cosmos speaking through smart glasses."
				"Keep responses concise and conversational."
			}

			Response(.audio) {
				MaxTokens(400)
				Truncation(.auto)
			}

			AudioInput(.pcm) {
				NoiseReduction(.nearField)
			}

			AudioOutput(.pcm) {
				Voice(.marin)
			}

			Tools(choice: .none) {
				SearchTool()
				CalendarTool()
			}
		}

		let realtime = try #require(realtimeSession(from: session))
		let tools = try #require(realtime.tools)

		#expect(realtime.model == .gptRealtime)
		#expect(realtime.instructions == """
		You are Cosmos speaking through smart glasses.
		Keep responses concise and conversational.
		""")
		#expect(realtime.outputModalities == [.audio])
		#expect(realtime.maxOutputTokens == .limited(400))
		#expect(realtime.truncation == .auto)
		#expect(realtime.audio?.input?.format == .pcm)
		#expect(realtime.audio?.input?.noiseReduction == .nearField)
		#expect(realtime.audio?.output?.format == .pcm)
		#expect(realtime.audio?.output?.voice == .marin)
		#expect(realtime.toolChoice == ToolChoice.none)
		#expect(tools.count == 2)
		#expect(functionName(from: tools[0]) == "search")
		#expect(functionName(from: tools[1]) == "calendar")
	}

	@Test
	func buildsHostedInstructionsTracingAndAudioConfiguration() throws {
		let session = try SessionConfiguration(.gptRealtime) {
			Instructions("cosmos_glasses", version: 2) {
				Variables([
					"location": "office",
					"mode": "focused",
				])
			}

			Response(.audio) {
				MaxTokens(.max)
				Truncation(.auto)
			}
			.include(.field(.inputAudioTranscriptionLogProbs))

			Tracing {
				Workflow("cosmos")
				Group("workday-session")
				Metadata([
					"surface": "glasses",
					"environment": "prod",
				])
			}

			AudioInput(.pcm) {
				NoiseReduction(.nearField)

				Transcription(.gpt4oTranscribe) {
					Language(.english)
					Prompt("Workplace vocabulary, project names, colleague names")
				}

				TurnDetection {
					Semantic(interrupts: false, responds: true) {
						Eagerness(.auto)
					}
				}
			}

			AudioOutput(.pcm) {
				Voice(.marin).speed(1.1)
			}
		}

		let realtime = try #require(realtimeSession(from: session))
		let prompt = try #require(realtime.prompt)
		let tracing = try #require(realtime.tracing)
		let audioInput = try #require(realtime.audio?.input)
		let audioOutput = try #require(realtime.audio?.output)

		#expect(prompt.id == "cosmos_glasses")
		#expect(prompt.version == "2")
		#expect(prompt.variables?["location"] == "office")
		#expect(prompt.variables?["mode"] == "focused")
		#expect(realtime.instructions == nil)
		#expect(realtime.include == [SessionConfiguration.Include.inputAudioTranscriptionLogprobs])
		#expect(realtime.maxOutputTokens == .max)
		#expect(audioInput.noiseReduction == SessionConfiguration.AudioInput.NoiseReduction.nearField)
		#expect(audioInput.transcription?.model == .gpt4oTranscribe)
		#expect(audioInput.transcription?.language == "en")
		#expect(audioInput.transcription?.prompt == "Workplace vocabulary, project names, colleague names")
		#expect(audioInput.turnDetection == SessionConfiguration.AudioInput.TurnDetection.semanticVAD(
			createResponse: true,
			eagerness: .auto,
			interruptResponse: false
		))
		#expect(audioOutput.voice == SessionConfiguration.Voice.marin)
		#expect(audioOutput.speed == 1.1)

		switch tracing {
			case let .configuration(configuration):
				#expect(configuration.workflowName == "cosmos")
				#expect(configuration.groupId == "workday-session")
				#expect(configuration.metadata == [
					"surface": SessionConfiguration.Tracing.MetadataValue.string("glasses"),
					"environment": SessionConfiguration.Tracing.MetadataValue.string("prod"),
				])
			case .auto:
				Issue.record("Expected tracing configuration")
		}
	}

	@Test
	func buildsServerVADAndSpecificRequiredToolChoice() throws {
		let session = try SessionConfiguration(.gptRealtime) {
			Instructions {
				"Use the calendar tool for scheduling tasks."
			}

			Response(.audio) {
				MaxTokens(500)
				Truncation(.auto)
			}

			AudioInput(.pcm) {
				TurnDetection {
					ServerVAD(interrupts: false, responds: true) {
						PrefixPadding(.seconds(1))
						SilenceDuration(.seconds(1))
						IdleTimeout(.seconds(10))
						Threshold(.medium)
					}
				}
			}

			Tools(choice: .required(CalendarTool.self)) {
				SearchTool()
				CalendarTool()
			}
		}

		let realtime = try #require(realtimeSession(from: session))
		let turnDetection = try #require(realtime.audio?.input?.turnDetection)

		#expect(realtime.toolChoice == .function(name: "calendar"))
		#expect(turnDetection == .serverVAD(
			createResponse: true,
			idleTimeoutMs: 10_000,
			interruptResponse: false,
			prefixPaddingMs: 1_000,
			silenceDurationMs: 1_000,
			threshold: 0.5
		))
	}

	@Test
	func buildsMCPDefinitionsAndConnectorSelections() throws {
		let session = try SessionConfiguration(.gptRealtime) {
			Instructions {
				"Use workspace tools when needed."
			}

			Response(.audio) {
				MaxTokens(700)
				Truncation(.auto)
			}

			Tools(choice: .auto) {
				DropboxConnector()
					.deferred()
					.approval(.required)

				MCP("internal-ops", server: "https://example.com/mcp") {

					Description {
						"Internal operations MCP server."
						"Provides deployment, status, and search tools."
					}

					ToolPolicies {
						Tool("searchDocs")
						Tool("listProjects")
						Tool("fetchFile").approval(.required)
					}

					Headers([
						"x-org": "openai",
						"x-agent": "cosmos",
					])

					AuthorizationToken("oauth-token")
				}

				GoogleDriveConnector {
					ToolPolicies(.allowAll)
				}
			}
		}

		let realtime = try #require(realtimeSession(from: session))
		let tools = try #require(realtime.tools)
		#expect(tools.count == 3)

		guard
			case let .mcp(dropbox) = tools[0],
			case let .mcp(internalOps) = tools[1],
			case let .mcp(drive) = tools[2]
		else {
			Issue.record("Expected MCP-based tool definitions")
			return
		}

		#expect(dropbox.connectorId == .dropbox)
		#expect(dropbox.serverLabel == "dropbox_connector")
		#expect(dropbox.deferLoading == true)
		#expect(dropbox.requireApproval == .setting(.always))

		#expect(internalOps.serverLabel == "internal-ops")
		#expect(internalOps.serverUrl?.absoluteString == "https://example.com/mcp")
		#expect(internalOps.serverDescription == """
		Internal operations MCP server.
		Provides deployment, status, and search tools.
		""")
		#expect(internalOps.headers == [
			"x-org": "openai",
			"x-agent": "cosmos",
		])
		#expect(internalOps.authorization == "oauth-token")
		#expect(internalOps.allowedTools == .names(["searchDocs", "listProjects", "fetchFile"]))
		#expect(internalOps.requireApproval == .rules(.init(
			always: .init(toolNames: ["fetchFile"]),
			never: nil
		)))

		#expect(drive.serverLabel == "google_drive_connector")
		#expect(drive.connectorId == .googleDrive)
		#expect(drive.allowedTools == nil)
	}

	@Test
	func buildsPrefixAllowPolicies() throws {
		let session = try SessionConfiguration(.gptRealtime) {
			Response(.audio) {
				MaxTokens(500)
				Truncation(.auto)
			}

			Tools(choice: .auto) {
				MCP("calendar", server: "https://example.com/calendar-mcp") {

					ToolPolicies(.allow(prefix: "calendar")) {
						Tool("calendar.deleteEvent").approval(.required)
						Tool("calendar.getAvailability").readOnly()
						Tool("docs.search")
					}
				}
			}
		}

		let realtime = try #require(realtimeSession(from: session))
		let tools = try #require(realtime.tools)

		guard case let .mcp(calendar) = try #require(tools.first) else {
			Issue.record("Expected MCP tool definition")
			return
		}

		#expect(calendar.allowedTools == .names([
			"calendar.deleteEvent",
			"calendar.getAvailability",
		]))
		#expect(calendar.requireApproval == .rules(.init(
			always: .init(toolNames: ["calendar.deleteEvent"]),
			never: .init(toolNames: ["calendar.getAvailability"])
		)))
	}

	@Test
	func rejectsInvalidMaxTokens() {
		#expect(throws: SessionConfigurationBuilderError.self) {
			try SessionConfiguration(.gptRealtime) {
				Response(.audio) {
					MaxTokens(0)
				}
			}
		}
	}

	@Test
	func rejectsMissingRequiredToolDefinition() {
		#expect(throws: SessionConfigurationBuilderError.self) {
			try SessionConfiguration(.gptRealtime) {
				Response(.audio) {
					MaxTokens(500)
				}

				Tools(choice: .required(CalendarTool.self)) {
					SearchTool()
				}
			}
		}
	}

	@Test
	func requiredToolSelectionUsesOverriddenToolName() throws {
		let session = try SessionConfiguration(.gptRealtime) {
			Response(.audio) {
				MaxTokens(500)
			}

			Tools(choice: .required(AliasedCalendarTool.self)) {
				AliasedCalendarTool()
			}
		}

		let realtime = try #require(realtimeSession(from: session))
		#expect(realtime.toolChoice == .function(name: "calendar"))
	}

	@Test
	func rejectsHostedInstructionsInsideInlineInstructionsBuilder() {
		#expect(throws: SessionConfigurationBuilderError.self) {
			try SessionConfiguration(.gptRealtime) {
				Instructions {
					Instructions("hosted_prompt", version: 1) {
						Variables(["surface": "glasses"])
					}
				}
			}
		}
	}

	@Test
	func rejectsInvalidMCPServerURL() {
		#expect(throws: SessionConfigurationBuilderError.self) {
			try SessionConfiguration(.gptRealtime) {
				Response(.audio) {
					MaxTokens(500)
				}

				Tools(choice: .auto) {
					MCP("internal-ops", server: "not a valid url") {
						ToolPolicies(.allowAll)
					}
				}
			}
		}
	}
}

private func realtimeSession(from session: SessionConfiguration) -> SessionConfiguration.Realtime? {
	guard case let .realtime(realtime) = session else {
		return nil
	}

	return realtime
}

private struct AliasedCalendarTool: FunctionTool {
	@Generable
	struct Arguments: Codable, Sendable {
		let value: String
	}

	let name = "calendar"
	let description = "Calendar tool with an explicit overridden name."

	func call(arguments _: Arguments) async throws -> String {
		"ok"
	}
}

private func functionName(from definition: ToolDefinition) -> String? {
	guard case let .function(function) = definition else {
		return nil
	}

	return function.name
}

private struct SafetyRail: InstructionsRepresentable {
	let text: String

	init(_ text: String) {
		self.text = text
	}

	var instructionsRepresentation: Instructions {
		Instructions(text)
	}
}

private struct DirectoryContext: PromptRepresentable {
	let text: String

	init(_ text: String) {
		self.text = text
	}

	var promptRepresentation: Prompt {
		Prompt(text)
	}
}

private func encodedSessionJSON(_ session: SessionConfiguration) throws -> String {
	let encoder = JSONEncoder()
	encoder.keyEncodingStrategy = .convertToSnakeCase
	let data = try encoder.encode(session)
	let object = try JSONSerialization.jsonObject(with: data)
	let canonicalData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
	return try #require(String(data: canonicalData, encoding: .utf8))
}

private func canonicalJSON(_ json: String) throws -> String {
	let data = Data(json.utf8)
	let object = try JSONSerialization.jsonObject(with: data)
	let canonicalData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
	return try #require(String(data: canonicalData, encoding: .utf8))
}

private struct SearchTool: FunctionTool {
	let description = "Search the web."
	let parameters = GenerationSchema.object(
		properties: ["query": .string(description: "Search query")],
		required: ["query"]
	)

	struct Arguments: ConvertibleFromGeneratedContent {
		let query: String
	}

	func call(arguments: Arguments) async throws -> String {
		arguments.query
	}
}

private struct CalendarTool: FunctionTool {
	let description = "Manage calendar events."
	let parameters = GenerationSchema.object(
		properties: ["action": .string(description: "Calendar action")],
		required: ["action"]
	)

	struct Arguments: ConvertibleFromGeneratedContent {
		let action: String
	}

	func call(arguments: Arguments) async throws -> String {
		arguments.action
	}
}
