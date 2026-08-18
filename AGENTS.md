## Scope

This repository packages and makes common CLI tools available to your shell as small wrappers that call `podman run`.

## Personality

Drop all affect, be objective, succinct and provide practical advice.

Question requests that materially differ from your training of best practices by:
1. Searching the web for information added after your knowledge cutoff using your search tools. Synthesize any such responses explicitly citing your sources.
2. Challenging the user to adopt a different approach that more closely aligns with standards.

## Project Map

- Read root `CONTEXT.md` and every retained child `CONTEXT.md` on the path to
  changed files under `commands/`, `lib/`, or `tests/`. Tool and management
  plugin directories deliberately do not contain context files.
- Tool runtime, metadata, guides, and concrete versions live in `tools/<tool>/`.
- Shared modules live in `lib/`.
- Management entrypoints live in `commands/`.
- Behavioral tests live in `tests/`.
- Contributor guidance lives in `CONTRIBUTING.md`.
- The reusable project prompt lives in `docs/prompt-shimmy-project.md`.

## Available Shim Skills

- Generic shim template: `docs/templates/generic-shim/`
- AWS tool: `tools/aws/`
- jq tool: `tools/jq/`
- ripgrep tool: `tools/rg/`
- Terraform tool: `tools/terraform/`

## First-time installation

If Shimmy is not installed on this system:

1. Read `BOOTSTRAP.md`.
2. Use the existing source checkout and invoke the root `install.sh` checkout
   bootstrap as documented there.

The authoritative Shimmy control-plane skills are under
`plugins/shimmy/skills/`. Canonical tool skills are at
`tools/<tool>/SKILL.md`. Do not modify generated copies under
`.agents/skills/`.

## Working Rules

- Read `CONTRIBUTING.md` before making repo changes.
- Follow the naming conventions in `CONTRIBUTING.md` for files, functions, and variables.
- Keep runtime shims as small POSIX shell wrappers with `#!/bin/sh` and `set -eu`.
- Do not propose or implement Go, Rust, Python, or other language rewrites for Shimmy shared behavior or runtime shims unless the user explicitly asks to leave the POSIX shell architecture.
- Mount `$PWD` to `/work` unless the shim has a documented reason not to.
- Use `SHIMMY_{TOOL_PREFIX}_IMAGE` for image override and `SHIMMY_{TOOL_PREFIX}_IMAGE_PULL=always` for pull policy.
- Use Shimmy's shared Podman helper for runtime platform selection instead of hardcoding per-shim OS or architecture checks.
- Treat registry redirect mounting as an explicit client capability. Skopeo is
  the only initial tool-container consumer; `shimmy images verify` inherits it
  through Skopeo, while other runtimes remain unchanged.
- Any Shimmy-defined user-facing environment variable must use the `SHIMMY_` prefix, including image overrides, pull or build flags, opt-in behavior switches, and secret-name selectors.
- Update shim helper code, install script, tests, and README together when behavior changes.
- Treat Podman as an explicit dependency. Do not add Shimmy-side installation or provisioning steps for it.
- On macOS, remember the official Podman pkg installer may place the binary at `/opt/podman/bin/podman`. If automation cannot find `podman`, check that `/opt/podman/bin` is on `PATH`.
- When testing containers, use live Podman and non-mutating cli calls (eg: version or --help) to validate execution  
- Ensure runnable shell files keep executable bits.
- It is important that you use Shimmy tools when available. This requires Podman to be running.
- If a selected command is a Shimmy wrapper and its safe outer-wrapper prefix
  is already approved, run the actual task operation with escalation on the
  first attempt; do not first make a sandboxed Podman call or a preliminary
  version smoke. For repeated read-only repository searches, `["rg"]` is an
  acceptable bounded persistent prefix. Do not announce or invoke the
  `shimmy-escalation` workflow merely because an existing approval is being
  used. If approval is absent or denied, use that workflow for the actual
  wrapper operation before considering a host-tool fallback. Use a non-shim
  fallback only after the user explicitly approves it, preferably with the
  phrase `fallback approved`.
- For installed shims already selected on `PATH`, invoke the normal tool name such as `rg` or `jq`; do not call the resolved installed shim path. Before selecting another profile, use its absolute launcher for `profile status`, `profile activate --dry-run`, and the exact approved `profile activate` command. Require separate confirmation before adding `--stop-running`; never provision, delete, rename, or adopt a machine. Source the profile's `shell-init.sh` only after activation when PATH initialization is needed. Agent tool calls do not retain earlier sourcing, so use an absolute dispatcher or same-command sourcing when the target is not already on `PATH`. For source previews, use `./commands/run-tool.sh <tool> --preview-shim ...` or the concrete version runtime selected by that tool's `tool.conf`.
- When running repo commands, invoke them directly with `exec_command` `login=false` unless profile or startup-file behavior is explicitly under test. Do not use `bash -lc` or login shells for Shimmy commands unless needed.
- In AI Agent environments, approvals are evaluated on the outer command. A
  sandbox-only `unreachable`, `unknown`, socket-denied, or
  `operation not permitted` result means the selected profile is `unverified
  from the sandbox`; it does not prove the profile is inactive. Retry the same
  wrapper operation with outer-command escalation. Only if that escalated call
  still reports a profile-affinity, engine, connection, or registry-projection
  failure should `shimmy-init` inspect or activate the profile. Never activate
  a profile automatically from sandbox-only evidence. Approval for
  `["podman","info"]` does not approve Podman access nested through a wrapper,
  and wrapper approval does not authorize profile activation.
- Canonical skill changes never authorize edits to generated `.agents/skills/` adapters. Refresh accepted repository or home adapters only with the explicit profile-local `shimmy skills update --target repo|profile` lifecycle.

## Refactoring Lessons Learned

- Coordinate directory renames across source comments, context links, test
  discovery, and historical plans so stale references do not recreate the old
  layout in later work.
- When removing a compatibility surface, remove every forwarding path,
  equivalent environment or argument alias, fixture, and test together; verify
  obsolete inputs fail before mutation.
- During staged filesystem replacement, preserve the last valid marker or
  manifest until the new state is committed atomically, so failures leave the
  previous state intact and invalid partial state is rejected.
- Treat a schema or owned-format identity change as one review unit. Inventory and update every producer, consumer, validator, fixture, transaction boundary, and rollback path together.
- Validate generated shell artifacts by inspecting and exercising the rendered output. Correct-looking renderer source does not prove that quoting, escaping, or expansion survived generation.
- Test sourced POSIX entrypoint failures under callers with `set -e`, including ordinary and conditional sourcing. The final status-producing command can determine whether cleanup runs and whether the caller can recover.
- Classify broad terminology-search matches by behavior before editing them. Do not mechanically replace terms that remain accurate in a different subsystem.
- Keep resources with different ownership and lifecycle boundaries behind separate commands and tests, even when one workflow initially creates both.
- Before removing a compatibility surface, map its tests to the invariants they protect. Remove obsolete inputs and fixtures while retaining coverage for malformed state, unsafe paths, collisions, isolation, ownership, and unknown options.
- Compare generated guidance with its canonical source semantically before regeneration. Byte-for-byte reproducibility demonstrates determinism only after the canonical source contains all guidance worth preserving.
