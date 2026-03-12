# ``RealtimeAPI``

Build speech and multimodal realtime experiences with a high-level ``Session`` runtime, a configuration model centered on ``SessionConfiguration``, and a Swift-friendly DSL for assembling session behavior.

## Overview

`RealtimeAPI` is organized around three layers:

- The runtime layer, centered on ``Session``, which owns connection lifecycle, observation streams, conversation state, and tool dispatch.
- The configuration layer, centered on ``SessionConfiguration``, which models realtime and transcription session state.
- The authoring layer, centered on ``FunctionTool``, ``Generable``, and the session DSL, which helps you describe prompts, tools, audio behavior, and turn detection.

For most applications, start with ``Session`` and a client secret created by ``RealtimeAPI/createClientSecret(apiKey:configuration:expiresAfter:using:)``.

## Topics

### Essentials

- <doc:Session-Runtime>
- <doc:Session-Configuration>
- <doc:Session-DSL>
- <doc:Tool-Authoring>
- <doc:Debugging-And-Observation>

### Core Symbols

- ``Session``
- ``SessionConfiguration``
- ``Item``
- ``ResponseDTO/Config``
- ``Model``
- ``GenerationSchema``
- ``RealtimeClientSecret``
