# Evidence index

## GFX-000 bootstrap

| Claim | Git commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Intended repository was absent before bootstrap | pending | filesystem inspection under `/Users/Dilan` | exact project directory not found | DERIVED |
| Host is macOS 26.4.1 on arm64 | pending | `sw_vers`, `uname -a`, `arch` | local host at bootstrap time | DERIVED |
| Required executable states recorded | pending | environment inspection and `make doctor` | future-phase EDA tools may be missing | DERIVED |
| Admitted dependency metadata is pinned | pending | `docs/PROJECT_STATE.md` | no source import; no parent modification | SPECIFIED |
| No graphics implementation HDL added | pending | `make bootstrap-smoke`, file inspection | bootstrap scope only | DERIVED |

No functional, formal, synthesis, timing, hardware, or performance claim is
entered by GFX-000.
