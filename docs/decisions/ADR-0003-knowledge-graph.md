# ADR-0003: Storage-agnostic knowledge graph

- Status: Accepted
- Date: 2026-09-18

## Decision

Model graph concepts independently of any graph database and explicitly categorize official versus inferred relations.

## Consequences

Lightweight local persistence remains possible. Every edge can carry provenance, evidence, confidence, and timestamps without allowing inferred relationships to masquerade as official facts.
