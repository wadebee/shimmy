# Update lifecycle

`update.sh` is the sourceable implementation for the public
`commands/update.sh` entrypoint. It refreshes management assets, adopts current
catalog defaults for selected installed tools, refreshes remote or local
images, and cleans stale local-image state for the invoking profile only.
Catalog availability is resolved from the profile's fixed shared registry
binding before any update mutation; refresh hooks continue to execute from
the profile-owned materialization root.

An update preserves the profile's canonical root and, for `upstream`, its
recorded source checkout. It never selects or mutates a sibling profile,
updates persistent upstream startup integration, or writes an external skills
target. Management self-update executes the fetched repository bootstrap
without lifecycle skills options or reconstructed tool-selection arguments;
that control refresh preserves the existing selection. A separate atomic
profile materialization step then replaces only selected tool/version labels
with their current catalog mappings while retaining explicitly selected
concrete versions.

## Files

- `request.sh` parses update CLI inputs and renders command help.
- `selection.sh` validates installed tools and concrete version selections for
  the enclosing profile.
- `management.sh` refreshes management assets from an installed source URL.
- `profile.sh` validates and refreshes the enclosing profile's assets.
- `refresh.sh` locates and invokes an installed concrete version's executable
  refresh hook. Hooks accept `pull` or `build`; they own image override
  handling, their safe runtime invocation where applicable, and local-image
  cleanup.
- `update.sh` retains setup and lifecycle orchestration only.
