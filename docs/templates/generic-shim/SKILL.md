---
name: shimmy-generic-shim-template
description: Template for a Shimmy CLI tool backed by Podman.
---

# Generic Shimmy tool template

Read root `CONTEXT.md`, `CONTRIBUTING.md`, and the closest existing tool guide
and canonical skill. Create one self-contained `tools/<tool>/` directory.

## Installed workflow

Every generated skill must keep this evidence order:

1. Use an already-approved safe outer-wrapper prefix for the requested
   operation on the first attempt.
2. Treat sandbox-only socket, reachability, or permission errors as
   `unverified from the sandbox`; retry the same wrapper through escalation.
3. Use `shimmy-init` only when the escalated wrapper proves a profile, engine,
   connection, or registry-projection failure.
4. Define tool-specific approval scope. Credentialed, networked, privileged,
   mutating, and arbitrary-code operations require exact authorization.

For another profile, resolve its absolute launcher, run `profile status`, then
`profile activate <name> --dry-run`, obtain approval for the exact activation,
and source `shell-init.sh` only after success. Running containers require
separate confirmation before `--stop-running`. Agents never provision or
directly manage Podman machines.

## Required structure

```text
tools/<tool>/
  tool.conf
  guide.md
  SKILL.md
  tests/<tool>.sh
  versions/<major.minor>/
    run.sh
    refresh.sh
    smoke.conf
    image.conf
    container/Containerfile  # local builds only
```

`tool.conf` declares:

```text
tool_default_version=<major.minor>
tool_selector_env=<SHIMMY_SELECTOR_ENV or empty>
```

Do not declare concrete implementation names or add shared routing maps.
`run.sh` receives the original argument vector, mounts `$PWD:/work`, uses the
shared Podman helper, and supports `--preview-shim`. Local builds use the shared
image helper and set `SHIMMY_RUNTIME_DIR` to `lib/runtime`.

Every repository image default and non-`scratch` base must be an immutable
top-level index digest containing `linux/amd64` and `linux/arm64`. Keep mutable
publisher tags only as discovery references.

Validate with:

```sh
./commands/run-tool.sh <tool> --preview-shim <smoke-arguments>
./tests/test.sh --group tools-<tool>
shimmy catalog verify --tool <tool>@<version>
shimmy shim add <tool>@<version>
shimmy shim test <tool>@<version>
```

Run the version-owned smoke on native Linux `amd64` and native Apple Silicon
macOS `arm64`. Cross-emulation does not satisfy native acceptance.
