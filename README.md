# Obsidian_FLM

## Project Overview

Obsidian_FLM is a local-first academic knowledge workspace for FPT University's FLM data. It combines a Manifest V3 browser extension for extraction with a Flutter desktop application for importing and exploring academic knowledge.

## Current Scope

This repository contains architecture and minimal project bootstraps only. Crawling, persistence, graph algorithms, Markdown generation, retrieval, and LLM features are intentionally not implemented.

## Architecture

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

## Repository Structure

- `apps/desktop`: independently buildable Flutter desktop application.
- `apps/extension`: independently buildable TypeScript Manifest V3 extension.
- `packages`: framework-independent domain and processing modules.
- `schemas`: language-neutral interchange contracts.
- `services`: documentation for optional future backend services.
- `docs`: architecture, data-model, flow, and decision records.
- `scripts`: future repository automation with narrow purposes.
- `samples`: non-production fixtures.
- `tests`: repository-level integration and end-to-end tests.

## Module Responsibilities

The desktop owns UI and application orchestration. The extension owns session-aware FLM extraction and transport export. `domain` owns canonical concepts; `flm_core` maps source representations; `knowledge_graph` owns graph abstractions; `obsidian_core` owns vault boundaries; `rag_core` owns provider-neutral retrieval interfaces; and `shared` contains only cross-cutting primitives.

See [module boundaries](docs/architecture/module-boundaries.md).

## Data Flow

FLM data is extracted into a versioned transport contract, imported, validated, normalized, and used to build derived artifacts. Updates compare incoming source data and rebuild only affected derived data. User-owned data remains outside replacement paths.

## Local-first Principles

- Source, derived, and user data have separate ownership.
- Official facts and inferred relations remain distinguishable.
- Contracts carry schema version and provenance metadata.
- Stable IDs, content hashes, and atomic replacement are planned boundaries.
- Core functionality must remain usable without backend connectivity.

## Development Setup

The desktop requires Flutter with desktop support; the extension requires Node.js and npm. Toolchain commands will be finalized with the first implementation milestone. Each app is independently buildable from its directory.

## Future Roadmap

1. Finalize cross-application schemas.
2. Implement FLM extraction and file transport.
3. Add normalization and local persistence.
4. Build official and inferred graph pipelines.
5. Add protected Markdown generation and local search.
6. Introduce provider-neutral RAG and optional LLM integrations.
7. Consider optional backend services without weakening local-first operation.
