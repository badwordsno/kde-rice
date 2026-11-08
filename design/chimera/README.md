<!-- SPDX-License-Identifier: MIT -->

# Chimera visual grammar

Chimera is one interface with several independently replaceable organs. It is
not a collection of simultaneously visible upstream themes.

The canonical rules are:

- a 2 px spacing grid, square corners, and a dense 32 px panel;
- one light top/left edge and one dark bottom/right edge for raised surfaces;
- an inverted bevel for pressed surfaces;
- one accent rail for selection, warning, or critical state;
- a separate 2 px accent outline for keyboard focus;
- Noto Sans panel text, plain-text window titles, and tabular-width metrics;
- no blur, glow, gradient, and animation stack; state transitions are either
  disabled or 110 ms.

ChimeraTokens.qml and ChimeraFrame.qml are the single authored runtime source.
Each Plasmoid receives a byte-identical local copy because a Plasma KPackage
must remain self-contained. The read-only release gate is:

    scripts/sync-chimera-components --check

The explicit maintainer command for refreshing generated package copies is:

    scripts/sync-chimera-components --write

The second command updates only the exact package-local component allowlist in
the script. Runtime packages do not import files from the checkout or from
another Plasmoid.

The three widgets deliberately expose content and behavior choices while
keeping the visual grammar constrained:

- Active Window Title controls its safe placeholder template, icon, width
  policy, maximized-only filter, and guarded window actions.
- Resource Usage controls metric visibility/order, sensor rate, and threshold
  rails.
- Workspaces controls labels, single-desktop visibility, and wheel behavior.

No upstream QML, SVG, preset, or numeric theme table is copied into this layer.
The component research catalog is informational until a component is explicitly
vendored or shipped as a separately licensed extra.
