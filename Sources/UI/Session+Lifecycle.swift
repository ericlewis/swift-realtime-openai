import Core
import Foundation

extension Session {
	static func makeEventTask(
		transport: Transport,
		handleEvent: @escaping @MainActor @Sendable (ServerEvent) async throws -> Void,
		reportFailure: @escaping @MainActor @Sendable (SessionError) -> Void
	) -> Task<Void, Never> {
		Task { @MainActor in
			do {
				for try await event in transport.events {
					do { try await handleEvent(event) }
					catch {
						reportFailure(.eventHandlingFailed)
					}

					guard !Task.isCancelled else { break }
				}
			} catch {
				reportFailure(.eventStreamFailed)
			}
		}
	}

	static func makeStatusTask(
		transport: Transport,
		handleStatus: @escaping @MainActor @Sendable (RealtimeAPI.Status) -> Void
	) -> Task<Void, Never> {
		Task { @MainActor in
			for await status in transport.statusUpdates {
				handleStatus(status)

				guard !Task.isCancelled else { break }
			}
		}
	}

	func awaitConnectionStatus() async throws {
		if status == .connected {
			return
		}

		var sawConnecting = status == .connecting
		var iterator = statusStream().makeAsyncIterator()

		while let status = await iterator.next() {
			switch status {
				case .connected:
					return
				case .connecting:
					sawConnecting = true
				case .disconnected where sawConnecting:
					throw SessionError.disconnectedWhileWaitingForConnection
				case .disconnected:
					continue
			}
		}

		throw SessionError.disconnectedWhileWaitingForConnection
	}

	func statusStream() -> AsyncStream<RealtimeAPI.Status> {
		let id = UUID()

		return AsyncStream { continuation in
			statusObservers[id] = continuation
			continuation.yield(status)
			continuation.onTermination = { [weak self] _ in
				Task { @MainActor in
					self?.statusObservers.removeValue(forKey: id)
				}
			}
		}
	}

	func handleStatusUpdate(_ status: RealtimeAPI.Status) {
		storeStatus(status)
		for observer in statusObservers.values {
			observer.yield(status)
		}
		publishSnapshotIfNeeded()
	}
}
