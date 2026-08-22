# Testing Minimalist Black 1.0

All automated tests use temporary homes and mocked Plasma interfaces. They must
never redirect KDE applications to the real home.

Node.js and Qt 6 `qmllint` are test-harness dependencies only; no live runtime
script depends on them. Tests resolve `node` or `nodejs` from `PATH`, or an
executable absolute path from `KDE_RICE_TEST_NODE`. They resolve `qmllint`,
Fedora's `qmllint-qt6`, or `qmllint6` from `PATH`, or accept an executable
absolute path from `KDE_RICE_TEST_QMLLINT`. They resolve the Qt 6 import root
with `qtpaths6 --query QT_INSTALL_QML` before checking standard distribution
paths. `KDE_RICE_TEST_QML_IMPORT_PATH` may provide an existing absolute import
root for an isolated test runtime. A stock Fedora 44 Plasma installation may
omit the executable even when every live doctor capability passes. Missing
`qmllint` blocks the complete release suite but does not make a diagnosed live
apply unsupported. Installing its official-repository provider remains a
separately approved package action.

Keep two gates distinct:

- **Live readiness:** `scripts/doctor --target minimalist-v04`, bootstrap
  dry-run, and the observed topology/capability result. Test-only `qmllint`
  absence does not weaken or override doctor.
- **Repository release readiness:** every `tests/test-*.sh`, shell syntax,
  `qmllint` package checks, and `git diff --check`. Missing `qmllint` leaves this
  gate incomplete even when a live host is supported.

When reporting results, say which gate was evaluated. Do not summarize a
`qmllint`-blocked release suite as either a live doctor failure or a fully
passing repository suite.

## Complete candidate-checkout suite

```bash
set -e
for test_script in tests/test-*.sh; do
  bash "$test_script"
done
for shell_file in scripts/* scripts/lib/*.sh tests/*.sh tests/lib/*.sh; do
  [[ -f "$shell_file" ]] || continue
  bash -n "$shell_file"
done
git diff --check
```

The Extended archive intentionally has no `.git` directory. After extracting
it, rerun every contained `tests/test-*.sh` and every shell syntax check from
the block above, omitting only `git diff --check`. Run that Git check again
after the extracted source is initialized as the clean-history public
repository.

The suite covers:

- exact-path snapshot, restore, displaced state, legacy restore-only paths,
  path traversal, symlink escape, and display exclusions;
- the guarded clock-only dry run/apply, exact v0.4.1 topology and 32 px geometry,
  full-scope snapshot-before-write ordering, layout-only asset refresh,
  eight-key clock-policy idempotence, enum serialization compatibility,
  monospaced-font enforcement, and failure restore;
- the guarded Pager-preview dry run/apply, geometry-positioned insertion after
  the launcher, four-desktop one-row KWin state, numeric Pager policy,
  idempotence, exact-ID failure cleanup, complete snapshot restore, and
  read-only Pager/KWin verification;
- the Workspaces revision-2 Pager replacement and revision-1 refresh,
  no-argument KWin navigation API guard, preserved widget order, and exact
  live-package failure recovery;
- doctor version, capability, topology, sensor, Fastfetch, and event-driven
  volume-backend gates;
- bootstrap dry-run, complete v0.4.1 step order, fresh and managed transitions,
  exact v0.3 migration input, idempotent v0.4.1 input, transaction receipts,
  exact Pager/Workspaces final-variant preservation and receipt targets,
  exact failed-receipt/resume guidance at the Plasma 6.7 Opaque checkpoint,
  component failure, verification failure, and display preservation;
- transaction snapshot reuse without nested component snapshots, plus refusal
  of failed or incomplete transaction metadata;
- BlackMinimal colors and Konsole profile;
- Breeze shell activation;
- explicit preservation of the user-owned wallpaper and rejection of the
  retired wallpaper-variant bootstrap option;
- fresh-panel and Minimalist v0.2 migration guards;
- exact date-hidden Digital Clock, always-visible seconds, forced 24-hour time,
  preserved hidden date-format preferences, and 11 pt `Noto Sans` policy;
- v0.3 resource sensors, RAM naming, stable text width, GPU fallback,
  event-driven VOL normalization/mute presentation, package install, topology
  transition, and verification;
- Fastfetch medium-density module selection, Host/Local IP/public-IP exclusion,
  exact config install, render check, snapshot/restore, and shell-startup
  preservation;
- exact v0.3-to-v0.4.1 migration, the enumerated spacer-staged and task-front
  recovery states, settled two-phase placement, exact live cleanup back to
  v0.3, two expanding spacers, one compact native task manager, idempotency,
  and refusal of every other unknown or misordered task-area topology;
- v0.4.1 layout installation only after the complete managed snapshot, exact
  layout-bundle verification, rollback commands, and restore of prior panel
  state;
- task-manager `fill=false`, `maxStripes=1`, and `iconSpacing=0`, while launcher
  membership remains unseeded, unmodified, and outside verification policy;
- Plasma 6.7 fresh-opacity degraded diagnosis, opacity-only recovery messaging,
  receipt-bound continuation from the exact manually repaired v0.2 base using
  the original snapshot, and metadata-only resume for an exact final target;
- forbidden privileged package operations and Plasma/KWin restart commands.
- valid JSON for every public KPackage metadata and manifest;
- the layout-free Store package contract and isolated KPackage
  install/query/upgrade/remove lifecycle;
- deterministic Store and Extended archives, exact allowlists, traversal and
  symlink refusal, checksums, and excluded-payload detection.

## Live read-only checks

```bash
scripts/doctor --target minimalist-v04
scripts/bootstrap
scripts/verify --panel-target minimalist-v04
```

Expected supported topology:

```text
launcher | active title | spacer | compact pinned/running apps | spacer | resources | margin | input | tray | clock
```

Verification does not inspect or grade the user-selected wallpaper. A display
fingerprint that differs from the transaction receipt remains a visible
mismatch, not authority to overwrite out-of-scope state.

## Live visual QA

After an explicitly approved apply and any required login to clear Plasma QML
cache, check:

- active title remains legible and truncates rather than resizing the strip;
- CPU, RAM, GPU, and VOL fields do not shift when values cross 9/10/100 percent;
- CPU can display 100 percent without clipping and returns afterward;
- a missing GPU sensor hides only the GPU label;
- VOL changes without clicking the tray icon, shows `--%` only when the audio
  backend/default output is unavailable, and remains visibly dimmed while
  muted;
- no rendered `|` or middle-dot separator appears between resource labels;
- `fastfetch` shows the medium-density config without a user/host title, Host,
  or network-address fields, and opening a shell does not force an automatic
  Fastfetch run;
- the task manager remains one compact row and running apps can be launched or
  selected without disturbing either adjacent status cluster;
- user-pinned launchers survive an idempotent reapply unchanged;
- the clock reads like `HH:mm:ss` on one line with no date, uses
  `Noto Sans` at 11 pt Regular, and remains legible without
  changing the 32 px panel height;
- input, tray, and clock remain usable;
- Overview, `Meta+W`, KRunner, Kickoff, and existing global shortcuts remain
  available and unchanged;
- no new QML errors appear in the current boot journal.

## Release gate

A change is ready only when the complete suite passes, both release builders
are deterministic, `git diff --check` is clean, live verification reports no
unexplained managed mismatch, rollback is still printed, and the two native
acceptance lanes in `docs/RELEASE.md` pass.
