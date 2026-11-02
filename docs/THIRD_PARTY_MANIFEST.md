# Third-party manifest

| Component | Repository / revision | Imported path | License / copyright | Modifications / purpose |
|---|---|---|---|---|
| Project F 640×480 timing | `projf/projf-explore`, commit `dd212c2e5e0e0d8bdcf93ba077630dbfd49ae708` | `third_party/projectf/lib/display/display_480p.sv` (SHA-256 `729b2a634735651925e37b02e3e51db035d149d035340c1c237c87e27ad68e50`) | MIT; source header ©2022 Will Green; pinned root license ©2023 Will Green, Project F (`third_party/projectf/LICENSE`) | Unmodified generic timing source used by GFX-015 scanout; no vendor primitives. |

| From RTL to Pixels accelerator | `dilanj123/from-rtl-to-pixels`, tag `v1.0.1-dependency-ready`, commit `ad35514c990f6e1c9eb9fa18aee9d906f9df7721` | `ip/rtl-to-pixels` (submodule pointer only) | Upstream `COPYRIGHT.md`: Copyright ©2026 Dilan Jayasena, all rights reserved; no permissive licence or general reuse permission stated | Parent RTL remains unmodified in the upstream repository. Local contract and parameterized verification only; superproject records URL+commit, no vendored code. Source redistribution/downstream use permission remains UNESTABLISHED and requires explicit authorization. |

The submodule points to the exact admitted immutable revision. Recording a
pointer does not grant rights to copy, modify, redistribute, or ship upstream
source. No such rights are claimed by this project.
