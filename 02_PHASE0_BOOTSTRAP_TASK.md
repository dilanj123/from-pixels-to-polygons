# From Pixels to Polygons — Phase 0 Bootstrap Task

Use only after the Master Project Plan and ChatGPT Operating Instructions have been accepted.

## Objective

Establish the real local environment and create the repository skeleton without implementing graphics/raster RTL.

## Required actions

1. Inspect:
   - `uname -a`;
   - architecture;
   - macOS version;
   - current directory;
   - existing `from-pixels-to-polygons` repository if present.

2. If repository does not exist:
   - create it;
   - initialize Git;
   - use `main`.

3. Configure repository-local Git identity only from identity explicitly supplied by the user/project contract.

4. Run `gh auth status`.
   - If unauthenticated, stop before remote creation.
   - State the exact user authentication action required.
   - Never request/store credentials.

5. Create skeleton:

```text
.github/workflows/
rtl/
ip/
third_party/
sw/host/
sw/reference/
tb/drivers/
tb/monitors/
tb/tests/
tb/images/
formal/
constraints/
scripts/sim/
scripts/formal/
scripts/synth/
scripts/timing/
scripts/analysis/
reports/
results/raw/
results/processed/
docs/assets/
docs/debug/
examples/
```

6. Add placeholders:

```text
README.md
docs/REQUIREMENTS.md
docs/MICROARCHITECTURE.md
docs/COMMAND_PROTOCOL.md
docs/FIXED_POINT.md
docs/VERIFICATION_PLAN.md
docs/FORMAL.md
docs/TIMING.md
docs/TRADEOFFS.md
docs/DECISIONS.md
docs/KNOWN_LIMITATIONS.md
docs/PROJECT_STATE.md
docs/EVIDENCE_INDEX.md
docs/THIRD_PARTY_MANIFEST.md
THIRD_PARTY_NOTICES.md
AGENTS.md
Makefile
pyproject.toml
.gitignore
LICENSE
```

7. Detect exact executable paths/versions for at least:

```text
git
gh
python3
make
verilator
yosys
sby
nextpnr-ecp5
```

Also discover available formal solvers.

8. Detect, but do not yet require/install automatically, board/programming utilities that may later matter for ULX3S/ECP5.

9. Do not install large dependencies automatically.
   - Report missing tools first.

10. Create `make doctor`.
    - Print path/version.
    - Distinguish mandatory/optional.
    - Return non-zero when a specifically requested core workflow cannot run.

11. Smoke-check Makefile/doctor.

12. Make one bootstrap commit if requested by the project workflow.

13. If GitHub CLI is authenticated and remote creation is requested/authorized:
    - create public `from-pixels-to-polygons`;
    - use agreed description;
    - push `main`.

14. Do **not** yet:
    - implement raster RTL;
    - import RasterIX/Raster I code;
    - import Project F files;
    - add `rtl-to-pixels` dependency;
    - buy hardware;
    - install large EDA bundles without review.

15. Return exact evidence:
    - repo URL if created;
    - branch;
    - commit;
    - git status;
    - commands executed;
    - exit codes;
    - tool paths/versions;
    - missing dependencies;
    - failures/warnings.

## Acceptance criteria

Phase 0 is complete only when:

- repository state is known;
- actual tool paths/versions are recorded;
- `make doctor` runs as designed;
- no graphics RTL has been added;
- Git status is known;
- any missing tool/hardware dependency is explicitly documented rather than guessed.

## Prohibitions

- no rasterizer RTL;
- no copied third-party graphics core;
- no architecture changes;
- no fabricated output;
- no destructive Git commands;
- no credential handling;
- no unreviewed large dependency installation;
- no hardware purchase recommendation without current research and explicit project need.
