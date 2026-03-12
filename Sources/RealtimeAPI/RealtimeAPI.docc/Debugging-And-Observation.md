# Debugging and Observation

`RealtimeAPI` exposes several ways to observe session behavior without dropping down to raw client event authoring.

## High-level streams

- ``Session/errors`` yields server-side error payloads
- ``Session/failures`` yields runtime failures from the high-level wrapper
- ``Session/updates`` yields state snapshots for UI or diagnostics

## Raw server events

Use ``Session/serverEvents`` when you need to inspect the underlying protocol stream for debugging, analytics, or advanced observation. This stream is intentionally read-only; raw client event sending is not part of the recommended public app surface.

## Debug logging

``Session/debug`` enables verbose runtime logging for the session wrapper. Prefer this and the observation streams before adding custom logging around the transport layer.
