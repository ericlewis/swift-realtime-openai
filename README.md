# RealtimeAPI

A Swift SDK for OpenAI's GA Realtime API centered on the high-level `Session` runtime, `SessionConfiguration`, the session DSL, tool authoring, and `serverEvents` as an advanced read-only observation surface.

## Installation

Add the package in Xcode or SwiftPM:

```swift
dependencies: [
	.package(url: "https://github.com/m1guelpf/swift-realtime-openai.git", branch: "main")
]
```

## Documentation

The package includes an in-source DocC catalog at [`Sources/RealtimeAPI/RealtimeAPI.docc`](/Users/ericlewis/Developer/swift-realtime-openai/Sources/RealtimeAPI/RealtimeAPI.docc). It covers the runtime model, session configuration, the DSL, tool authoring, and advanced observation/debugging. Use it as the deeper reference surface when browsing the package locally in Xcode or directly in the repo.

## Quick Start

### High-level session API

Create a GA client secret on your server with `POST /v1/realtime/client_secrets`, then connect with `Session.connect(clientSecret:)`.

`Session` is the main runtime surface. It defaults to WebRTC, and you can opt into WebSocket explicitly with `Session(using: .webSocket)`.

You can mint that secret directly with the SDK:

```swift
import RealtimeAPI

let clientSecret = try await RealtimeAPI.createClientSecret(
	apiKey: "<server-api-key>",
	configuration: .realtime(.init(
		model: .gptRealtime,
		instructions: "You are a friendly assistant."
	)),
	expiresAfter: .init(seconds: 600)
)
```

```swift
import RealtimeAPI
import SwiftUI

struct ContentView: View {
	@State private var session = Session()
	@State private var draft = ""
	@State private var errorMessage: String?

	var body: some View {
		VStack {
			ScrollView {
				LazyVStack(alignment: .leading, spacing: 12) {
					ForEach(session.messages, id: \.id) { message in
						Text(message.content.compactMap(\.text).joined(separator: "\n"))
					}
				}
				.padding()
			}

			HStack {
				TextField("Message", text: $draft)
				Button("Send", action: sendMessage)
			}
			.padding()
		}
		.task {
			for await failure in session.failures {
				errorMessage = String(describing: failure)
			}
		}
		.task {
			do {
				try await session.connect(clientSecret: "<client-secret>")
			} catch {
				errorMessage = String(describing: error)
			}
		}
	}

	private func sendMessage() {
		guard !draft.isEmpty else { return }
		let text = draft
		draft = ""

		Task {
			do {
				try await session.send(from: .user, text: text)
			} catch {
				errorMessage = String(describing: error)
			}
		}
	}
}
```

### Session configuration

`Session` is GA-first and works with `SessionConfiguration.Realtime`.

The startup `configuring:` callback transforms the full `SessionConfiguration`, so it can also adjust transcription sessions when you need symmetry across both session kinds.

```swift
let session = Session(configuring: { configuration in
	switch configuration {
		case var .realtime(realtime):
			realtime.instructions = "You are a concise assistant."
			return .realtime(realtime)
		case .transcription:
			return configuration
	}
})
```

If you need raw server visibility for debugging or custom instrumentation, `Session` also exposes a read-only `serverEvents` stream while keeping raw client event sending internal.

```swift
try await session.whenConnected {
	try await session.updateConfiguration { configuration in
		var updated = configuration
		updated.instructions = "You are a concise assistant."
		updated.outputModalities = [.audio]
		updated.audio = .init(
			output: .init(voice: .marin)
		)
		return updated
	}
}
```

### WebSocket sessions

If you want the high-level runtime over WebSocket instead of WebRTC:

```swift
import RealtimeAPI

let session = Session(using: .webSocket)
try await session.connect(authToken: "<api-key>")
```

### Session DSL

You can also build realtime sessions with the result-builder DSL:

```swift
import RealtimeAPI

let configuration = try SessionConfiguration(.gptRealtime) {
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

	Tools(choice: .auto) {
		FindContactsTool()

		GoogleDriveConnector {
			ToolPolicies(.allowAll)
		}
	}
}
```

One naming note:

- `Tool("...")` inside `ToolPolicies` defines MCP tool policies, while `FunctionTool` is the executable tool-authoring protocol.

You can also reuse instruction and prompt values in a style closer to Foundation Models:

```swift
import RealtimeAPI

let system = Instructions {
	"You are Cosmos speaking through smart glasses."
	Prompt {
		"Keep responses concise."
		"Be natural."
	}
}

let transcriptionPrompt = Prompt {
	"Workplace vocabulary"
	"Project names"
	"Colleague names"
}

let configuration = try SessionConfiguration(.gptRealtime) {
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
```

Custom types can participate by conforming to `InstructionsRepresentable` or `PromptRepresentable`.

The package still contains lower-level transport and event primitives, but they are intentionally secondary to the `Session` runtime and are not the recommended starting point.

## Tool Authoring

The SDK supports typed tool authoring with `@Generable` arguments and `@Guide` field constraints, close to Apple’s Foundation Models surface:

```swift
import RealtimeAPI

struct FindContacts: FunctionTool {
	let name = "findContacts"
	let description = "Find a specific number of contacts."

	@Generable(description: "Search parameters for a contact lookup.", representNilExplicitlyInGeneratedContent: true)
	struct Arguments: Generable {
		@Guide(description: "The number of contacts to get.", .range(1...10))
		let count: Int

		@Guide(description: "A prefix for contact names.", .pattern("^[A-Za-z]+$"), .length(2...24))
		let prefix: String?

		@Guide(description: "Email-like query text.", .format(.email))
		let email: String?

		@Guide(description: "Tags to include.", .count(1...3))
		let tags: [String]
	}

	func call(arguments: Arguments) async throws -> [String] {
		["Ada Lovelace", "Grace Hopper"]
	}
}
```

Public authoring protocols now mirror the Foundation Models split:

- `GenerationSchema` is the public schema name
- `ConvertibleFromGeneratedContent` is the input-side decoding protocol
- `ConvertibleToGeneratedContent` is the prompt/instructions-side encoding protocol
- `Generable` inherits both and synthesizes `generationSchema`

Supported `@Guide` constraints:

- numeric: `.minimum`, `.maximum`, `.range`
- arrays: `.count`, `.minimumCount`, `.maximumCount`
- strings: `.pattern`, `.format`, `.length`, `.minimumLength`, `.maximumLength`, `.constant`, `.anyOf`

`ToolRegistry` will JSON-encode non-`String` tool outputs automatically before sending them back as `function_call_output` items.

The macros also emit compile-time diagnostics for invalid combinations such as `.pattern` on an `Int` or `.count` on a `String`.

At the API level:

- `FunctionTool` is the authoring protocol for executable tools
- `ToolDefinition` is the GA wire-model payload used in sessions and responses
- `ToolChoice` models GA tool-selection behavior

## Key Types

### `Session`

`Session` is the high-level connected runtime. It owns:

- connection state
- `configuration`
- `conversationID`
- `entries`
- `messages`
- async `updates`

### `SessionConfiguration`

`SessionConfiguration` is a tagged GA union:

- `SessionConfiguration.realtime(SessionConfiguration.Realtime)`
- `SessionConfiguration.transcription(SessionConfiguration.Transcription)`

Realtime session fields follow the GA wire shape:

- `audio.input`
- `audio.output`
- `outputModalities`
- `maxOutputTokens`
- `include`
- `tracing`
- `truncation`

### `ResponseDTO.Config`

`ResponseDTO.Config` matches GA `response.create` payloads, including:

- nested audio config
- `conversation`
- `metadata`
- `outputModalities`
- `toolChoice`
- `tools`
- `input: [ResponseDTO.InputItem]`

For out-of-band responses, use `ResponseDTO.InputItem.itemReference(id:)`:

```swift
let response = ResponseDTO.Config(
	conversation: .none,
	outputModalities: [.text],
	input: [
		.itemReference(id: "item_12345"),
		.message(.init(
			id: "msg_123",
			role: .user,
			content: [.inputText("Summarize the above message in one sentence.")]
		)),
	]
)
```

### `Item`

Assistant message content uses the GA discriminators:

- `Item.Message.Content.outputText`
- `Item.Message.Content.outputAudio`

MCP call items also use GA naming:

- `Item.mcpCall`

## Testing

The package includes GA protocol fixture tests for:

- client event encoding
- server event decoding
- conversation upsert behavior for `conversation.item.added` / `.done`
- streamed `output_text` and `output_audio_transcript` handling
- automatic tool dispatch for completed function calls

## License

MIT. See [LICENSE](LICENSE).
