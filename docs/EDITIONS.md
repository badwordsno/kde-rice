# Edition boundary

Both editions share the same Minimalist Black palette, but they do not share
the same authority over the desktop.

## KDE Store

The Store artifact is one native `Plasma/LookAndFeel` KPackage. Its complete
configuration surface is listed in `contents/defaults`:

- `kdeglobals` application style and embedded color scheme;
- `plasmarc` Breeze Plasma Style;
- `kwinrc` Breeze window decoration.

Anything absent from `contents/defaults` is intentionally outside the Store
edition. In particular, the package has no desktop layout. Enabling a Global
Theme's layout can cause Plasma to discard the current applet configuration;
that mechanism cannot preserve Extended's topology checks and transaction
snapshot.

The Store package also has no dependency on the Extended Plasmoids. It remains
complete when those packages are not installed.

## GitHub Extended

Extended owns only the exact paths in `config/managed-paths.txt`. It adds the
panel and application-specific pieces that cannot safely be expressed as a
one-click Global Theme:

- guarded single-panel composition;
- active-window-title and resource Plasmoids;
- BlackMinimal Konsole profile;
- Fastfetch presentation.

Wallpaper and display configuration are user-owned. Extended diagnoses a live
session, prints the complete plan, captures one transaction baseline, performs
only an explicitly approved apply, and verifies the resulting managed state.
The apply path does not select or inspect wallpaper. Because Plasma stores
desktop and panel state together, applying a later full snapshot restore can
also return wallpaper keys in that snapshotted file; users should review the
restore preview after making unrelated post-snapshot changes.

## Private recovery archive

Personal recovery artwork and its historical apply path are not a third
edition. They remain only in the private archival checkout and are excluded
from every public manifest. Public restore never discovers those paths
automatically. An archival operator must explicitly select
`--private-legacy-compat`, and `scripts/restore` accepts only the pinned private
manifest digest; an added or edited manifest cannot broaden the restore scope.

The private repository's old objects and tags are not publication input. The
verified Extended source archive is the sole seed for a clean public history.
