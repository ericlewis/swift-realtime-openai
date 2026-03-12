# Session DSL

The session DSL provides a result-builder interface for creating ``SessionConfiguration`` values with less boilerplate than the raw model initializers.

## Typical structure

Start from `SessionConfiguration(.gptRealtime) { ... }` and compose the session from top-level components like:

- ``Instructions``
- ``Response``
- ``Tracing``
- ``AudioInput``
- ``AudioOutput``
- ``Tools``

## What the DSL is for

Use the DSL when you want:

- readable session setup in app code
- hosted prompt configuration through ``Instructions``
- structured audio and turn-detection configuration
- MCP and function tool declarations close to the session definition

Use the raw ``SessionConfiguration`` initializers when you need a more direct or programmatic construction path.
