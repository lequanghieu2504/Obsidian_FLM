You are a senior software architect with 20+ years of experience designing maintainable, scalable software systems.

I am starting a university project named **Obsidian_FLM**.

Your task is to create the **initial repository architecture and folder tree only**.

Do NOT implement product features yet.

The goal is to establish a clean, understandable, extensible foundation that can grow for several years without requiring an early structural rewrite.

---

# 1. Product overview

Obsidian_FLM consists initially of two applications:

1. **Flutter Desktop Application**

   * Windows is the primary target initially.
   * macOS/Linux support may be added later.

2. **Browser Extension**

   * Chrome / Edge compatible.
   * Manifest V3.
   * Used to extract academic data from FPT University's FLM website.

There is **NO backend in the first phase**.

All user data and crawled FLM data must remain on the user's local machine.

A backend may be introduced in the future, so the architecture must allow adding backend services later without requiring restructuring of the desktop app or extension.

---

# 2. Core product flow

The conceptual flow is:

```text
FPT FLM Website
        ↓
Browser Extension
        ↓
Extract raw academic data
        ↓
Transport package
        ↓
Flutter Desktop App
        ↓
Validate
        ↓
Normalize
        ↓
Canonical Local Academic Data
        ↓
Knowledge Graph
        ↓
Prerequisite Graph
        ↓
Obsidian-style Markdown Vault
        ↓
Search / RAG
        ↓
LLM
        ↓
Q&A / Analysis / Study Guidance
```

Initial communication between extension and desktop may use file export/import.

Future versions may use localhost communication.

Do not tightly couple the extension to the Flutter application.

---

# 3. Academic data

FLM may contain information such as:

```text
Program
Curriculum
Semester
Course
Syllabus
Prerequisite
Topic
Session
Learning Outcome
Assessment
Material
Reference
```

The system should eventually represent these as structured academic entities.

A core requirement is a clear:

```text
Academic Knowledge Graph
```

and especially a:

```text
Prerequisite Graph
```

Example:

```text
PRO192
   ↓ prerequisite
PRM393
```

The architecture must also distinguish:

```text
Official academic relationships
```

from:

```text
Inferred relationships
```

Example:

```text
OFFICIAL_PREREQUISITE_OF
```

must never be confused with:

```text
RECOMMENDED_BEFORE
RELATED_TO
CONCEPT_DEPENDS_ON
```

---

# 4. Local-first requirements

All data must initially remain on the user's machine.

Data should conceptually be separated into:

```text
Source Data
Derived Data
User Data
```

## Source Data

Data extracted from FLM.

Examples:

```text
raw FLM course
raw syllabus
curriculum
prerequisites
```

## Derived Data

Generated from source data.

Examples:

```text
normalized academic data
knowledge graph
prerequisite graph
Markdown
chunks
embeddings
search index
```

## User Data

Must never be overwritten by FLM updates.

Examples:

```text
personal notes
highlights
custom links
tags
learning progress
chat history
user preferences
```

This separation must be reflected in the architecture.

---

# 5. Update behavior

Users may later request:

```text
Update this course
Update selected courses
Update curriculum
```

When FLM data changes, the system should conceptually support:

```text
crawl latest version
        ↓
validate
        ↓
compare with current local version
        ↓
detect changes
        ↓
replace canonical FLM source data
        ↓
rebuild only affected derived data
```

Affected data may include:

```text
normalized models
knowledge graph edges
prerequisite graph
Markdown
RAG chunks
embeddings
search index
```

Do NOT design updates as blindly overwriting every user file.

Official FLM-generated data may be replaced.

User-generated data must remain untouched.

Inferred AI relationships should also remain logically separate from official FLM facts.

Prepare the architecture for:

```text
content hashes
schema versioning
source provenance
atomic updates
```

but do not implement them yet.

---

# 6. Repository style

Use a **monorepo**.

Both applications must live in the same repository but remain independently buildable.

Use this top-level structure:

```text
Obsidian_FLM/
├── apps/
│   ├── desktop/
│   └── extension/
│
├── packages/
│
├── schemas/
│
├── services/
│
├── docs/
│
├── scripts/
│
├── samples/
│
├── tests/
│
├── .github/
│   └── workflows/
│
├── .gitignore
├── README.md
└── LICENSE
```

Do not create unnecessary folders simply to make the repository appear complex.

Every directory must have a clear responsibility.

---

# 7. Flutter Desktop application

Create:

```text
apps/desktop/
```

This is the Flutter desktop application.

Use a combination of:

```text
feature-first architecture
+
clean architectural boundaries
```

Recommended structure:

```text
apps/desktop/
├── lib/
│   ├── app/
│   │   ├── router/
│   │   ├── theme/
│   │   ├── dependency_injection/
│   │   ├── app.dart
│   │   └── bootstrap.dart
│   │
│   ├── core/
│   │   ├── errors/
│   │   ├── logging/
│   │   ├── storage/
│   │   ├── filesystem/
│   │   └── platform/
│   │
│   ├── features/
│   │   ├── curriculum/
│   │   ├── courses/
│   │   ├── knowledge_graph/
│   │   ├── prerequisite_graph/
│   │   ├── vault/
│   │   ├── import_export/
│   │   ├── assistant/
│   │   └── settings/
│   │
│   └── main.dart
│
├── test/
├── windows/
├── macos/
├── linux/
└── pubspec.yaml
```

Each substantial feature may internally contain:

```text
data/
domain/
presentation/
```

but only create those subfolders when they are actually meaningful.

Avoid unnecessary nesting.

Flutter UI must not contain core parsing, graph-building, or Markdown-generation logic.

---

# 8. Browser extension

Create:

```text
apps/extension/
```

Use:

```text
TypeScript
Manifest V3
```

Recommended structure:

```text
apps/extension/
├── src/
│   ├── background/
│   ├── content/
│   ├── popup/
│   ├── extractors/
│   ├── transport/
│   ├── storage/
│   ├── types/
│   └── utils/
│
├── public/
├── test/
├── manifest.json
├── package.json
├── tsconfig.json
└── vite.config.ts
```

The browser extension responsibilities are limited to:

```text
access FLM using the user's current browser session
read FLM DOM or available network data
extract source data
perform basic validation
create transport package
export/send the package to the desktop application
```

The browser extension must NOT contain:

```text
knowledge graph algorithms
prerequisite traversal
RAG logic
LLM logic
study recommendation logic
Obsidian Markdown generation
complex academic normalization
```

Keep FLM-specific selectors and page extraction logic isolated under:

```text
src/extractors/
```

so future FLM website changes affect as little code as possible.

---

# 9. Packages

Create the following packages:

```text
packages/
├── domain/
├── flm_core/
├── knowledge_graph/
├── obsidian_core/
├── rag_core/
└── shared/
```

---

# 10. Domain package

Create:

```text
packages/domain/
```

Responsibility:

Represent the core academic domain independent of:

```text
Flutter
browser APIs
SQLite
filesystem
HTTP
LLM providers
backend APIs
```

Prepare architecture for entities such as:

```text
Program
Curriculum
Semester
Course
Syllabus
Topic
LearningOutcome
Assessment
Material
Prerequisite
```

Domain models should not depend on infrastructure.

Do not duplicate canonical domain concepts inside individual UI features unless the feature genuinely owns a different model.

---

# 11. FLM core package

Create:

```text
packages/flm_core/
```

Responsibility:

Handle the boundary between FLM source data and canonical academic data.

Suggested structure:

```text
src/
├── raw/
├── normalized/
├── mappers/
├── validators/
├── diff/
└── versioning/
```

Conceptual flow:

```text
RawFlmData
    ↓
Validator
    ↓
Normalizer / Mapper
    ↓
Canonical Academic Data
```

Raw FLM representation must remain separate from normalized domain representation.

Do not couple normalized academic models to current FLM HTML structure.

Prepare architecture for change detection and versioning, but do not implement advanced logic yet.

---

# 12. Knowledge Graph package

Create:

```text
packages/knowledge_graph/
```

This is a core module.

Suggested structure:

```text
src/
├── models/
├── relations/
├── builders/
├── traversal/
├── queries/
├── validators/
└── serialization/
```

Prepare core abstractions such as:

```text
GraphNode
GraphEdge
KnowledgeGraph
```

Official relations may eventually include:

```text
OFFICIAL_PREREQUISITE_OF
COREQUISITE_OF
BELONGS_TO_PROGRAM
BELONGS_TO_SEMESTER
HAS_SYLLABUS
TEACHES_TOPIC
HAS_LEARNING_OUTCOME
ASSESSED_BY
```

Inferred relations may eventually include:

```text
RELATED_TO
RECOMMENDED_BEFORE
CONCEPT_DEPENDS_ON
SIMILAR_TO
```

These relation categories must remain distinguishable.

Graph edges should eventually support metadata such as:

```text
source
confidence
evidence
createdAt
updatedAt
```

The graph package must not assume Neo4j or another graph database.

The initial project should remain compatible with lightweight local persistence such as SQLite.

---

# 13. Obsidian Core package

Create:

```text
packages/obsidian_core/
```

Suggested structure:

```text
src/
├── markdown/
├── frontmatter/
├── links/
├── vault/
├── generators/
└── models/
```

Responsibility:

Convert canonical academic knowledge into Obsidian-compatible Markdown.

Example links:

```text
[[PRM393]]
[[PRO192]]
[[Object Oriented Programming]]
```

The module must distinguish generated content from user-owned content.

Architect the system so future FLM updates cannot accidentally erase personal notes.

Do not implement full Markdown generation yet.

---

# 14. RAG Core package

Create:

```text
packages/rag_core/
```

Suggested structure:

```text
src/
├── documents/
├── chunking/
├── embeddings/
├── retrieval/
├── ranking/
└── interfaces/
```

Only create architecture and interfaces.

Do not integrate OpenAI, Gemini, or another provider yet.

Keep providers replaceable.

The future RAG layer should be capable of combining:

```text
semantic retrieval
+
knowledge graph traversal
```

---

# 15. Shared package

Create:

```text
packages/shared/
```

Only place genuinely cross-cutting utilities here.

Possible examples:

```text
IDs
Result types
common errors
logging interfaces
serialization primitives
```

Do NOT make `shared` a dumping ground.

Do not create vague folders such as:

```text
misc/
stuff/
helpers2/
common_stuff/
temp/
```

---

# 16. Cross-application schemas

Create:

```text
schemas/
```

This directory contains language-neutral contracts shared between:

```text
browser extension
desktop app
future backend
```

Prepare placeholders such as:

```text
course.schema.json
syllabus.schema.json
curriculum.schema.json
graph-node.schema.json
graph-edge.schema.json
course-package.schema.json
```

Transport packages should eventually contain metadata similar to:

```json
{
  "schemaVersion": "1.0",
  "source": "FLM",
  "exportedAt": "...",
  "data": {}
}
```

Do not couple extension and Flutter through implementation-specific models.

They communicate using contracts.

---

# 17. Future backend

Create only:

```text
services/README.md
```

Do NOT create an actual backend service yet.

Explain that future services may live under:

```text
services/api/
services/indexer/
services/worker/
```

Current functionality must not depend on `services/`.

The local-first architecture must continue functioning without backend connectivity.

---

# 18. Samples

Create:

```text
samples/
```

Prepare directories for future development samples:

```text
samples/
├── raw_flm/
├── normalized/
└── transport_packages/
```

Do not populate them with fabricated production data.

Only add example README files if useful.

---

# 19. Tests

Use local test folders near their modules.

Also keep:

```text
tests/
```

for repository-level integration and end-to-end tests.

Future important tests will include:

```text
FLM source
→ expected extracted representation
```

```text
raw data
→ expected normalized academic model
```

```text
normalized curriculum
→ expected prerequisite graph
```

```text
updated syllabus
→ correct affected graph rebuild
```

```text
FLM update
→ user notes remain unchanged
```

Do not create meaningless placeholder tests purely for test count.

---

# 20. Documentation

Create:

```text
docs/
├── architecture/
├── data-model/
├── flows/
└── decisions/
```

Create lightweight starter documents:

```text
docs/architecture/
├── overview.md
├── repository-structure.md
└── module-boundaries.md
```

```text
docs/data-model/
├── academic-domain.md
├── knowledge-graph.md
└── prerequisite-graph.md
```

```text
docs/flows/
├── flm-import-flow.md
└── update-flow.md
```

```text
docs/decisions/
├── README.md
├── ADR-0001-monorepo.md
├── ADR-0002-local-first.md
└── ADR-0003-knowledge-graph.md
```

Use lightweight ADRs.

---

# 21. Dependency rules

Document these boundaries clearly.

Allowed conceptual dependency direction:

```text
Desktop UI
   ↓
Application / Feature Layer
   ↓
Domain / Core Packages
```

Infrastructure implements domain-facing abstractions.

Never allow:

```text
domain → Flutter UI
domain → SQLite
domain → browser APIs
domain → OpenAI SDK
domain → filesystem implementation
```

The extension must not depend directly on Flutter source code.

The desktop app must not depend directly on extension internals.

Both may depend on shared contracts.

Avoid circular dependencies.

---

# 22. Storage boundaries

Do not implement storage yet, but prepare for local storage responsibilities.

Conceptually separate:

```text
Source Storage
Derived Storage
User Storage
```

Possible future structure:

```text
local_data/
├── source/
├── derived/
└── user/
```

Do not hardcode this exact physical structure if a cleaner implementation later emerges.

The important requirement is ownership separation.

---

# 23. Stable identity

Prepare the architecture for stable IDs.

Do not make human-readable titles the sole identity of academic entities.

Examples:

```text
course:PRM393
course:PRO192
course:PRM393:clo:1
```

Renaming a course must not break graph relations.

Do not implement an elaborate global ID framework yet.

---

# 24. Naming conventions

Use explicit domain terminology.

Examples of good names:

```text
FlmCourseExtractor
CourseNormalizer
PrerequisiteGraphBuilder
MarkdownNoteGenerator
CourseImportService
```

Avoid vague names such as:

```text
Manager
Helper
Processor
Thing
CommonUtil
DataHandler
```

unless the responsibility is genuinely narrow and clear.

Use:

```text
snake_case for Dart files
kebab-case or conventional TypeScript naming where appropriate
PascalCase for classes/types
```

---

# 25. Root README

Create a clean `README.md` containing:

```text
Project Overview
Current Scope
Architecture
Repository Structure
Module Responsibilities
Data Flow
Local-first Principles
Development Setup
Future Roadmap
```

Include a high-level architecture diagram in plain Markdown text:

```text
FPT FLM
   ↓
Browser Extension
   ↓
Transport Contract
   ↓
Flutter Desktop
   ↓
Validation / Normalization
   ↓
Canonical Academic Model
   ↓
Knowledge Graph
   ├── Prerequisite Graph
   └── Academic Relations
   ↓
Local Storage
   ├── Source Data
   ├── Derived Data
   └── User Data
   ↓
Markdown / Search / RAG
   ↓
LLM-assisted Features
```

---

# 26. Do not overengineer

Do NOT introduce:

```text
microservices
Docker
Kubernetes
Redis
Kafka
RabbitMQ
Neo4j
cloud infrastructure
authentication system
backend APIs
event sourcing
CQRS
complex dependency injection frameworks
```

at this stage.

This is currently a university project developed by a small team.

The repository should be professional but understandable.

Prefer:

```text
clear boundaries
simple dependencies
explicit ownership
small modules
```

over unnecessary enterprise patterns.

---

# 27. Important implementation rule

This task is ONLY for establishing repository architecture.

Do not implement:

```text
FLM crawling
course parsing
knowledge graph algorithms
SQLite database
LLM integration
RAG
Markdown generation
localhost communication
backend services
```

yet.

Minimal bootstrapping files required for Flutter and TypeScript projects are acceptable.

Do not generate hundreds of empty files.

Do not create one interface per hypothetical future class.

Only scaffold structures that provide immediate architectural value.

---

# 28. Expected final result

After scaffolding the repository, provide:

1. The complete final directory tree.
2. A concise explanation of every top-level directory.
3. Module responsibility boundaries.
4. Dependency direction.
5. Important architectural decisions.
6. Any assumptions made.
7. Any folders you deliberately did NOT create and why.

Before finishing, inspect the resulting structure and remove unnecessary boilerplate or meaningless empty directories.

The final repository should be:

```text
clean
minimal
understandable
extensible
local-first
backend-ready
```

without being overengineered.
