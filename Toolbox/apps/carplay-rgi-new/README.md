# CarPlay RGI New payload

This directory is for the supervisor-based deployment from `luka-dev/mib2q-carplay-rgi`.

Pinned upstream release for the initial integration:

- Release: `MHI2Q-2026-08-30`
- Deployment layout: `deploy/smartphone_integrator/`

The following text files are included from the upstream deployment layout:

- `carplay_startup.sh`
- `carplay_cleanup.sh`
- `carplay_processes.sh`
- `carplay_child.json`

The GitHub connector used to prepare this integration cannot transfer binary GitHub Release assets.
Before using the installer, place these four release binaries in this same directory:

| File | Size | SHA-256 |
| --- | ---: | --- |
| `carplay_hook.jar` | 178976 | `8031eb73009a8b09fb9c8663b6b08c64ed51cb966ee374cb74845c8090ab8d37` |
| `libcarplay_hook.so` | 300211 | `34dabdcfda933be6bbc8085414f31fe052dded4c0c4a1075e2ac1793dd0f162a` |
| `maneuver_render` | 121738 | `1004dc594a9f408793b91f69f75200ea71088e408caa3a9ed43bde4f6b517b30` |
| `flag_atlas.rgba` | 917504 | `b1985705eabcb0379bed9a5c0055694a4b3db7ac28cef29c57a9d7f2e619dd11` |

`install_carplay_rgi_new.sh` refuses to install if any required source file is missing or empty.

Backup and logs are stored under:

`Backup/${VERSION}/CarPlayRGI-new/`

The installer recognizes four production states:

- `CLEAN`: stock configuration; creates the immutable NEW stock backup and installs.
- `OLD`: legacy `carplay-rgi`; validates `Backup/${VERSION}/CarPlayRGI/`, restores stock, creates the NEW stock backup, then installs.
- `NEW`: supervisor-based installation; preserves the original NEW stock backup and overwrites/updates the NEW payload.
- `INVALID`: partial/mixed state; aborts without intentionally modifying production files.
