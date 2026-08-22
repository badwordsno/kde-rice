# Changelog

## 1.0.0 — release candidate

- Added a self-contained Plasma 6 Global Theme for KDE Store. It applies only
  the Minimalist Black colors and Breeze appearance; it has no desktop layout,
  wallpaper, script, or custom-widget dependency.
- Split the guarded panel, Plasmoids, Konsole profile, and Fastfetch
  configuration into the GitHub Extended edition.
- Made Extended wallpaper-neutral: the current wallpaper is preserved and is
  no longer a prerequisite, managed target, bootstrap step, receipt field, or
  verification condition.
- Added deterministic Store and Extended release archives, checksums, isolated
  KPackage lifecycle tests, public allowlists, and private-payload leak checks.
- Added an explicit license and a clean-history publication procedure.
- Fixed the compact Workspaces switcher so numbered buttons use KWin's
  no-argument next/previous APIs, with a guarded live refresh from revision 1.
- Made integrated bootstrap preserve and idempotently reassert exact Pager and
  Workspaces v0.4.1 final variants instead of misclassifying them as unknown.
- Unified the panel's project widgets and built-in Digital Clock with Fedora's
  `Noto Sans` family, showing 24-hour time with seconds and no panel date while
  retaining the clock's calendar and time-zone features.

The tagged v1.0.0 release artifacts and KDE Store publication remain gated on
the documented Fedora and Arch-family native session acceptance run.
