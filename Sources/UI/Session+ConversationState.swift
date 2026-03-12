import Core
import Foundation

extension Session {
	func upsertEntry(_ item: Item, after previousItemId: String?) {
		if let itemId = item.id, let index = entryIndexesByItemID[itemId] {
			entryRecords[index].item = item
			markConversationChanged()
			return
		}

		let record = EntryRecord(localId: UUID().uuidString, item: item)

		guard let previousItemId else {
			entryRecords.append(record)
			rebuildEntryIndexes()
			markConversationChanged()
			return
		}

		if previousItemId == "root" {
			entryRecords.insert(record, at: 0)
			rebuildEntryIndexes()
			markConversationChanged()
			return
		}

		guard let previousIndex = entryIndexesByItemID[previousItemId] else {
			entryRecords.append(record)
			rebuildEntryIndexes()
			markConversationChanged()
			return
		}

		entryRecords.insert(record, at: previousIndex + 1)
		rebuildEntryIndexes()
		markConversationChanged()
	}

	func replaceEntryIfPresent(_ item: Item) {
		guard let itemId = item.id,
		      let index = entryIndexesByItemID[itemId]
		else {
			return
		}
		entryRecords[index].item = item
		rebuildEntryIndexes()
		markConversationChanged()
	}

	func updateMessage(id: String, modifying closure: (inout Item.Message) -> Void) {
		guard let index = entryIndex(forLookupID: id),
		      case var .message(message) = entryRecords[index].item
		else {
			return
		}

		closure(&message)
		entryRecords[index].item = .message(message)
		markConversationChanged()
	}

	func updateFunctionCall(id: String, modifying closure: (inout Item.FunctionCall) -> Void) {
		guard let index = entryIndex(forLookupID: id),
		      case var .functionCall(functionCall) = entryRecords[index].item
		else {
			return
		}

		closure(&functionCall)
		entryRecords[index].item = .functionCall(functionCall)
		markConversationChanged()
	}

	func messageContent(for part: ResponseDTO.ContentPart) -> Item.Message.Content {
		switch part {
			case let .outputText(text):
				.outputText(text)
			case let .outputAudio(audio):
				.outputAudio(audio)
		}
	}

	func matches(_ record: EntryRecord, id: String) -> Bool {
		record.localId == id || record.item.id == id
	}

	func entryIndex(forLookupID id: String) -> Int? {
		entryIndexesByItemID[id] ?? entryIndexesByLocalID[id]
	}

	func rebuildEntryIndexes() {
		entryIndexesByItemID.removeAll(keepingCapacity: true)
		entryIndexesByLocalID.removeAll(keepingCapacity: true)

		// Structural edits are less frequent than streamed content deltas, so we pay the
		// rebuild cost here to keep the hot mutation path on O(1) indexed lookups.
		for (index, record) in entryRecords.enumerated() {
			entryIndexesByLocalID[record.localId] = index
			if let itemId = record.item.id {
				entryIndexesByItemID[itemId] = index
			}
		}
	}

	func insertOrAppend(_ content: Item.Message.Content, at index: Int, in contents: inout [Item.Message.Content]) {
		if index <= contents.count {
			contents.insert(content, at: index)
		} else {
			contents.append(content)
		}
	}

	func setOrAppend(_ content: Item.Message.Content, at index: Int, in contents: inout [Item.Message.Content]) {
		if contents.indices.contains(index) {
			contents[index] = content
		} else {
			contents.append(content)
		}
	}

	func markConversationChanged() {
		conversationRevision &+= 1
		// Derived arrays are cached for read performance and invalidated only when the
		// underlying conversation structure or item content changes.
		cachedEntries = nil
		cachedMessages = nil
	}

	func publishSnapshotIfNeeded() {
		let snapshot = Snapshot(
			status: status,
			isUserSpeaking: isUserSpeaking,
			isModelSpeaking: isModelSpeaking,
			conversationID: conversationID,
			conversationRevision: conversationRevision
		)

		guard snapshot != lastPublishedSnapshot else { return }
		lastPublishedSnapshot = snapshot
		updateStream.yield(snapshot)
	}
}
