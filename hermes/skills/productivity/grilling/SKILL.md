---
name: grilling
description: "Use when requirements need alignment before execution."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [requirements, alignment, design, scope]
    related_skills: [plan, systematic-debugging]
---

# Grilling

Turn an underspecified request into an executable brief without silently guessing.

## Process

1. State the current understanding and list decisions that could change implementation. Done when the user can confirm or correct scope.
2. Ask only the highest-value question next. Cover goal, non-goals, constraints, interfaces, failure behavior, and acceptance criteria. Done when every implementation-changing branch has an answer or an explicit assumption.
3. Maintain a compact decision record using the user's vocabulary. Done when no unresolved contradiction remains.
4. Produce an execution brief: goal, non-goals, decisions, affected surfaces, verification, and assumptions. Done when another agent could execute without inventing requirements.

## Rules

- Do not implement while requirements are still branching.
- Do not ask questions whose answers can be discovered from the repository or documentation.
- Stop once additional answers would not change implementation or verification.
- If immediate execution is requested, record assumptions explicitly and choose the smallest reversible interpretation.

## Completion Checklist

- [ ] Goal and non-goals are explicit
- [ ] Scope-changing decisions are resolved
- [ ] Acceptance checks are observable
- [ ] Assumptions are labeled
- [ ] Execution brief is ready
