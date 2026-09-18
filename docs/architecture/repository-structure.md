# Repository structure

`apps/` contains deployable clients; `packages/` contains framework-independent modules; `schemas/` is the interoperability boundary; `services/` is reserved for documented future options; `docs/` records architecture; `samples/` holds safe fixtures; `scripts/` holds purposeful automation; and root `tests/` covers cross-module behavior.

Local tests remain beside their owner. Directories are preserved only when they communicate a current architectural boundary.
