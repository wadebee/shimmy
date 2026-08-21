# Installation lifecycle

- `manifest.sh` solely renders schema-2 profile manifests.
- `transaction.sh` owns same-filesystem file candidates, authority revalidation,
  atomic replacement, exact rollback, and injected boundary tests.
- `catalog.sh` stages tracked clean-main catalog payloads, creates/reuses
  immutable generations, commits current/previous registry authority, rolls
  back, and never deletes retained generations.
- `profile.sh` stages complete profile candidates: canonical commands/libs,
  direct shim versions, launcher, shell initializer, registry policy, manifest,
  and control/tool skill bundles. Profiles contain no tests or generated
  repository adapters.
- `lifecycle.sh` integrates fresh bootstrap, profile create/activation, image
  preparation, exact active authority, startup compensation, AI-skill
  reconciliation, dry-run, deletion, and failure cleanup.
- `uninstall.sh` validates ownership and removes all installation-owned profiles,
  catalog state, active state, exact startup blocks, recognized projections, and
  recognized direct user-skill links while preserving external resources.
- `launcher-template.sh` is the byte-authoritative final installed launcher for
  `admin`, `profile`, `catalog`, `shim`, and `ai-skill`.

Initial bootstrap requires a clean committed attached `main`, creates only
`default`, installs jq/rg/Skopeo, activates engine/registry authority, records
the active profile, reconciles exact skill links, and applies startup policy as
one compensated lifecycle. An existing config root is never adopted or merged.
