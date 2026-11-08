# Product scope

Minimalist Black ships one guarded desktop configuration workflow.

The project owns only the exact paths in `config/managed-paths.txt`. It adds the
panel and application-specific pieces that cannot safely be expressed as a
one-click Global Theme:

- guarded single-panel composition;
- three installed project Plasmoid packages: Active Window Title, Resource
  Usage, and optional Workspaces;
- BlackMinimal Konsole profile;
- Fastfetch presentation.

The scripts apply the `BlackMinimal` color scheme, Breeze Plasma Style, and
Breeze window decoration. The base panel
contains Active Window Title and Resource Usage instances. A Workspaces widget
instance exists only on the exact optional Workspaces final variant, while the
alternative exact Pager variant uses Plasma's built-in Pager. Bootstrap adds
neither optional switcher to the base target and preserves either variant only
when its complete topology and policy are already proven.

Wallpaper and display configuration are user-owned. The workflow diagnoses a live
session, prints the complete plan, captures one transaction baseline, performs
only an explicitly approved apply, and verifies the resulting managed state.
The apply path does not select or inspect wallpaper. Because Plasma stores
desktop and panel state together, applying a later full snapshot restore can
also return wallpaper keys in that snapshotted file; users should review the
restore preview after making unrelated post-snapshot changes. The preview labels
unchanged, changed, new, missing, and type-changed paths without showing contents.
It compares data and modes, not timestamps or ownership. Unchanged existing paths
are still displaced and restored during apply.

## Private recovery archive

Personal recovery artwork and its historical apply path are not part of the
product. They remain only in the private archival checkout and are excluded
from every public manifest. Public restore never discovers those paths
automatically. An archival operator must explicitly select
`--private-legacy-compat`, and `scripts/restore` accepts only the pinned private
manifest digest; an added or edited manifest cannot broaden the restore scope.

The private repository's old objects and tags are not publication input. The
verified public source archive is the sole seed for a clean public history.
