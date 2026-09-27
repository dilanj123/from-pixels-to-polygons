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

## GFX-002 primitive milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Independent fixed-point/raster primitives pass focused tests | `268c04680cae0c5f17d268c54faa4f5cc960b64b` | `python3 -m unittest discover -s sw/reference -p 'test_*.py' -v` | 19 tests passed; no full framebuffer/Z renderer | REFERENCE-MODEL VERIFIED |
| Signed42 attribute bound is satisfied | `268c04680cae0c5f17d268c54faa4f5cc960b64b` | `DerivationTests.test_signed42_attribute_bound` | mathematical bound only | DERIVED |
| No functional graphics RTL was added | `268c04680cae0c5f17d268c54faa4f5cc960b64b` | functional HDL scan and bootstrap smoke check | RTL/reference primitive scope only | LOCAL OBSERVATION |

GFX-002 does not claim a complete reference renderer, framebuffer/Z behavior,
RTL simulation, formal, synthesis, timing, or hardware evidence.

## GFX-003 complete reference-renderer milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Quantized command parser/encoder and frame reference pass | `6a9dbe1c4eaa71697ca2a13db3892bc93116eb3b` | `python3 -m unittest discover -s sw/reference -p 'test_*.py' -v` | 31 tests passed, including all 19 GFX-002 tests | REFERENCE-MODEL VERIFIED |
| Fixed-seed regression is repeatable | `6a9dbe1c4eaa71697ca2a13db3892bc93116eb3b` | standalone two-run `random_regression` command | seeds 1, 7, 42; identical framebuffer/Z hashes | REFERENCE-MODEL VERIFIED |
| Gate-1 reference-model requirements are evidenced | `6a9dbe1c4eaa71697ca2a13db3892bc93116eb3b` | directed tests, multi-triangle frame, empty frame, depth/order tests | no RTL or hardware claim | REFERENCE-MODEL VERIFIED |

### GFX-003 random regression records

| Seed | Framebuffer SHA-256 | Z-buffer SHA-256 |
|---:|---|---|
| 1 | `f5be4ccae05fe568fbca3a12102ad03344636f90d2898f90caa6cfc55e9ac7eb` | `e29287f671fb7c0855a121f9c7f1bdf324922242f7ab47454e3375d5a6af7` |
| 7 | `c3891205ae7eaaa4be78267d6f0e15245c16f55bec767fa96c1ffb5007771f72` | `44883795c9dbeb15059834fbd4e84d26d3d3d8a3cccd690a73e5cf9488f7bae4` |
| 42 | `8ff44bcb78e1a5c7518867f0ed7be6c184c7a4690799597a8c09384a65366472` | `df8ae0a8c1152f0b82b8f9ff6172e6b20af58cb3a2152600e479161196b60cca` |

The seed records were identical across two independent executions. Hashes are
regression conveniences; later RTL comparison remains byte-level.
