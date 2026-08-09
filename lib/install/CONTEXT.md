# Installation lifecycle

`install.sh` is the sourceable orchestration implementation for the public
`commands/install.sh` entrypoint. The root `install.sh` invokes it only to
bootstrap one canonical profile with internally supplied jq/rg requests; an
installed profile-local launcher invokes it only for its enclosing profile and
requires one or more explicit `--shim` requests. It selects fresh, additive,
refresh, or uninstall lifecycle flows without a shared installed control root.

## Files

- `request.sh` parses install inputs, resolves the canonical XDG profile path,
  and validates requested tool kinds and versions.
- `manifest.sh` preserves and renders the profile-local version-4 manifest.
- `profile-assets.sh` stages the flat control/runtime payload, profile-local
  launcher, implementations, metadata, and dispatchers.
- `launcher-template.sh` becomes the installed profile's self-contained
  `bin/shimmy`.
- `startup.sh` renders the profile's `shell-init.sh` asset and applies
  persistent startup integration only for `default`.
- `uninstall.sh` removes only validated assets owned by the enclosing profile,
  then attempts to remove empty merge-owned parent directories.

External shared-skills integration for a repository or home agent profile runs
only for an explicit target after the profile transaction commits. Profile
lifecycle operations do not own or implicitly remove that target. The
packaged `plugin` target remains inside the profile payload.
