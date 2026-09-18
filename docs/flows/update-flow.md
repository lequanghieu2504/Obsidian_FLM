# Update flow

```text
latest source → validate → compare hashes/versions → replace source atomically
              → identify impact → rebuild affected derived data only
```

Source refreshes may replace official FLM data. Derived artifacts may be rebuilt. User notes, highlights, custom links, progress, chat history, and preferences are outside those replacement paths. AI-inferred edges are separately owned from official edges.
