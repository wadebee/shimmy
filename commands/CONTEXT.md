# Management commands

These executable entrypoints implement the installed `bin/shimmy` management
surface. The sourceable or executable repository `install.sh` bootstrap
invokes `install.sh` directly with its fixed jq/rg baseline; there is no
repository launcher. Commands parse arguments and orchestrate shared modules;
reusable behavior belongs in `../lib/`.

## Key files

- `install.sh` installs or removes the enclosing canonical profile.
- `dispatch-tool.sh` dispatches a profile-local installed tool command.
- `run-tool.sh` resolves tool metadata and a concrete version.
- `agent-preflight.sh` validates concrete-version `image.conf` metadata and
  adds preview-only smoke arguments for local builds.
- `status.sh` reads enclosing-profile metadata and validated concrete-version
  image configuration;
- `images.sh` provides explicit, non-mutating remote index and upstream-drift
  verification through catalog-default profile-local Skopeo and jq runtimes;
  `update.sh`, `skills.sh`, and `netinfo.sh` retain their corresponding public
  capabilities.

Installed commands derive profile identity from their profile root and reject
profile and installation-location selectors. Canonical and plugin skills are
profile payload; repository and home exports are written only by explicit
standalone skills operations and are owned by the target manifest.

## Related contexts

- [shared library](../lib/CONTEXT.md)
- [tool metadata](../tools/CONTEXT.md)
- [tests](../tests/CONTEXT.md)
