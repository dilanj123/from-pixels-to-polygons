# Evidence index

## GFX-000 bootstrap

| Claim | Git commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Intended repository was absent before bootstrap | `7beabb84a5f66a1f2cba252f3e88cf0647102cf2` | filesystem inspection under `/Users/Dilan` | exact project directory not found before creation | DERIVED |
| Host is macOS 26.4.1 on arm64 | `7beabb84a5f66a1f2cba252f3e88cf0647102cf2` | `sw_vers`, `uname -a`, `arch` | local host at bootstrap time | DERIVED |
| Required executable states recorded | `7beabb84a5f66a1f2cba252f3e88cf0647102cf2` | environment inspection and `make doctor` | future-phase EDA tools may be missing | DERIVED |
| Admitted dependency metadata is pinned | `7beabb84a5f66a1f2cba252f3e88cf0647102cf2` | `docs/PROJECT_STATE.md` | exact repository URL, tag, commit, and selected top recorded; no source import; no parent modification | SPECIFIED |
| No graphics implementation HDL added | `7beabb84a5f66a1f2cba252f3e88cf0647102cf2` | `make bootstrap-smoke`, file inspection | bootstrap scope only; zero HDL files found | DERIVED |

No functional, formal, synthesis, timing, hardware, or performance claim is
entered by GFX-000.
