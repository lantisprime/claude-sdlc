# Plan: <task-slug>

- **Task ID:** <slug or ticket reference>
- **Classification:** new-build | fix | change-request
- **Reference:** REQ-xxx | ISSUE-xxx | CR-xxx
- **Author:** <name>
- **Created:** <YYYY-MM-DD>
- **Version:** 1
- **Status:** draft | signed | superseded
- **Estimate:** <S/M/L/XL or story points>

## Problem

<One or two sentences. What is broken or missing?>

## Scope statement alignment

- Section of `.claude/sdlc/scope.md`: <x.y>
- In-scope? yes | no (if no, this is a scope-delta → human decision required)

## In-scope files

- path/to/file_a.ext
- path/to/file_b.ext

## In-scope functions

- `path/to/file_a.ext::function_one`
- `path/to/file_a.ext::function_two`
- `path/to/file_b.ext::ClassName.method`

## Out-of-scope (do NOT touch)

- path/to/adjacent_file.ext
- `path/to/file_a.ext::unrelated_helper`

## Approach

- Step 1 — …
- Step 2 — …
- Step 3 — …

## Tests to add or update

- Unit test for `function_one` — covers REQ-001 via TC-012
- Unit test for `ClassName.method` — covers REQ-002 via TC-013

## Technology stack & compatibility

| Component | Current / Proposed | Compatibility |
|-----------|--------------------|---------------|
| Language  | <py 3.12>          | ✓             |
| Framework | <fastapi 0.110>    | ✓             |
| Data      | <postgres 15>      | ✓             |
| Auth      | <existing IdP>     | ✓             |

## Risks & rollback

- Risk: …
- Mitigation: …
- Rollback: revert commit <SHA> / feature-flag off / migration down

## Clarifications (if `scoping` skill ran)

- Q: …
- A: …
