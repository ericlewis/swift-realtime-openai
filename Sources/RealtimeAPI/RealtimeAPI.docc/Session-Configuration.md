# Session Configuration

Use ``SessionConfiguration`` to describe the behavior of a realtime or transcription session.

## Session kinds

- ``SessionConfiguration/realtime(_:)`` configures a full assistant session with output modalities, tools, tracing, and truncation.
- ``SessionConfiguration/transcription(_:)`` configures transcription-only sessions focused on input audio processing.

## Common concepts

- Prompt templates through ``SessionConfiguration/Prompt``
- Audio input and output settings through ``SessionConfiguration/AudioInput`` and ``SessionConfiguration/AudioOutput``
- Tool choice and tool definitions through ``ToolChoice`` and ``ToolDefinition``
- Tracing and truncation with ``SessionConfiguration/Tracing`` and ``SessionConfiguration/Truncation``

## Runtime updates

At startup, ``Session`` accepts a configuration transform so you can adjust the full configuration before the first update is sent. After connecting, use the live transform APIs on ``Session`` to update either realtime or transcription configuration.
