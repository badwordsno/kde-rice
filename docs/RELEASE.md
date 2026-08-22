# Version 1.0 release gate

Release review is deliberately bounded: one design audit before implementation,
the automated checks below, and one native acceptance pass afterward. Passing
the automated and public-safety checks is authority to publish an untagged
clean-history source RC. It is not authority to publish a version tag, GitHub
Release artifact, or KDE Store package.

## Automated gate

The release workstation needs Bash/coreutils, GNU tar, XZ, Zip/Unzip, `jq`,
Node.js, ImageMagick, KDE's `kpackagetool6`, and the Qt 6 `qmllint` development
tool. These are build/test tools only; the Store theme itself requires only
Plasma 6 and Breeze. The scripts report a missing tool and stop rather than
installing packages.

Run from a clean candidate checkout:

```bash
set -e
for test_script in tests/test-*.sh; do
  bash "$test_script"
done
find scripts tests -type f -print0 |
  while IFS= read -r -d '' shell_file; do
    bash -n "$shell_file"
  done
git diff --check

release_dir=$(mktemp -d)
scripts/build-release --output "$release_dir"
(cd "$release_dir" && sha256sum --check SHA256SUMS)
```

Required evidence:

- all QML packages pass the real Qt 6 `qmllint`;
- the Store package passes isolated install, query, upgrade, and removal;
- two builds with the same inputs have identical SHA-256 values;
- archive roots and exact manifests match;
- neither archive contains a symlink, traversal path, private payload, user
  state, receipt, snapshot, host dump, credential, or repository metadata;
- extracting the Extended archive and rerunning every contained test and shell
  syntax check succeeds; `git diff --check` is run in the candidate checkout
  and again after the extracted source becomes a clean-history repository.

## Native KDE Store acceptance

Use one Fedora 44 Plasma Wayland session and one EndeavourOS/Arch-family Plasma
Wayland session. Record the exact distro, Plasma, KWin, package version, and
commit without recording hostnames, hardware identifiers, or account data.

For each lane:

1. Start from an installed, usable Global Theme and record its package ID.
2. Record a checksum of
   `~/.config/plasma-org.kde.plasma.desktop-appletsrc` and the current display
   fingerprint. These are observation artifacts, not files to publish.
3. Install the Store archive. Confirm installation alone changes no active KDE
   configuration.
4. Apply `io.github.badwordsno.minimalistblack` without a layout reset. Confirm
   the expected colors and Breeze appearance.
5. Confirm the panel/applet configuration checksum, wallpaper, launcher set,
   shortcuts, and display fingerprint are unchanged.
6. Apply the same theme again. Confirm the resulting managed appearance is
   identical and no duplicate package or component appears.
7. Apply the recorded previous Global Theme. If it is no longer installed, use
   Breeze and record that substitution.
8. Remove Minimalist Black, log out and back in, and confirm the reverted theme
   is valid and the Extended `BlackMinimal.colors` file, if present, remains.

Any unexplained panel, wallpaper, display, shortcut, or uninstall side effect
is a release blocker.

## Native Extended acceptance

On the same two lanes, with one known panel:

1. run `scripts/doctor --target minimalist-v04`;
2. review the complete `scripts/bootstrap` dry run;
3. capture the printed exact-path snapshot and rollback commands;
4. explicitly apply, including only a documented degraded acknowledgement;
5. complete the documented Opaque checkpoint on Plasma 6.7 if it occurs;
6. log out and back in, then run `scripts/verify --panel-target` with the exact
   base, Pager, or Workspaces target printed by bootstrap;
7. confirm the pre-existing wallpaper, display state, shortcuts, and pinned
   launchers were preserved;
8. preview and apply the recorded restore, log in again, and confirm the
   managed baseline is restored.

The restore intentionally returns complete managed files to their baseline.
If the user changes a wallpaper or another setting stored in those files after
the snapshot, the restore preview must be treated as a request to return that
newer change to the baseline too.

## Public source RC handoff

After the complete automated gate and public-boundary inspection pass, seed the
public GitHub project from the extracted Extended archive with a new root
commit. Do not reuse this private checkout's `.git` directory, branches, or
tags. Keep the source RC untagged and do not attach release artifacts.

## Final release handoff

After both native lanes pass, inspect the clean-history source candidate once
more, create the v1.0.0 tag and GitHub Release, and upload only the verified
Store archive and its checksum to KDE Store.

Repository visibility changes, Git commits, pushes, and Store uploads require
separate explicit approval.
