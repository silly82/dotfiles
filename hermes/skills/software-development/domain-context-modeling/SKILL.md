---
name: domain-context-modeling
description: "Use when project terms need shared context."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [domain, context, vocabulary, architecture, adr]
    related_skills: [plan, systematic-debugging, test-driven-development]
---

# Domain Context Modeling

Give the agent and user one shared language for a project. This reduces repeated explanation and prevents code, tests, and documentation from using competing meanings.

## Process

1. Inspect existing `CONTEXT.md`, `AGENTS.md`, `.hermes.md`, README files, schemas, and representative tests before inventing terminology. Done when existing vocabulary and rules are listed.
2. Extract only terms that affect implementation: entities, states, boundaries, identifiers, units, lifecycle events, and overloaded words. Done when each selected term has one concise definition and useful examples or counterexamples.
3. Record durable decisions as ADRs only when alternatives or tradeoffs matter. Include context, decision, consequences, and rejected alternatives. Done when a future agent can understand why the choice exists.
4. Use the vocabulary consistently in plans, code, tests, and reports. If a term conflicts with an existing term, resolve the conflict instead of silently renaming concepts.

## File Guidance

- Prefer a small `CONTEXT.md` at the project root for glossary and invariants.
- Store durable decisions in `docs/adr/` or the repository's existing ADR location.
- Do not copy facts already obvious from config, package metadata, or command help; document conventions and reasons that cannot be discovered cheaply.

## Completion Checklist

- [ ] Existing context sources were checked
- [ ] Terms are defined once and used consistently
- [ ] Ambiguities and units are explicit
- [ ] Relevant invariants are recorded
- [ ] ADRs exist only for decisions with meaningful alternatives
