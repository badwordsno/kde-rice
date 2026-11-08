# Version 1.0 release gate

Release review is deliberately bounded: one design audit before implementation,
the automated checks below, and one native acceptance pass afterward. Passing
the automated and public-safety checks is authority to publish an untagged
clean-history source RC. It is not authority to publish a version tag or GitHub
Release artifact.

## Automated gate

The release workstation needs Bash/coreutils, GNU tar, XZ, `jq`, Node.js, Python 3, `rg`,
KDE's `kpackagetool6`, `xmllint`, and the Qt 6 `qmllint` development tool.
The offscreen readability check also needs PySide6, Noto Sans, and the installed
KDE QML imports; missing visual dependencies leave the gate incomplete (exit 77).
These are build/test tools only. The scripts report a missing tool and stop rather than
installing packages.

Run `scripts/check-release` from a clean candidate checkout to execute the
complete automated gate, including extracted-source tests. It leaves local
artifacts and logs in a printed temporary directory and publishes nothing.
The individual commands below remain useful for diagnosis.

Run from a clean candidate checkout:

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

release_dir=$(mktemp -d)
scripts/build-release --output "$release_dir"
(cd "$release_dir" && sha256sum --check SHA256SUMS)
```

Required evidence:

- all QML packages pass the real Qt 6 `qmllint`;
- the offscreen readability test runs and passes in both source trees;
- two builds with the same inputs have identical SHA-256 values;
- archive roots and exact manifests match;
- the source archive contains no symlink, traversal path, private payload, user
  state, receipt, snapshot, host dump, credential, or repository metadata;
- extracting the public source archive and rerunning every contained test and shell
  syntax check succeeds; `git diff --check` is run in the candidate checkout
  and again after the extracted source becomes a clean-history repository.

## Native desktop acceptance

Use one Fedora 44 Plasma Wayland session and one EndeavourOS/Arch-family Plasma
Wayland session, each with one known panel. Record distribution and software
versions without hostnames, hardware identifiers, or account data.

1. run `scripts/doctor --target minimalist-v04`;
2. review the complete `scripts/bootstrap` dry run;
3. capture the printed exact-path snapshot and rollback commands;
4. explicitly apply, including only a documented degraded acknowledgement;
5. complete the documented Opaque checkpoint on Plasma 6.7 if it occurs;
6. log out and back in, then run `scripts/verify --panel-target` with the exact
   base, Pager, or Workspaces target printed by bootstrap;
7. confirm the pre-existing wallpaper, display state, shortcuts, and pinned
   launchers were preserved; reapply the same plan and confirm no duplicate
   widget or topology change occurs;
8. preview and apply the recorded restore, log in again, and confirm the
   managed baseline is restored.

Visual acceptance also checks long window titles, metric digit transitions,
missing optional GPU/audio data, keyboard focus, and the account's existing
display scale. Do not change display settings as part of this workflow.

The restore intentionally returns complete managed files to their baseline.
If the user changes a wallpaper or another setting stored in those files after
the snapshot, the restore preview must be treated as a request to return that
newer change to the baseline too.

## Public source RC handoff

After the complete automated gate and public-boundary inspection pass, seed the
public GitHub project from the extracted public source archive with a new root
commit. Do not reuse this private checkout's `.git` directory, branches, or
tags. Keep the source RC untagged and do not attach release artifacts.

## Final release handoff

After both native lanes pass, inspect the clean-history source candidate once
more, create the v1.0.0 tag and GitHub Release, and attach the verified source
archive and `SHA256SUMS`.

Repository visibility changes, Git commits, pushes, and release publication require
separate explicit approval.

## Native evidence to record

For each of the two lanes, record the candidate commit, package checksums,
Plasma/KWin versions, test date, and pass/fail for every native
acceptance step above. Mark an unperformed step as pending, never passed.
Record failure explanations without account identifiers or raw session dumps.
Automated results and read-only checks on an existing desktop do not substitute
for the apply/reapply/restore and logout/login acceptance sequence.
