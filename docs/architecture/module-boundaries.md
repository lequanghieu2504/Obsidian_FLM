# Module boundaries

Allowed dependency direction:

```text
Desktop UI → feature/application layer → domain/core abstractions
Infrastructure → domain-facing abstractions
FLM core → domain
Knowledge graph / Obsidian core / RAG core → domain and narrow shared primitives
Desktop and extension → schemas (generated or validated representations)
```

The domain must not depend on Flutter, browser APIs, SQLite, HTTP, filesystems, LLM SDKs, or backend APIs. The extension and desktop must not import one another's internals. Provider-specific infrastructure stays outside core packages. Circular dependencies are prohibited.
