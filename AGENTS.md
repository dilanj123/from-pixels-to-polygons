# Repository operating rules

- Treat `00_MASTER_PROJECT_PLAN.md`, `01_CHATGPT_PROJECT_OPERATING_INSTRUCTIONS.md`,
  the finalized `docs/*` contracts, and `04_MASTER_CHECKLIST.md` as authoritative
  in that order.
- Preserve evidence classifications. Do not claim tests, formal proof, synthesis,
  timing, hardware, or performance results without command output.
- GFX-001 is documentation/specification only. Do not add graphics RTL, a
  reference renderer, synthesis experiments, hardware support, or the
  RTL-to-Pixels production RTL.
- Keep the admitted dependency metadata exact and pinned; do not modify the
  upstream repository.
- The admitted dependency is `v1.0.1-dependency-ready` at commit
  `ad35514c990f6e1c9eb9fa18aee9d906f9df7721`, selected top
  `rtl_to_pixels_top_pipelined`. Future consumers must verify this immutable
  boundary before importing it.
