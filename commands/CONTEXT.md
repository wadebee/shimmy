# Management commands

These executable entrypoints implement the installed `bin/shimmy` management
surface. The sourceable or executable repository `install.sh` bootstrap
invokes `install.sh` directly with its fixed jq/rg baseline; there is no
repository launcher. Commands parse arguments and orchestrate shared modules;
reusable behavior belongs in `../lib/`.

## Key files

- `install.sh` installs or removes the enclosing canonical profile.
- `catalog.sh` publishes clean committed `upstream` content to an immutable
  `default` generation or explicitly rebinds the live upstream registry.
- `dispatch-tool.sh` dispatches a profile-local installed tool command without
  resolving or validating the catalog checkout.
- `run-tool.sh` dispatches materialized tool runtime assets; it does not act as
  catalog availability authority.
- `agent-preflight.sh` validates concrete-version `image.conf` metadata and
  adds preview-only smoke arguments for local builds.
- `status.sh` resolves the enclosing profile's named catalog and reports its
  source, generation provenance, schema, fingerprint, and health together
  with validated tool metadata;
- `images.sh` provides explicit, non-mutating remote index and upstream-drift
  verification through catalog-default profile-local Skopeo and jq runtimes;
  `update.sh`, `skills.sh`, and `netinfo.sh` retain their corresponding public
  capabilities.

Installed commands derive profile identity from their profile root, resolve
its fixed named catalog through shared XDG registry state on every
catalog-aware invocation, and reject profile and installation-location
selectors. Missing or invalid catalog state fails before command mutation.
Canonical skill sources are read from the resolved catalog; repository and
home exports are written only by explicit standalone skills operations and
are owned by the target manifest. Repository and home
`.agents/skills/<name>/` exports are one-file compatibility adapters
containing only `SKILL.md`.

## Related contexts

- [shared library](../lib/CONTEXT.md)
- [tests](../tests/CONTEXT.md)
