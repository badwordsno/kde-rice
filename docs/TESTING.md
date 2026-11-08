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
  `qmllint` package checks, the offscreen Python readability test, and
  `git diff --check`. Missing `qmllint` leaves this
  gate incomplete even when a live host is supported.

When reporting results, say which gate was evaluated. Do not summarize a
`qmllint`-blocked release suite as either a live doctor failure or a fully
passing repository suite.

## Complete candidate-checkout suite

`scripts/check-release` runs this suite plus two release builds, checksum
comparison, and all tests and syntax checks in the extracted public archive.
It stops at the first failed check and prints the temporary log directory.
The readability check runs for both the candidate and extracted source. Missing
PySide6/Qt bindings, required QML imports, or Noto Sans are reported as `NOT RUN`;
other checks continue, and the gate ends `INCOMPLETE` with exit code 77. That is
not a complete release pass. Actual QML or assertion failures stop the gate. Use this
same command as the automation entry point on a prepared non-root test host;
it does not provision packages or perform native-session acceptance.

Recovery tests additionally cover format-2 content corruption, missing checksums,
added or missing payload entries, inherited and conflicting operation locks,
noncanonical XDG refusal before writes, and a copy command that reports success
with incorrect contents. Legacy format-1 recovery remains tested separately.

```bash
set -e
for test_script in tests/test-*.sh; do
  bash "$test_script"
done
python3 tests/test-panel-readability.py
for shell_file in scripts/* scripts/lib/*.sh tests/*.sh tests/lib/*.sh; do
  [[ -f "$shell_file" ]] || continue
  bash -n "$shell_file"
done
git diff --check
```

The public source archive intentionally has no `.git` directory. After extracting
it, rerun every contained `tests/test-*.sh`, the readability test, and every
shell syntax check from
the block above, omitting only `git diff --check`. Run that Git check again
after the extracted source is initialized as the clean-history public
repository.

The suite covers:

- generated panel constants matching their authored contract, read-only drift
  detection, and refusal of unsafe or incomplete generation destinations;

- restore preview classifications for content/mode changes, missing/new paths,
  type changes, and links, without exposing contents or writing during preview;
- exact-path snapshot, restore, displaced state, legacy restore-only paths
  including the retired `.config/kcminputrc`, path traversal, symlink escape,
  and display exclusions;
- the guarded clock-only dry run/apply, exact v0.4.1 topology and 32 px geometry,
  full-scope snapshot-before-write ordering, layout-only asset refresh,
  eight-key clock-policy idempotence, enum serialization compatibility,
  fixed `Noto Sans` panel-font enforcement, and failure restore;
- the guarded Pager-preview dry run/apply, geometry-positioned insertion after
  the launcher, four-desktop one-row KWin state, numeric Pager policy,
  idempotence, exact-ID failure cleanup, complete snapshot restore, and
  read-only Pager/KWin verification;
- the Workspaces revision-2 Pager replacement and revision-1 refresh,
  no-argument KWin navigation API guard, preserved widget order, and exact
  live-package failure recovery;
- all three project Plasmoid package sources, with two widget instances on the
  base target, the optional Workspaces instance only on its exact variant, and
  Plasma's built-in Pager excluded from the project-package count;
- shared component diagnosis refusal for unsupported and operational failures,
  and explicit degraded acknowledgement before live apply;
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
- the deterministic public source archive, exact allowlists, traversal and
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
- keyboard focus on an optional Workspaces button has a visible theme-highlight
  outline distinct from the current-desktop fill;
- no new QML errors appear in the current boot journal.

## Release gate

A change is ready only when the complete suite passes, the release build
is deterministic, `git diff --check` is clean, live verification reports no
unexplained managed mismatch, rollback is still printed, and the two native
acceptance lanes in `docs/RELEASE.md` pass.

## Reading verification summaries

The JSON result retains its overall `status` and checks, and adds
`summary.managed_state` (`verified` or `mismatch`) and `summary.display_state`:

- `unchanged`: the checked display fingerprints agree;
- `changed_during_apply`: the receipt's before/after fingerprints differ;
- `changed_since_receipt`: apply recorded no display change, but current state differs;
- `changed_since_failed_baseline`: current state differs from a failed receipt baseline.

Every display mismatch still fails verification. These categories identify the
comparison that failed, not the actor or intent behind a change. Do not
rewrite display settings or overwrite the receipt to make verification pass.

## Soft cells readability regression

The public archive includes this test and its fixed baseline fixtures. With
PySide6, Noto Sans, and the local KDE QML imports available, run:

```sh
python3 tests/test-panel-readability.py
```

The test creates a temporary HOME/XDG/runtime tree and uses offscreen Qt with
no live session bus or sensor instances. It compares fixed pre-change QML
excerpts with the current Workspaces frame and Resource Usage font/formatting
code. It checks selected-text contrast, preserved selection and focus, distinct
hover/pressed fills, metric capacity, and stable digit transitions. This is a
fragment-level check with synthetic input, not full Plasma visual acceptance.
Exit 77 means dependencies are unavailable and the test was not run. All other
nonzero exits are failures. The release gate runs the default check;
`--render` additionally regenerates the comparison and measurements under
`research/ricing/experiments/readability-study`.

For a user-reviewed three-desktop layout, read-only verification can state that
expectation explicitly with `--panel-target minimalist-v04-workspaces
--expected-desktops 3`. The default remains four, the actual count is never
changed, all other checks still run, and failed-receipt resume retains its
original four-desktop contract. Next-login staging can be previewed without
writes using `scripts/apply-panel-font-policy --stage-next-login
--expected-desktops 3 --dry-run`.
