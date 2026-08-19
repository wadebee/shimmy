# Shimmy project guidance

Read root `CONTEXT.md`, then the retained child contexts leading to changed
code under `commands/`, `lib/`, or `tests/`. Update the closest retained
context whenever that hierarchy's architecture, conventions, or child links
change. Tool and management-plugin directories do not own context files.

## Layout

- `commands/` contains the executable management surface.
- `lib/` contains reusable POSIX modules, including canonical XDG profile-path
  resolution.
- Root `bootstrap.sh` bootstraps one profile; the repository contains no runnable
  `shimmy` launcher. Sourcing it initializes the caller; execution is for
  automation. Every bootstrap includes jq and rg, and each installed
  materialized profile owns its own `bin/shimmy`. Human users may explicitly
  add `--activate` for a post-commit activation that automatically selects a
  stale Darwin restart but never acknowledges running workloads.
- Shared named catalogs live outside profiles: `upstream` is a live validated
  checkout binding and `default` is a published immutable generation.
- `tools/<tool>/tool.conf` defines a tool's default version and selector.
- `tools/<tool>/versions/<major.minor>/run.sh` is the concrete runtime.
- Every concrete version owns `image.conf`, which records external or
  local-build image policy, immutable multi-platform defaults, registry access,
  and both required platforms.
- Local builds use that version directory's `container/Containerfile`.
- Tool guides and canonical tool skills live beside the tool.
- `tests/` validates retained context integrity, metadata dispatch, previews, and clean
  installation behavior.

## Runtime rules

- Keep shell code POSIX-compatible with `#!/bin/sh` and `set -eu`.
- Preserve tool names, supported tool-specific `SHIMMY_*` environment
  variables, image overrides, pull/build options, mounts, credentials, and
  `--preview-shim`.
- Mount `$PWD` at `/work` unless the tool guide or canonical skill documents a
  reason not to.
- Use `lib/runtime/podman.sh` for native OS/architecture platform selection and
  Podman preflight; unsupported or unreadable hosts must fail closed.
- Use `lib/runtime/image.sh` to validate and consume `image.conf`, resolve local
  build inputs, and derive cache identity. Do not duplicate repository-owned
  defaults in runtime shell or Containerfiles.
- Do not install or provision Podman from Shimmy.
- Treat profile registry policy as an explicit client capability. Skopeo is
  the initial read-only mount consumer and `images verify` inherits it; do not
  add policy mounts to other tools without focused review and tests.

## Tool additions

Add a self-contained `tools/<tool>/` directory with `tool.conf`, a guide, a
canonical `SKILL.md`, focused tests, and one or more version directories
containing `run.sh`, `refresh.sh`, `smoke.conf`, `image.conf`, and `container/`
when locally built. The
catalog discovers this metadata; do not add tool-name case statements to `lib/`
or command code.

Choose `external` or `local-build` before implementation. Each concrete
version must own a complete `image.conf`; every repository default and
non-`scratch` base must be an immutable top-level index digest with both
required platforms. Keep mutable publisher tags only as upstream discovery
references. Use the shared image and Podman helpers rather than duplicating
defaults or OS/architecture checks.

Audit companion tools, packages, download URLs, and release archives for both
target architectures. Verify configured indexes explicitly with `shimmy images
verify`, then run the version-owned smoke on native Linux `amd64` and native
Apple Silicon macOS `arm64`; cross-emulation is not acceptance. Digest rotation
is a focused `image.conf` review that must change local cache identity when
applicable and retain the prior digest in git history as rollback evidence.

## Installed profiles and external integrations

Install profiles below an absolute
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>` root. Installed
commands derive identity from their enclosing profile and do not accept
installation-location or profile-selection overrides. Add non-baseline tools
after onboarding with installed `shimmy install --shim <tool>`. Source a
profile's `shell-init.sh` to select it in an existing shell only after using
its absolute launcher for `profile status`, `profile activate --dry-run`, and
explicit `profile activate`. Running containers require separate confirmation
before `--stop-running`. Missing deterministic macOS machines are provisioned
only by the user from Shimmy's exact normal-shell guidance; agents never
provision, delete, rename, or adopt machines. AI Agent calls do not retain
earlier sourcing, so later calls use an absolute profile dispatcher or
same-command sourcing. Only `default` owns persistent startup blocks. A fresh
bootstrap records one normalized shell and either its conventional exact paths
or manual policy selected by `--no-startup`; later lifecycle operations inherit
that immutable state, and repair consumes only the recorded ledger. Changing
policy requires uninstalling and recreating the profile. `upstream` never
changes startup files.

The combined `bootstrap.sh --activate` human workflow does not authorize an AI
Agent to collapse status, dry-run, activation approval, or workload
acknowledgement into one operation.

The five canonical management skills and co-located tool skills remain in the
selected named catalog and are not profile payload. Repository and home agent
skill adapters are independently manifest-owned external state, staged from a
validated catalog, and written or removed only through explicit standalone
`shimmy skills ... --target repo|profile` operations. Profile and catalog
lifecycle operations do not remove those exports.
After accepting canonical skill changes, refresh an existing target only with
explicit `shimmy skills update --target repo|profile`; do not edit generated
adapters directly.
In AI Agent environments, recognize installed Shimmy wrappers before their
first task invocation. If a safe outer-wrapper prefix is already approved, run
the actual task operation with escalation immediately instead of first making
a sandboxed Podman call or version smoke. For repeated read-only repository
searches, `["rg"]` is an acceptable bounded persistent prefix. Treat a
sandbox-only unreachable or unknown result as `unverified from the sandbox`,
not as an inactive profile, and retry the same wrapper operation through the
approval boundary. Inspect or activate a profile only if the escalated wrapper
still provides evidence of a real profile-affinity, engine, connection, or
registry-projection failure. Never activate from sandbox-only evidence;
wrapper approval and profile-activation approval are separate authorities.
Catalog-aware operations resolve and validate the profile's named catalog on
every invocation. Valid upstream edits are immediately visible; default sees
them only after clean committed publication. Publication does not change
profile materializations until explicit update. Profile uninstall preserves
shared catalogs; explicit global uninstall preserves bound checkouts and
external skill exports.

## Verification

Run `./tests/test.sh`, inspect shell executable bits, and verify retained
context links.
For a source preview, use `./commands/run-tool.sh <tool> --preview-shim ...`.
