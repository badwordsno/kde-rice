# Compatibility policy

Compatibility is determined from observable KDE APIs and capabilities, not a
distribution name. Fedora and EndeavourOS are the recorded native validation
lanes; plain Arch and Debian-family package mappings are best-effort until the
same release candidate completes a native acceptance run. Every Extended host
must pass doctor regardless of its distribution.

The KDE Store edition has a separate, narrower contract. Its metadata accepts
Plasma 6.0 or newer, it embeds its own color scheme, and it selects only Breeze
appearance components. A tagged Version 1.0 release and KDE Store publication
still require the Fedora and Arch-family apply/reapply/revert/remove acceptance
in `docs/RELEASE.md`.

## Canonical diagnosis

```bash
scripts/doctor --target minimalist-v04
```

The Extended v0.4.1 panel target checks Plasma/KWin, Wayland, D-Bus scripting, apply tools,
Breeze, fonts, Fastfetch 2.40+, applets including
`org.kde.plasma.icontasks`, panel topology, KSystemStats CPU/memory support,
the LibKSysGuard sensor QML module, KDE's event-driven PulseAudioQt volume QML
backend, and optional GPU readiness.

The volume module is a Plasma-internal interface rather than a cross-version
public QML contract. This repository therefore proves the module on the
live-confirmed Plasma 6.7 range and retains degraded/unsupported version gates
instead of assuming that the import remains compatible on another KDE minor.

## Status meanings

- `supported`: every required capability and an accepted topology are proven.
- `degraded`: inspection and dry-run remain safe, but a documented quality or
  validation condition requires explicit review before `--allow-degraded`.
- `unsupported`: a required API, version, capability, path invariant, session,
  or safe topology cannot be proven. Live apply is refused.

Degraded mode never overrides an unsupported Plasma/KWin major version,
missing required capability, unsafe XDG root, inaccessible shell, or unknown
panel topology.

## Version policy

| Component | Policy |
| --- | --- |
| Plasma 6.7.x managed v0.2/v0.3/v0.4.1 state | Live-confirmed when every capability probe passes |
| Plasma 6.7.x fresh stock-panel replacement | Degraded: manual Opaque confirmation and receipt resume are required |
| KWin 6.7.x Wayland | Live-confirmed with the Breeze decoration apply tool |
| KDE Plasma volume QML backend on Plasma 6.7.x | Live-confirmed for event-driven default-output percentage and mute state |
| Fastfetch 2.40+ | Supported for the managed portable JSONC subset; executable ownership remains in `linux-workstation` |
| Other Plasma/KWin 6 minors | Degraded until full automated and live validation is recorded |
| Plasma/KWin 5 | Unsupported |
| Future major versions | Unsupported until explicitly ported |

## Panel topology policy

Bootstrap accepts:

- an exactly recognized clean Plasma 6 panel;
- an enumerated older Minimalist or interrupted migration state;
- the exact Minimalist v0.2 base;
- the exact Minimalist v0.3 resource state as a v0.4.1 migration source;
- the enumerated v0.4.1 spacer-only and task-front order repair states;
- the exact Minimalist v0.4.1 base target;
- the exact v0.4.1 Pager and Workspaces final variants.

The final result is always Minimalist v0.4.1. Bootstrap does not add an
optional switcher to the base target, but an already exact Pager or Workspaces
variant is preserved, reasserted, and verified with its own target signature.
Historical Silver Palace and Retro Workstation layouts are not accepted
targets. Unknown or unexplained panels and widgets are refused rather than
normalized.

The guarded v0.4.1 transition accepts the exact v0.3 sequence, adds the second
expanding spacer, waits for its live geometry to settle, and adds the native
Icons-Only Task Manager in a separate scripting call. The exact spacer-only
state is completed directly. The exact historical task-front insertion state
is recovered by removing only its task and right spacer, returning to v0.3,
and rebuilding those additions in two settled phases. No other partial or
similar-looking panel grants permission to continue.

### Plasma 6.7 fresh-panel opacity

The Plasma 6.7 scripting wrapper routes the panel `opacity` setter through the
window-opacity path instead of the panel opacity-mode setter. Consequently, a
freshly created target panel can pass topology, geometry, tray, clock, spacer,
and Plasmoid checks while remaining Adaptive. This is a known capability limit,
not permission to weaken the target or edit `plasmashellrc` by guesswork.

Doctor classifies an accepted stock-panel transition on Plasma 6.7 as
`degraded`. After the user explicitly reviews `--allow-degraded`, bootstrap may
create the guarded target and stop with a precise manual instruction. Set that
single panel to Opaque in Plasma edit mode without changing its widget order,
then run the exact receipt commands printed by bootstrap:

```bash
scripts/resume-bootstrap --receipt /absolute/path/to/failed-receipt
scripts/resume-bootstrap --receipt /absolute/path/to/failed-receipt --apply
scripts/verify --panel-target minimalist-v04
```

The failure output names the transaction receipt, failed step, baseline
snapshot, resume preview/apply commands, and restore preview/apply commands.
The operator must use the resume preview before its apply form and must not
start a new live bootstrap around the partial v0.2 state.

Resume first classifies the exact repaired topology and checks the original
excluded-display fingerprint. A live Fedora 44 / Plasma 6.7.4 fresh transition
showed that the opacity postcheck can stop at the exact v0.2 base before the
integrated v0.3/v0.4.1 steps run. For that exact receipt and topology only, resume
reuses the original complete snapshot, adds the missing resource widget, right
spacer, and Icons-Only Task Manager, then performs normal v0.4.1 verification. An
already complete v0.4.1 target uses metadata-only finalization. Both paths
preserve the original failure record under the receipt's `history/` directory;
every other intermediate topology is refused.

## Monitor policy

| Arrangement | Status |
| --- | --- |
| One monitor and one recognized panel | Supported in the confirmed version range |
| Multiple monitors with one recognized primary panel | Degraded pending complete live QA |
| Multiple or per-monitor panels | Unsupported for replacement |
| Mirrored, rotated, mixed-scale, HDR, or VRR outputs | Display state is out of scope and preserved |

The project never writes output resolution, scale, position, refresh rate,
HDR, VRR, `.config/kwinoutputconfig.json`, or `.local/share/kscreen`.

## Promotion of a new KDE minor

Run the full automated suite, doctor, bootstrap dry-run, fresh and managed
transitions, the exact v0.3-to-v0.4.1 migration, idempotent v0.4.1 reapply,
read-only verification, visual QA, and snapshot restore. Record the new version
here instead of weakening runtime guards silently.
