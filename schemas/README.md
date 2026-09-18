# Cross-application schemas

Language-neutral JSON Schema contracts shared by the extension, desktop, and possible future services. Contracts are the integration boundary; applications do not import each other's implementation models.

The initial schema files are explicit placeholders and will receive `$defs` and domain fields when contract design begins. Every transport envelope reserves `schemaVersion`, `source`, `exportedAt`, and `data`.
