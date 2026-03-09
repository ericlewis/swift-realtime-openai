# RealtimeAPI

A Swift SDK for OpenAI's GA Realtime API, with both a low-level event surface and a higher-level `Conversation` wrapper for speech and multimodal sessions.

## Installation

Add the package in Xcode or SwiftPM:

```swift
dependencies: [
	.package(url: "https://github.com/m1guelpf/swift-realtime-openai.git", branch: "main")
]
```

## Quick Start

### High-level conversation API

Create a GA client secret on your server with `POST /v1/realtime/client_secrets`, then connect with `Conversation.connect(clientSecret:)`.

You can mint that secret directly with the SDK:

```swift
import RealtimeAPI

let clientSecret = try await RealtimeAPI.createClientSecret(
	apiKey: "<server-api-key>",
	session: .realtime(.init(
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
	@State private var conversation = Conversation()
	@State private var draft = ""

	var body: some View {
		VStack {
			ScrollView {
				LazyVStack(alignment: .leading, spacing: 12) {
					ForEach(conversation.messages, id: \.id) { message in
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
			do {
				try await conversation.connect(clientSecret: "<client-secret>")
			} catch {
				print("Realtime connect failed:", error)
			}
		}
	}

	private func sendMessage() {
		guard !draft.isEmpty else { return }
		try? conversation.send(from: .user, text: draft)
		draft = ""
	}
}
```

### Session configuration

`Conversation` is GA-first and works with `Session.Realtime`.

```swift
try await conversation.whenConnected {
	try conversation.updateSession { session in
		session.instructions = "You are a concise assistant."
		session.outputModalities = [.audio]
		session.audio = .init(
			output: .init(voice: .marin)
		)
	}
}
```

### Direct WebRTC connection

Use the GA client-secret flow when connecting directly to WebRTC:

```swift
import RealtimeAPI

let api = try await RealtimeAPI.webRTC(clientSecret: "<client-secret>")
```

### Direct WebSocket connection

The WebSocket helpers support the unified GA flow with either a client secret or a bearer token:

```swift
import RealtimeAPI

let api = RealtimeAPI.webSocket(clientSecret: "<client-secret>")
let serverSideAPI = RealtimeAPI.webSocket(authToken: "<api-key>")
```

Send GA-shaped events through the low-level API:

```swift
try await api.send(event: .updateSession(.realtime(.init(
	model: .gptRealtime,
	instructions: "Be helpful.",
	audio: .init(output: .init(voice: .marin))
))))

for try await event in api.events {
	switch event {
		case let .responseOutputTextDelta(_, _, _, _, _, delta):
			print(delta)
		case let .responseOutputAudioTranscriptDelta(_, _, _, _, _, delta):
			print(delta)
		default:
			break
	}
}
```

## Key Types

### `Session`

`Session` is a tagged GA union:

- `Session.realtime(Session.Realtime)`
- `Session.transcription(Session.Transcription)`

Realtime session fields follow the GA wire shape:

- `audio.input`
- `audio.output`
- `outputModalities`
- `maxOutputTokens`
- `include`
- `tracing`
- `truncation`

### `Response.Config`

`Response.Config` matches GA `response.create` payloads, including:

- nested audio config
- `conversation`
- `metadata`
- `outputModalities`
- `toolChoice`
- `tools`
- `input: [Response.InputItem]`

For out-of-band responses, use `Response.InputItem.itemReference(id:)`:

```swift
let response = Response.Config(
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
