# ADR-0002: Local-first data ownership

- Status: Accepted
- Date: 2026-09-18

## Decision

Core functionality and data remain local. Source, derived, and user data have distinct ownership and update rules.

## Consequences

The product works without backend connectivity. Refresh operations can replace source and derived artifacts but must preserve user data. Optional future services remain adapters, not prerequisites.
