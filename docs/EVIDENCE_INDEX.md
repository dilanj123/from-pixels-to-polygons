# Evidence index

## GFX-001 source-level contract evidence

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| D-001–D-028 are recorded | `111fe6f9bc7116f7007aaf89e781ddd3d8871f42` | `docs/DECISIONS.md` and cross-document review | specified source input only | SPECIFIED |
| Exact dependency is admitted | `111fe6f9bc7116f7007aaf89e781ddd3d8871f42` | `docs/PROJECT_STATE.md`, `docs/REQUIREMENTS.md` | URL/tag/commit/top exact; no source import | SPECIFIED |
| Gate numbering is canonical | `111fe6f9bc7116f7007aaf89e781ddd3d8871f42` | Master Plan and `04_MASTER_CHECKLIST.md` review | Gate 0–12 mapping from D-001 | SPECIFIED |
| Requirement-to-verification coverage is planned | `111fe6f9bc7116f7007aaf89e781ddd3d8871f42` | `docs/VERIFICATION_PLAN.md` | planned methods only; no tests run | SPECIFIED |
| Combined memory feasibility is a hard early gate | `111fe6f9bc7116f7007aaf89e781ddd3d8871f42` | Master Plan, checklist, GFX-004, microarchitecture | actual resource evidence still required | SPECIFIED |
| No graphics implementation was added | `111fe6f9bc7116f7007aaf89e781ddd3d8871f42` | file scan and allowed-file review | documentation-only task | LOCAL OBSERVATION |

## Gate-0 closure milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Gate 0 is closed | `ca915a918c85bfe3e85602d6a93e4644c74f3cfd` | final Gate-0 review, `make doctor`, `make bootstrap-smoke`, clean repository audit | missing future tools are documented prerequisites, not Gate-0 blockers | SPECIFIED / LOCAL OBSERVATION |
| GFX-000 and GFX-001 are accepted | `ca915a918c85bfe3e85602d6a93e4644c74f3cfd` | `docs/PROJECT_STATE.md`, accepted task evidence | no later gate implied | SPECIFIED |
| Tool availability and missing states are known | `ca915a918c85bfe3e85602d6a93e4644c74f3cfd` | `make doctor` | no tool installation performed | LOCAL OBSERVATION |

## Dependency record

```text
Repository: https://github.com/dilanj123/from-rtl-to-pixels.git
Tag: v1.0.1-dependency-ready
Commit: ad35514c990f6e1c9eb9fa18aee9d906f9df7721
Selected top: rtl_to_pixels_top_pipelined
```

The parent record is an immutable dependency boundary, not graphics
implementation, simulation, synthesis, timing, or hardware evidence.

## Evidence deliberately absent

No reference-model, RTL simulation, formal, synthesis, timing, P&R, physical
framebuffer, display, resource-count, Fmax, or performance claim is entered by
GFX-001.
