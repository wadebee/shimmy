# Installation lifecycle

`install.sh` is the sourceable orchestration implementation for the public
`commands/install.sh` entrypoint. The root `install.sh` invokes it only to
bootstrap one canonical profile with internally supplied jq/rg requests; an
installed profile-local launcher invokes it only for its enclosing profile and
requires one or more explicit `--shim` requests. It selects fresh, additive,
refresh, or uninstall lifecycle flows without a shared installed control root.
The root entrypoint sources the installed `shell-init.sh` into its caller when
it is sourced; execution retains initialization only inside the bootstrap
process.

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

Every profile payload unconditionally includes the canonical `agent/` sources
and packaged `plugins/` bundle. Profile install and uninstall do not write or
remove repository or home shared-skill targets; those targets are managed only
through explicit standalone `shimmy skills` commands.
