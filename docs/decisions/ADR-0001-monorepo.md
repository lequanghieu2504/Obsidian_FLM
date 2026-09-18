# ADR-0001: Use a monorepo

- Status: Accepted
- Date: 2026-09-18

## Decision

Keep independently buildable desktop and extension applications with shared packages, contracts, documentation, and integration tests in one repository.

## Consequences

Contract changes are visible and coordinated while application internals remain isolated. Build tooling must not force either application to depend on the other.
