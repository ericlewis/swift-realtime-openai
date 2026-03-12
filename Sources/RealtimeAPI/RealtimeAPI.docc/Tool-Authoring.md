# Tool Authoring

Use ``FunctionTool`` to define local tools that the runtime can advertise and dispatch automatically.

## Core building blocks

- ``FunctionTool`` for the executable tool contract
- ``ToolRegistry`` for runtime registration and dispatch
- ``Generable`` for schema-derived argument modeling
- ``GuideConstraint`` and `@Guide` for describing fields in generated schemas

## Output behavior

Tool outputs flow through ``PromptRepresentable``. Simple values can render directly as prompt text, while structured values can be encoded into generated content for function-call output.

## Explicit nil behavior

If a `@Generable` type opts into explicit nil representation, generated prompt content preserves `null` values instead of dropping optional fields.
