# Licensing boundary

The code, configuration, documentation, package metadata, and original preview
artwork included in a Minimalist Black public release are licensed under the
MIT License in [`LICENSE`](LICENSE).

KDE Plasma, Breeze, Qt, Fastfetch, and distribution packages are runtime or
test dependencies. They are not vendored by this project and retain their own
licenses.

## Archival material excluded from public releases

The maintainer's separate private recovery checkout contains personal artwork
whose redistribution rights have not been established. It is not present in
this public source, is not covered by the MIT License, and is excluded from
both the KDE Store archive and the Extended public-source archive. The release
builders use explicit file allowlists and payload-hash checks so renaming known
excluded private artwork, its source notes or metadata, an archival screenshot,
or an unsanitized recovery record does not make it publishable.

The Git history and archive tags of this private checkout may also contain
historical screenshots or other non-release material. A public GitHub project
must therefore begin with a clean history made from the verified Extended
source archive; changing this repository's visibility is not a release step.
