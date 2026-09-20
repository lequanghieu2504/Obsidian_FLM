# Browser extension

Manifest V3 TypeScript application responsible only for session-aware FLM extraction, basic source validation, and schema-based export. FLM selectors belong in `src/extractors`; normalization, graph, Markdown, RAG, and recommendation logic do not.

## Development

```sh
npm install
npm test
npm run typecheck
npm run build
```

Load `dist/` as an unpacked extension. Open a student or guest `CurriculumDetails?curid=...` page, open the extension, and explicitly click **Crawl**. The detected role is reused for curriculum and syllabus requests. Crawls are never started by login, navigation, or extension startup.

The export is a single ZIP-compatible `.flmpkg` containing `manifest.json`, full response HTML under `raw/`, and parsed academic JSON under `extracted/`.
