# Session Runtime

Use ``Session`` as the primary entry point for connecting to the Realtime API from app code.

## What ``Session`` owns

- Connection lifecycle for WebRTC and WebSocket transports
- Read-only observation streams like ``Session/updates``, ``Session/failures``, ``Session/errors``, and ``Session/serverEvents``
- Current conversation state through ``Session/entries`` and ``Session/messages``
- Optional local tool dispatch through ``FunctionTool`` registration

## Transport choices

- Use `Session()` or `Session(using: .webRTC)` for the default WebRTC runtime.
- Use `Session(using: .webSocket)` when your app should speak to the Realtime API over WebSocket instead.

## Reconnect behavior

The runtime supports reconnecting after ``Session/disconnect()`` for factory-backed sessions created through the public initializers. If you inject a custom transport for testing, reconnect behavior depends on that transport.

## Observation

Prefer the high-level observation surfaces before reaching for raw protocol events:

- ``Session/updates`` for state snapshots
- ``Session/errors`` for server-side error events
- ``Session/failures`` for high-level runtime failures
- ``Session/serverEvents`` for advanced read-only protocol observation
