# Third-party manifest

| Component | Repository / revision | Imported path | License / copyright | Modifications / purpose |
|---|---|---|---|---|
| Project F 640×480 timing | `projf/projf-explore`, commit `dd212c2e5e0e0d8bdcf93ba077630dbfd49ae708` | `third_party/projectf/lib/display/display_480p.sv` (SHA-256 `729b2a634735651925e37b02e3e51db035d149d035340c1c237c87e27ad68e50`) | MIT; source header ©2022 Will Green; pinned root license ©2023 Will Green, Project F (`third_party/projectf/LICENSE`) | Unmodified generic timing source used by GFX-015 scanout; no vendor primitives. |

The admitted `from-rtl-to-pixels` dependency remains an external immutable
baseline; its production RTL is not present in this repository.
