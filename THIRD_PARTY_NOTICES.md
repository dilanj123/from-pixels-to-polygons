# Third-party notices

## Project F ECP5 clock and DVI support

- Repository: <https://github.com/projf/projf-explore>
- Commit: `dd212c2e5e0e0d8bdcf93ba077630dbfd49ae708`
- Imported unmodified: `lib/clock/ecp5/clock2_gen.v`,
  `lib/display/ecp5/dvi_generator.sv`, `lib/display/tmds_encoder_dvi.sv`, and
  `graphics/fpga-graphics/ecp5/ulx3s.lpf`, under matching paths in
  `third_party/projectf/`.
- Copyright: ©Will Green. Licence: MIT; see `third_party/projectf/LICENSE`.
- Purpose: ECP5 PLL wrapper, DVI/TMDS encoder and serializer, and reference
  ULX3S clock/reset/GPDI assignments. No Xilinx serializer/PLL or unrelated
  Project F example design was imported.

## ULX3S FTDI pin reference

- Repository: <https://github.com/emard/ulx3s>
- Commit: `6a92cec6b177191c5b0f80e260013a1f8ec147dd`
- Source: `doc/constraints/ulx3s_v20.lpf`; only FTDI pins were transcribed to
  `constraints/ulx3s_ftdi.lpf`.
- Source `LICENSE.md` is recorded in the manifest, including its board
  silkscreen logo condition. No logo or board artwork was copied.
- The v2.x.x/v3.0.x board match is an assumption, not physical confirmation.

## Project F `display_480p.sv`

- Repository: <https://github.com/projf/projf-explore>
- Commit: `dd212c2e5e0e0d8bdcf93ba077630dbfd49ae708`
- File: `lib/display/display_480p.sv`
- Local path: `third_party/projectf/lib/display/display_480p.sv`
- File SHA-256: `729b2a634735651925e37b02e3e51db035d149d035340c1c237c87e27ad68e50`
- Copyright in source header: ©2022 Will Green
- License: MIT; accompanying pinned root license copied to
  `third_party/projectf/LICENSE` (Copyright ©2023 Will Green, Project F).
- Changes: none; imported byte-for-byte for generic display timing.

## From RTL to Pixels dependency

- Repository: <https://github.com/dilanj123/from-rtl-to-pixels>
- Tag/commit: `v1.0.1-dependency-ready` / `ad35514c990f6e1c9eb9fa18aee9d906f9df7721`
- Local path: `ip/rtl-to-pixels` (Git submodule pointer; detached at the pinned commit)
- Selected top for the specified interface: `rtl_to_pixels_top_pipelined`, `IMG_WIDTH=320`, `IMG_HEIGHT=240`
- Copyright/status: upstream `COPYRIGHT.md` says Copyright ©2026 Dilan Jayasena, all rights reserved. It allows viewing for evaluation and educational review; it grants no general copying, modification, redistribution, publication, sublicensing, or use in another project.
- Licence: no permissive licence is supplied. This project does not claim MIT or other reuse rights.
- Local treatment: source remains unmodified in its own repository; no parent RTL has been copied into this project. Local contract inspection and verification were performed against the pinned checkout.
- Distribution boundary: the superproject records only the submodule URL and commit. Permission for source redistribution or downstream product use is not established; obtain explicit authorization before such use.
