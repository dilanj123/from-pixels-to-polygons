# Repository operating rules

- Treat `00_MASTER_PROJECT_PLAN.md`, `01_CHATGPT_PROJECT_OPERATING_INSTRUCTIONS.md`,
  the finalized `docs/*` contracts, and `04_MASTER_CHECKLIST.md` as authoritative
  in that order.
- Preserve evidence classifications. Do not claim tests, formal proof, synthesis,
  timing, hardware, or performance results without command output.
- GFX-000 is bootstrap only. Do not add graphics RTL, a reference renderer,
  synthesis experiments, hardware support, or the RTL-to-Pixels production RTL.
- Keep the admitted dependency metadata exact and pinned; do not modify the
  upstream repository.
