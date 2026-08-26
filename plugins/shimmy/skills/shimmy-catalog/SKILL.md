---
name: shimmy-catalog
description: Inspect, refresh, publish, roll back, or verify Shimmy's installation-owned immutable default catalog and its source image metadata.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# Shimmy Default Catalog

Shimmy owns one installation-wide catalog named `default`. It contains
immutable generations of tool metadata, concrete versions, and canonical tool
skills. Profiles pin a retained generation; publishing or rolling back the
registry does not change an existing profile pin.

## Inspect

- Use `shimmy catalog status` for the local current/previous registry state.
- Use `shimmy catalog tools` for current tool availability.
- Use `shimmy catalog tools --generation <sha256-generation>` only when a
  retained generation must be inspected explicitly.
- Do not infer installed shims from catalog availability. Use `shimmy shim
  list` for the invoking profile's materialized shims.

Catalog inspection is local-only. Do not add external catalogs, named
selectors, catalog membership, or remote discovery.

## Publish and roll back

Run `shimmy catalog publish` only from the repository root on a clean attached
local `main` branch whose `HEAD` equals `refs/heads/main`. Publication stages
tracked catalog content, validates the complete payload, creates or reuses its
immutable content-addressed generation, and advances current/previous without
deleting any retained generation.

Use `shimmy catalog rollback` to swap to the valid retained previous
generation. Neither operation updates profile pins. Stop on dirty, detached,
non-main, moved-HEAD, malformed skill, unsafe generation, or fingerprint
collision diagnostics; do not bypass them by editing registry or generation
files.

## Refresh source image metadata

Use `shimmy catalog refresh <tool@version> --dry-run` from the normalized clean
attached local `main` repository root before applying a source refresh. The
command uses the active profile's exact jq and Skopeo runtimes, registry
redirects, and explicit `SHIMMY_SKOPEO_AUTH_SECRET`. It resolves tag-backed
runtime and base-image records, inspects each exact immutable candidate for
`linux/amd64` and `linux/arm64`, then resolves the tags again before atomically
changing only the selected `image.conf`.

Do not use refresh for immutable-only upstreams or for a tag whose repository
differs from the configured default; that boundary may represent mirroring or
retention. Review every reported guide or skill path and the source diff. Index
verification is not native acceptance: run the version-owned smoke on native
Linux amd64 and Apple Silicon arm64, commit the reviewed source change, and run
`shimmy catalog publish` separately.

## Verify

Use `shimmy catalog verify` for remote image/index verification when that
action is available. It uses jq and Skopeo from the active profile, preserves
registry redirect and authentication boundaries, and may report upstream
drift without changing catalog state.
