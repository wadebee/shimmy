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

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues using the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

This repository uses a single-context domain documentation layout. See `docs/agents/domain.md`.

## First-time installation

If Shimmy is not installed on this system:

1. Read `BOOTSTRAP.md`.
2. Use the existing source checkout and invoke the root `bootstrap.sh` checkout
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
  the only initial tool-container consumer; `shimmy catalog verify` inherits it
  through Skopeo, while other runtimes remain unchanged.
- Any Shimmy-defined user-facing environment variable must use the `SHIMMY_` prefix, including image overrides, pull or build flags, opt-in behavior switches, and secret-name selectors.
- Update bootstrap and install code, tests, and README together when behavior changes.
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
- For installed shims already selected on `PATH`, invoke the normal tool name such as `rg` or `jq`; do not call the resolved installed shim path. Before selecting another profile, use an absolute installed launcher for `profile status`, `profile activate <name> --dry-run`, and the exact approved `profile activate <name>` command. Require separate confirmation before adding `--stop-running`; never substitute direct Podman machine provisioning, deletion, renaming, or adoption for Shimmy's bootstrap/profile/uninstall control-plane transactions. Source the selected profile's `shell-init.sh` only after activation when PATH initialization is needed. Agent tool calls do not retain earlier sourcing, so use an absolute launcher or same-command sourcing when the target is not already on `PATH`. For source previews, use `./commands/run-tool.sh <tool> --preview-shim ...` or the concrete version runtime selected by that tool's `tool.conf`.
- Checkout bootstrap creates and activates `default` as one compensated
  lifecycle. Inspect `./bootstrap.sh --help`, use a disposable absolute
  `XDG_CONFIG_HOME` for validation, and do not add a hidden activation or
  machine-provisioning step. Bootstrap never accepts `--stop-running`.
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
- Canonical skill changes never authorize a repository `.agents/skills/`
  adapter tree. Installed active-profile bundles own exact direct links in the
  user's skill root and reconcile them only through profile activation,
  shim lifecycle, or `shimmy ai-skill repair`.

## Test concurrency

- Prefer the test runner’s default bounded parallel execution when two or more
  independent groups are selected.
- Use `--jobs 3` when stating concurrency explicitly.
- Use `--serial` only to diagnose a failure, verify known order-sensitive
  behavior, run a single group where concurrency has no benefit, or satisfy an
  explicit user requirement.
- Treat retained-plan test commands as acceptance outcomes unless the user
  explicitly requires the exact invocation. If a plan requests a broad serial
  run without explaining why, challenge or replace it with parallel execution
  and rerun only failures serially.
  
## Negative Test Discipline

- Do not add rejection, absence, non-existence, or non-emission tests by default. The fact that an implementation rejects something, no longer supports something, or currently omits something does not by itself make that behavior a testable system invariant.
- Prefer tests that positively prove the required observable behavior. Do not add coverage whose only purpose is to prove that an alternative behavior, old feature, field, file, option, output string, or implementation artifact does not exist.
- Negative tests are appropriate when they protect a durable system invariant such as a security or privilege boundary, destructive-action safeguard, ownership or isolation rule, secret-redaction requirement, schema or data-integrity constraint, transactional rollback guarantee, or explicitly supported public compatibility contract.
- Do not infer a permanent invariant from the current implementation, from a removed feature, or from the existence of a rejection branch.
- Before adding a negative test, search existing coverage for an equivalent proof. Keep one authoritative proof of an invariant; do not repeat generic rejection coverage in command-specific tests when a shared test already establishes the same contract.
- If it is plausible that the proposed rejection or absence behavior should be a durable invariant but that status is not already explicit, **stop before adding the test and ask the user**: `Should <specific behavior> be treated as a permanent Shimmy invariant and protected by a negative test?` Do not assume the answer is yes.
- If the user does not designate the behavior as an invariant, omit the negative test.
- When a negative test is approved, use the lowest-cost proof available. Prefer adding an assertion to an existing scenario over creating another fixture, bootstrap, profile transition, subprocess, or container execution solely to prove rejection or absence.
- When removing a compatibility surface, remove obsolete forwarding paths, aliases, fixtures, and tests together. Do not automatically add coverage proving that the obsolete interface remains rejected. Apply the invariant decision rule above if permanent rejection might itself be part of the intended contract.

## Refactoring Lessons Learned

- Coordinate directory renames across source comments, context links, test
  discovery, and historical plans so stale references do not recreate the old
  layout in later work.
- During staged filesystem replacement, preserve the last valid marker or
  manifest until the new state is committed atomically, so failures leave the
  previous state intact and invalid partial state is rejected.
- Treat a schema or owned-format identity change as one review unit. Inventory and update every producer, consumer, validator, fixture, transaction boundary, and rollback path together.
- Validate generated shell artifacts by inspecting and exercising the rendered output. Correct-looking renderer source does not prove that quoting, escaping, or expansion survived generation.
- Test sourced POSIX entrypoint failures under callers with `set -e`, including ordinary and conditional sourcing. The final status-producing command can determine whether cleanup runs and whether the caller can recover.
- Classify broad terminology-search matches by behavior before editing them. Do not mechanically replace terms that remain accurate in a different subsystem.
- Keep resources with different ownership and lifecycle boundaries behind separate commands and tests, even when one workflow initially creates both.
- Before removing a compatibility surface, map its tests to the invariants they protect. Remove obsolete inputs and fixtures while retaining coverage for malformed state, unsafe paths, collisions, isolation, ownership, and unknown options.
- When removing a compatibility surface, remove every forwarding path,
  equivalent environment or argument alias, fixture, and test together.
- Compare generated guidance with its canonical source semantically before regeneration. Byte-for-byte reproducibility demonstrates determinism only after the canonical source contains all guidance worth preserving.
