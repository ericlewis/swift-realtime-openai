import Testing
import Foundation
@testable import Core

@Suite("Decode tolerance")
struct DecodeToleranceTests {
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    @Test("ServerEvent decoder throws on unknown event types (documents current behavior)")
    func unknownEventTypeThrows() {
        let payload = Data(#"{"type":"response.some_future_event","event_id":"evt_1"}"#.utf8)
        #expect(throws: DecodingError.self) {
            _ = try makeDecoder().decode(ServerEvent.self, from: payload)
        }
    }

    @Test("Known GA event types still decode successfully (regression guard)")
    func knownEventDecodesFine() throws {
        let payload = Data("""
        {"type":"conversation.item.added","event_id":"evt_2","previous_item_id":null,"item":{"id":"item_1","type":"message","role":"user","status":"completed","content":[{"type":"input_text","text":"hi"}]}}
        """.utf8)

        let event = try makeDecoder().decode(ServerEvent.self, from: payload)
        guard case .conversationItemAdded = event else {
            Issue.record("Expected .conversationItemAdded, got \(event)")
            return
        }
    }
}
