# Architecture overview

Obsidian_FLM is a local-first monorepo with two independently buildable applications. The extension exports FLM source data through language-neutral contracts. The desktop validates and normalizes imports, coordinates local persistence, and presents derived knowledge. Framework-independent packages hold reusable domain and processing responsibilities.

Storage ownership is conceptual, not yet a hardcoded filesystem layout: source data is replaceable FLM evidence, derived data is reproducible, and user data is durable and never overwritten by source refreshes.
