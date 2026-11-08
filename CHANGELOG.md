# Changelog

## Unreleased

- Use Sarasa Term K Regular 11 pt in the Konsole profile and its font
  prerequisite check. Record the approved C-to-A personal font comparison;
  preserve existing font sizes, Noto defaults, and the panel's Noto policy.

- Change the KDE focus/selection accent to blue `#007ACC`, keep white
  selection text, and add a colors-only maintenance option that preserves
  Konsole assets and its default profile while retaining the full snapshot.

- Include readability tests and baseline fixtures in the public source, run them
  in both release-check trees, and report missing visual dependencies as an
  incomplete gate (exit 77).
- Validate explicit panel roles and show restore preview change classifications
  without printing file contents or changing restore behavior.

- Centralize core v0.4 panel widget IDs and sequences in a source-only data
  contract, with checked generated constants and independent runtime checks.

- Retire the appearance-only KDE Store edition and ship one public source
  archive through `scripts/build-release`, with deterministic checksums and
  the existing private-payload boundary.
- Share component diagnosis decisions without weakening degraded or unsupported
  gates, and explain full-file restore effects in its preview.
- Present doctor, bootstrap, verify, and restore as the normal user workflow;
  retain historical panel IDs and migration/recovery paths for compatibility.


## 1.0.0 — release candidate

- Added format-2 snapshot content checksums and verified restore completion,
  preserving format-1 recovery with an explicit integrity warning.
- Enforced canonical XDG roots for snapshot/restore and serialized mutating
  operations through an inherited, write-free directory lock.
- Separated managed-state verification from excluded display drift in summaries
  while preserving strict mismatch exit codes.
- Added `scripts/check-release` for candidate and extracted-source tests,
  deterministic builds, and artifact checksum verification.

- Added a self-contained Plasma 6 Global Theme for KDE Store. It applies only
  the Minimalist Black colors and Breeze appearance; it has no desktop layout,
  wallpaper, script, or custom-widget dependency.
- Split the guarded panel, three project Plasmoid packages, Konsole profile,
  and Fastfetch configuration into the GitHub Extended edition. The base panel
  uses Active Window Title and Resource Usage; Workspaces remains an exact
  optional final variant.
- Made Extended wallpaper-neutral: the current wallpaper is preserved and is
  no longer a prerequisite, managed target, bootstrap step, receipt field, or
  verification condition.
- Added deterministic Store and Extended release archives, checksums, isolated
  KPackage lifecycle tests, public allowlists, and private-payload leak checks.
- Added an explicit license and a clean-history publication procedure.
- Split the current-contract previews into an appearance-only generated Store
  mock and an illustrative Extended daily-use view; native acceptance remains
  a separate release gate.
- Aligned user-visible `Minimalist Black` naming, added a keyboard-visible
  Workspaces focus indicator, and retired `.config/kcminputrc` from new managed
  scope while retaining exact legacy restore compatibility.
- Fixed the compact Workspaces switcher so numbered buttons use KWin's
  no-argument next/previous APIs, with a guarded live refresh from revision 1.
- Made integrated bootstrap preserve and idempotently reassert exact Pager and
  Workspaces v0.4.1 final variants instead of misclassifying them as unknown.
- Unified the panel's project widgets and built-in Digital Clock with Fedora's
  `Noto Sans` family, showing 24-hour time with seconds and no panel date while
  retaining the clock's calendar and time-zone features.
- Added the first Chimera vertical slice: one canonical square/beveled QML
  grammar synchronized into all three self-contained Plasmoids, native
  configuration pages for title/resource/workspace behavior, isolated
  private-volume failure, and exact user-setting preservation across widget
  refresh and recovery.
- Added a receipt-bound, persistent-state-verified recovery for the exact
  post-login Chimera duplicate tail; stale resources/title applets are removed
  without recreating or reconfiguring any keeper.
- Added a pinned upstream component/license catalog and third-party boundary;
  the current Chimera core remains independently authored MIT while planned
  Panel Colorizer, media, and scratchpad GPL extras stay separate.

The tagged v1.0.0 release artifacts and KDE Store publication remain gated on
the documented Fedora and Arch-family native session acceptance run.
