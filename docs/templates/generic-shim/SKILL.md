---
name: shimmy-generic-shim-template
description: Template for a Shimmy CLI tool backed by Podman.
---

# Generic Shimmy tool template

Read root `CONTEXT.md`, `CONTRIBUTING.md`, and the guide and canonical skill
for the closest existing tool. Create one self-contained `tools/<tool>/`
directory.

## Installed profile workflow

Every generated tool skill must include this evidence order, followed by a
tool-specific approval rule:

1. If the installed wrapper's safe outer-command prefix is already approved,
   run the actual requested operation with escalation on the first attempt. Do
   not first run a sandboxed Podman call or a version smoke.
2. Treat a sandbox-only unreachable, unknown, socket-denied, or
   `operation not permitted` result as `unverified from the sandbox`, not as an
   inactive profile. Retry the same wrapper operation through
   `shimmy-escalation` before profile inspection or fallback.
3. Use `shimmy-init` only if the escalated wrapper still proves a
   profile-affinity, engine, connection, or registry-projection failure. Never
   activate a profile automatically from sandbox-only evidence.
4. Add an `Approval scope:` rule specific to the tool. Permit a reusable
   wrapper prefix only for a demonstrably local, read-only command. Require an
   exact operation-specific prefix for credentialed, networked, potentially
   mutating, privileged, or arbitrary-code execution. Keep wrapper approval
   separate from authorization for external writes or other side effects.

When a generated tool skill describes installed use, require the target
profile's absolute launcher to run `profile status`, `profile activate
--dry-run`, and then the exact approved `profile activate` command. Running
containers require separate explicit confirmation before `--stop-running` is
added. A missing `shimmy-<profile>` machine is provisioned only by the user in
a normal shell with the exact guidance emitted by Shimmy; agents never run
direct Podman machine lifecycle commands.

After activation, sourcing the profile's `shell-init.sh` selects PATH only.
AI Agent tool calls do not retain earlier sourcing, so later calls use the
absolute profile dispatcher or source `shell-init.sh` in the same command.
Installed commands never accept a profile selector.

## Required structure

```text
tools/<tool>/
  tool.conf
  guide.md
  SKILL.md
  versions/<major.minor>/
    run.sh
    smoke.conf
    image.conf
    container/Containerfile  # only for local builds
```

`tool.conf` must retain `shim_name=<tool>` for manifest compatibility and add:

```text
tool_default_version=<major.minor>
tool_selector_env=<SHIMMY_SELECTOR_ENV or empty>
```

`run.sh` receives the original CLI argument vector unchanged, uses
`lib/runtime/podman.sh`, mounts `$PWD:/work`, and supports
`--preview-shim`. Use `lib/runtime/image.sh` for local build contexts after
setting `SHIMMY_RUNTIME_DIR` to `lib/runtime`.

Choose `image_source=external` when a usable publisher image exists or
`image_source=local-build` for a version-owned container context. Complete the
matching schema in `image.conf`. Pin every repository default and non-`scratch`
base to an immutable top-level OCI index or Docker manifest-list digest with
`linux/amd64` and `linux/arm64`; keep publisher tags as upstream discovery
references only. Do not duplicate defaults in `run.sh` or a `Containerfile`.

Audit packages and downloaded artifacts for both target architectures. Run
`./commands/images.sh verify --shim <tool>@<version>`, the preview suite, and
the version-owned smoke on native Linux `amd64` and Apple Silicon macOS
`arm64`. Cross-emulated builds do not satisfy native acceptance.

The catalog discovers tool metadata automatically. Do not add central catalog,
status, or update case statements. Add focused metadata and preview validation
to `tests/` and run `./tests/test.sh`.
