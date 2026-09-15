---
name: shimmy-tool-yq
description: Use and maintain Mike Farah's yq through Shimmy, including YAML filters, format conversion, explicit file edits, and container runtime limitations.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# Mike Farah yq

Use the installed `yq` command normally when its profile is selected on `PATH`.
This is Mike Farah's standalone Go processor, not the Python yq frontend to jq.
Read [guide.md](guide.md) for examples, dependencies, and runtime limitations
when working in the source checkout. Installed skill copies may lack the guide;
the operational instructions below are self-contained.

## Use

- Quote expressions and use paths relative to `$PWD`, mounted at `/work`.
  Example: `yq '.service.name' config.yaml`.
- Pipeline input works: `printf 'name: shimmy\n' | yq '.name'`.
- `eval` evaluates documents separately; `eval-all` loads all documents before
  evaluating once. Use `-o=json` for JSON output.
- Ordinary filters write stdout. Use `-i`/`--inplace`, split-output flags, or
  shell redirection only when the user's request authorizes those file writes.
- Host environment variables are not forwarded. `env`, `strenv`, and
  `envsubst` inspect the container environment. Do not assume a host assignment
  such as `NAME=value yq ...` exposes `NAME` inside the container.
- The official image lacks `tzdata`; named-timezone operations need an
  explicitly selected image with that dependency. Basic filtering requires no
  host jq, Python, or other companion CLI.
- The `system` operator is disabled by upstream unless explicitly enabled.
  Do not enable it implicitly; companions must exist inside the container.

## Execution and permissions

Use narrow outer-command approval for the actual requested operation. A broad
`["yq"]` approval also covers file writes and explicit command execution, so
request the exact arguments for each operation. Surrounding shell redirection
requires its own authorization. A `yq --version` approval covers that smoke only.

For an already approved wrapper operation, use escalation on the first attempt.
Sandbox-only socket or reachability errors mean the profile is unverified from
the sandbox. Use `shimmy-escalation` to retry that exact operation before any
host fallback. Use `shimmy-init` only if the escalated operation establishes an
engine/profile fault. Profile activation and workload stopping retain their
separate authorization requirements; do not change Podman machines directly.

Inspect the selected profile with `shimmy profile status --format manifest`
and `shimmy shim list --format manifest`. Do not treat `command -v` as proof
of profile health.

## Runtime contract

- `tool.conf` selects concrete version `4.53`; its `image.conf` owns the
  official v4.53.6 multi-platform image digest.
- `SHIMMY_YQ_IMAGE` overrides the image. `SHIMMY_YQ_IMAGE_PULL=always` forces
  acquisition. Overrides must provide a yq entrypoint usable as UID/GID 1000.
- The shared Podman helper selects native `linux/amd64` or `linux/arm64`.
- Keep stdin open without a TTY, preserve argument boundaries, and mount only
  the current workspace read-write at `/work`.
- Preserve UID/GID 1000 mapping through rootless `keep-id`, disabled networking,
  dropped capabilities, and `no-new-privileges`. Ownership mapping does not
  resolve SELinux labeling; do not recursively chown or relabel user files.
- The wrapper mounts no host home or credentials and forwards no host env.

## Maintenance

Canonical files live under `tools/yq/`: `tool.conf`, `guide.md`, this skill,
`tests/yq.sh`, and `versions/4.53/{run.sh,refresh.sh,smoke.conf,image.conf}`.
Keep behavior in the version runtime and metadata rather than shared dispatch.

Validate source preview with
`./commands/run-tool.sh yq --preview-shim --help`, then run focused `tools-yq`
coverage and the repository suite. After outer-command approval, use the
version-owned `--version` smoke and read-only fixture filtering. Record native
Linux amd64 and macOS arm64 results separately; previews are not live evidence.
Installed catalog verification requires a published generation containing yq.
Committing, publishing, and adopting that generation require their own task
authorization; source implementation alone does not authorize those actions.
