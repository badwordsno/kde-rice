# Architecture and entry points

Minimalist Black uses the running Plasma shell, native panel APIs, and project
QML widgets. It does not provide a replacement compositor or shell process.

## Normal user workflow

| Command | Responsibility |
| --- | --- |
| `scripts/doctor` | Read-only capability and topology diagnosis |
| `scripts/bootstrap` | Complete change preview; explicit `--apply` captures the baseline and executes the plan |
| `scripts/verify` | Read-only validation of the exact final target |
| `scripts/restore` | Preview or restore complete managed files from the recorded snapshot |

Bootstrap prints the exact final verification target and recovery commands.
Follow those commands rather than assembling a migration manually. A failed
Opaque-checkpoint receipt is continued with `resume-bootstrap`, using the
original snapshot; it is not a new bootstrap transaction.

## Implementation boundaries

- `config/managed-paths.txt` defines the exact live file boundary.
- `scripts/lib/common.sh` holds path, lock, snapshot, and component diagnosis
  helpers. Each component still owns its topology checks and rollback.
- `design/panel/v04.json` owns the widget IDs and sequences shared by the five
  core v0.4 migration scripts. `scripts/sync-panel-contract` checks or generates
  their constant blocks; observation, mutation, and validation remain separate.
- `layouts/plasma/org.kde.minimalist-v04/` contains the current panel contract
  and its specialized preflight, mutation, and postcheck scripts.
- The `v02` and `v03` layouts and apply commands are migration components used
  by bootstrap. Their IDs, destination paths, and receipt values remain stable
  so existing snapshots and failed transactions stay recoverable.
- Clock, font, Pager, and Workspaces commands are targeted maintenance tools;
  they are not alternate installation entry points.
- `plasmoids/` contains three self-contained packages. `design/chimera/` is the
  authored source of their shared visual components; generated package copies
  are checked for byte equality.

Historical topology IDs are separate from the product version in `VERSION`.
Renaming the product or release archive must not rename installed widget IDs,
managed paths, or transaction metadata. A broader topology-definition refactor
must preserve independent post-apply checks, not make verification replay the
same mutation logic.

## Build and evidence

`scripts/build-release` produces one source archive and checksums through
`scripts/build-source-release`. `release/source-manifest.txt` is the exact
public file allowlist. Git history and private recovery material are excluded.
`scripts/check-release` tests the candidate, compares two builds, and tests the
extracted source. Native-session acceptance remains a separate release gate.

Restore is file-level recovery: newer settings in the same managed file are
also returned to the baseline. Displaced current files are retained for
recovery. It is not a setting-by-setting merge.
