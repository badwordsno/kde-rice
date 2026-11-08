# Panel data contract

`v04.json` is the authored source for widget IDs, semantic roles, and the six accepted sequences
used by the v0.4 migration's preflight, two placement phases, cleanup, and
postcheck. It covers the v0.3 input, two recovery stages, and the final base,
Pager, and Workspaces variants.

Run `scripts/sync-panel-contract --write` after changing this data.
`scripts/sync-panel-contract --check` is read-only and is required by the source
release builder. Python 3 is a build/maintenance dependency only. Live apply
still sends standalone JavaScript to Plasma; no runtime import or generator
is needed on the desktop.

Only the marked constant blocks are generated. Each consumer retains its own
state observation, acceptance conditions, mutation, or rollback implementation.
Postcheck never calls the mutation code. Existing behavioral tests use their
own panel fixtures instead of constructing expectations from this contract.

Each sequence lists unique roles, including `leftSpacer` and `rightSpacer` for
the two instances of the same spacer widget type. The generator emits both the
widget-type array and its role-to-position map. The five consumers resolve
widgets through those positions; postcheck also checks each live widget's type
before reading its policy. The generator rejects missing or duplicated roles,
incompatible role/type bindings, and sequences that violate the supported
spacer/task insertion or cleanup transitions. These checks happen before any
generated source is written.

This contract does not cover every panel policy. Geometry, configuration
values, the general doctor probe, and specialized font/clock/Pager/Workspaces
scripts still have independent definitions. Changing a sequence requires
reviewing those consumers and the behavioral tests; regenerating constants is
not proof that a new topology is safe. Historical IDs and managed destinations
are unchanged.
