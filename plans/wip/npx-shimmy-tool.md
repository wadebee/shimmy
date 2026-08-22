# General-purpose npx Shimmy tool
**Status:** in-progress

## Objective

Add one independently addable `npx` Shimmy tool that runs the npm package
executor in an OCI container without requiring a host Node.js installation.

Success means:

- `shimmy shim add npx` installs a normal profile-owned tracking `npx` shim,
  while `shimmy shim add npx@24.18` installs the initial version explicitly as
  a pinned default;
- the command runs the official Node 24 LTS image on native `linux/amd64` and
  `linux/arm64` through Shimmy's existing platform and image helpers;
- the current directory is available read-write at `/work`, stdin works in
  pipelines, and interactive terminals receive a TTY;
- image override, version-owned pull refresh, source preview, catalog
  validation/publication, profile and shim synchronization, installed smoke
  testing, documentation, and canonical/profile-materialized agent guidance
  follow existing tool contracts; and
- `npx --yes node-llama-cpp@3.19.1 inspect gpu` is exercised as an observational
  package-execution diagnostic, with the detected compute backend recorded.

Explicit exclusions:

- public `node` or `npm` shims;
- a multi-command tool/package abstraction or any shared catalog schema change;
- persistent npm cache, host `HOME`, host `~/.npm`, private-registry credential,
  or project-independent configuration mounts;
- automatic `--yes` or `--no` injection into user commands;
- Podman machine creation, replacement, provider changes, or changes to the
  existing activation contract;
- `/dev/dri` passthrough, patched Mesa/Vulkan packaging, or a promise of GPU
  acceleration from the official Node image;
- model download, model storage, chat/inference workflows, or a dedicated
  `node-llama-cpp` image; and
- implementation of the future multi-command Shimmy design.

## Target layout and terminology

`npx` is the sole **tool** and sole installed public command. `24.18` is the
initial **concrete version label**, backed by Node `24.18.0` LTS. A **shim** is
the profile-local installed `npx` launcher plus its installed versions and
tracking/pinned policy. The container includes `node`, `npm`, and `npx`, but
only `npx` is a Shimmy command.

```text
tools/npx/
├── SKILL.md
├── guide.md
├── tests/
│   └── npx.sh
├── tool.conf
└── versions/
    └── 24.18/
        ├── image.conf
        ├── refresh.sh
        ├── run.sh
        └── smoke.conf
```

Tool directories deliberately do not contain `CONTEXT.md` in the current
repository architecture. `README.md` owns the catalog guide link. The default
catalog discovers the complete tool metadata; profiles materialize only
installed versions and resolve `<tool>|<version>` directly to the concrete
runtime. No shared dispatcher or tool-name routing map is required.

### Publication and profile update process

Repository changes and installed-profile adoption are separate transactions:

1. A new npx version is added as a complete
   `tools/npx/versions/<major.minor>/` directory. Changing the catalog default
   also updates `tools/npx/tool.conf` in the same reviewed commit. Existing
   concrete-version metadata is never silently rewritten to represent a
   different Node release, and prior version directories remain available so
   profiles with pinned defaults or exact slots can validate during adoption.
2. From a clean attached local `main` checkout at that commit, `shimmy catalog
   publish` validates and publishes a new immutable retained generation of the
   installation-owned `default` catalog. Publication changes registry
   current/previous authority only; it does not rewrite any profile pin.
3. `shimmy profile sync` is the active invoking profile's adoption operation.
   It resolves exactly `refs/heads/main`, snapshots registry-current default
   catalog, advances a tracking npx default to that generation's catalog
   default, preserves a pinned npx default and exact versions, prepares every
   selected image, validates regenerated control/shim assets and skill bundles,
   and commits atomically. It does not add npx to a profile that does not
   already own the shim.
4. `shimmy shim sync npx` and `shimmy shim sync npx@<version>` never adopt a
   newer catalog generation or control commit. They use only the invoking
   profile's existing pin: unqualified `npx` advances a tracking default within
   that pin and prepares every installed npx version; an exact selector
   prepares only that already installed version. Pinned defaults do not
   advance.
5. To adopt a newer npx version while keeping explicit pinning, first run
   `shimmy profile sync` to adopt a generation containing it, then
   `shimmy shim add npx@<version>` to add it as an exact slot and `shimmy shim
   set-version npx@<version>` to make it the default. The prior default becomes
   exact and the shim policy remains pinned.
6. `shimmy catalog rollback` swaps registry current/previous only. Existing
   profiles remain unchanged until an explicit `profile sync`; no catalog or
   shim command rewrites `image.conf` or adopts upstream-tag drift.

## Recorded design decisions

1. **One command, no catalog extension.** Implement only `tools/npx`. Do not
   expose `node` or `npm`, create aliases, add sibling tools, or teach Shimmy
   that one tool owns several public commands. A future plan will evaluate that
   capability independently.

2. **External official image.** Use `image_source=external` with upstream
   `docker.io/library/node:24.18.0-bookworm` and the planning-time top-level
   multi-platform index
   `docker.io/library/node@sha256:5711a0d445a1af54af9589066c646df387d1831a608226f4cd694fc59e745059`.
   The full Bookworm image is preferred over Alpine or slim because a general
   package executor benefits from the standard buildpack dependencies and
   glibc compatibility; the larger pull size is accepted. Before committing,
   `shimmy catalog verify --tool npx@24.18 --public-only` must confirm that the
   pinned digest is still reachable and contains both required platforms.
   Upstream drift is reported, not silently adopted.

3. **Existing external-image lifecycle.** `tool.conf` declares default version
   `24.18`, an empty selector, and `--version` as the public smoke argument.
   The concrete `smoke.conf` declares only `smoke_arg=--version`; manifest v2
   identifies the runtime directly as `npx|24.18` and stores no implementation
   name. `refresh.sh pull` runs the version smoke with
   `SHIMMY_NPX_IMAGE_PULL=always`; `build` is a no-op. Shim add/sync and profile
   sync prepare the image before committing materialized state. Do not add
   central case lists.

4. **Thin POSIX runtime.** `run.sh` uses `#!/bin/sh`, `set -eu`,
   `lib/runtime/image.sh`, the version-owned `image.conf`, and
   `shimmy_podman_preflight_or_preview_require`. It resolves
   `SHIMMY_NPX_IMAGE`, accepts `SHIMMY_NPX_IMAGE_PULL=always`, invokes the
   shared `shimmy_podman_run_or_preview` helper, selects the native platform,
   and overrides the official image command with `--entrypoint npx`.

5. **Workspace and I/O contract.** Mount `$PWD` read-write at `/work`, set the
   working directory to `/work`, and keep stdin open. Add a TTY only when both
   stdin and stdout are terminals so npx prompts and interactive child CLIs
   work without corrupting pipeline output. Forward all user-supplied npx and
   child-command arguments exactly after the image reference.

6. **Ephemeral, isolated user state.** Do not mount host `HOME`, `~/.npm`, npm
   credentials, or a persistent cache. Packages absent from the mounted project
   are fetched into the disposable container cache and will generally be
   downloaded again on a later invocation. This favors isolation and avoids
   host/container cache ownership and cross-platform contamination. A cache or
   private-registry design requires a separate explicit decision.

7. **Preserve npx's consent boundary.** npx can download and execute arbitrary
   package code with network access and read-write access to the current
   directory. The wrapper must not inject `--yes`; upstream's install prompt is
   retained. The guide and tool skill must tell users to review package names,
   pin versions for repeatability, use `--yes` only intentionally, and avoid
   invoking untrusted packages in sensitive working directories.

8. **Project-local dependency caveat.** npx may prefer dependencies found in
   the mounted project. Native addons or executable artifacts installed on a
   macOS host may be incompatible with the Linux container. Document using a
   clean directory or container-compatible project dependencies when this
   occurs; do not hide `node_modules` or rewrite npx resolution semantics.

9. **GPU diagnostic is observational.** Use the pinned command
   `npx --yes node-llama-cpp@3.19.1 inspect gpu` to prove public package fetch
   and execution and record its CPU/GPU report. Lack of GPU detection does not
   fail the npx tool. Official Podman guidance says macOS GPU use requires a
   LibKrun-backed machine, `--device /dev/dri`, and a specialized image with
   patched Mesa/Vulkan components; none are supplied by this generic Node
   image. Do not mutate Shimmy's deterministic Podman machines or claim that
   this diagnostic validates Metal/Vulkan acceleration.

10. **Canonical skill plus profile materialization.** Add canonical
    `tools/npx/SKILL.md` beside the tool, matching current repository practice.
    Catalog publication fingerprints it; a profile with the npx shim
    materializes it as `shimmy-tool-npx` in the profile's shims bundle, and
    active-profile reconciliation owns the exact user-level direct link. Do not
    add `tools/npx/CONTEXT.md`, `versions/24.18/CONTEXT.md`, an `agent/`
    subdirectory, or generated repository `.agents/skills/` output.

11. **Catalog publication and profile adoption are distinct.** A repository
    update is unavailable to profiles until clean-main `catalog publish`
    creates a retained generation. Publication does not mutate pins. Active-
    profile `profile sync` adopts registry current plus exact main;
    profile-local `shim sync` uses only the existing pin. Tracking and pinned
    npx policies follow the update process above and must not be conflated with
    mutable upstream-tag drift.

## Verified implementation inventory

- `AGENTS.md`, `CONTEXT.md`, `CONTRIBUTING.md`, and
  `docs/prompt-shimmy-project.md` define the current tool, image, platform,
  testing, documentation, publication, profile-materialization, and canonical-
  skill boundaries.
- `commands/run-tool.sh` and `lib/catalog/catalog.sh` already discover a tool
  from `tools/<tool>/tool.conf`; `shim_name` must equal its directory, one
  default concrete version is required, and no multi-command metadata exists.
- `lib/runtime/image.sh` owns external image resolution, platform preflight,
  preview rendering, and Podman execution. The npx wrapper should consume it,
  not duplicate platform or digest logic.
- `tools/go/` is the closest external toolchain pattern: external image,
  explicit entrypoint, `$PWD:/work`, image/pull overrides, refresh hook, guide,
  canonical skill, and focused preview test.
- `tools/textual/` and `tools/task/` show conditional TTY handling for
  interactive CLIs.
- `tools/jq/versions/1.8/refresh.sh` shows the external-image pull lifecycle.
- `tests/lib/catalog.sh` validates every discovered tool's metadata, immutable
  image configuration, required platforms, and Linux/Darwin previews.
- `tests/test.sh` explicitly sources each tool-local test entrypoint; npx
  therefore requires one mechanical registration, but no runtime/catalog
  tool-name allowlist.
- `README.md` contains the manually maintained tool-to-guide table and owns the
  npx guide link.
- The historical tool-grouping plan mentions future `node`, but does not
  authorize or define a current npx implementation and is not an implementation
  dependency.
- The official Node image includes npm, and npm supplies the modern `npx`
  executable as an `npm exec` frontend. Node 24 is LTS as of planning, and the
  selected official image publishes both required Linux architectures.
- npm documentation confirms missing packages are installed into the npm cache
  and that `--yes`/`--no` controls the install prompt.
- `node-llama-cpp` 3.19.1 provides Linux x64 and arm64 prebuilt artifacts and
  documents `inspect gpu`; its execution remains an integration diagnostic,
  not repository-owned smoke metadata.
- The worktree was clean during the original planning session. This inventory
  is a verified baseline, not permission to ignore dependencies discovered
  during execution.

### Redesigned control-surface reconciliation

- The installation owns one immutable retained-generation catalog named
  `default`. `catalog publish` and `catalog rollback` change its registry
  authority without rewriting profile pins.
- Profile manifest schema 2 records either `shim=npx|tracking` or
  `shim=npx|pinned`, plus one `shim_version=npx|<version>|default` record and
  optional `shim_version=npx|<version>|exact` records; no `npx_24_18`
  implementation identity or profile-local adapter layer exists.
- `shim add`, `shim remove`, `shim set-version`, `shim sync`, and `shim test`
  are the complete profile-local npx lifecycle. Mutation requires the invoking
  profile to be active and commits image, manifest, wrapper, config, and shims-
  bundle changes together.
- `profile sync` is active-only and atomically adopts exact
  `refs/heads/main` plus registry-current default catalog. It advances tracking
  defaults, preserves pinned defaults/exact slots, prepares images, and
  reconciles validated AI-skill links.
- `catalog verify --tool npx@24.18 --public-only` owns live image-index
  verification. `profile status --format manifest`, `shim list --format
  manifest`, and `shim test npx@24.18` own installed-state inspection and
  smoke acceptance.
- Baseline bootstrap/profile creation installs jq, rg, and Skopeo only. npx
  remains an opt-in shim and its canonical `SKILL.md` is materialized only
  while npx is installed in that profile.

## Unresolved

None.

## Progress Checklist

- [~] Chunk 1 — Add, document, and verify the npx tool. Implementation and
      available native macOS acceptance checks passed on 2026-08-16. Native
      Linux `amd64`, current catalog/profile/shim sync coverage, and the
      manifest-v2 installed add/test/remove flow are required, non-deferred
      acceptance items; the installed macOS smoke remains proposed for
      deferral because its native source-runtime smoke passed. Human review
      remains pending.

## Execution protocol

For every chunk:

1. Read `AGENTS.md`, `CONTEXT.md`, every child context on the path to a changed
   file, this plan, and the chunk's target files.
2. Execute only that chunk's scope.
3. Run its verification checklist and record `[x]`, `[ ]`, or `[~]` with notes.
4. Update the cumulative **Lessons learned** block.
5. Summarize changes, tests, failures, uncertainties, and remaining risks.
6. Stop for human review and explicit acceptance before starting the next
   chunk.

Repository paths in this plan are relative to `<repo>` so it remains portable
across workstations and sessions.

## Chunk 1 — Add, document, and verify the npx tool

### Goal

Leave the repository with a complete, independently addable npx tool whose
metadata, runtime, lifecycle, documentation, tests, and native acceptance
evidence conform to existing Shimmy contracts.

### Files

Primary change surface:

- `tools/npx/tool.conf`
- `tools/npx/guide.md`
- `tools/npx/SKILL.md`
- `tools/npx/tests/npx.sh`
- `tools/npx/versions/24.18/run.sh`
- `tools/npx/versions/24.18/image.conf`
- `tools/npx/versions/24.18/smoke.conf`
- `tools/npx/versions/24.18/refresh.sh`
- `tests/test.sh`
- `README.md`
- `plans/wip/npx-shimmy-tool.md` for evidence-backed progress and lessons
  updates

Newly discovered required files may be added only when necessary to satisfy an
existing generic contract. A need to change shared catalog, dispatcher,
installer, runtime, or profile code is a material divergence and must return to
review instead of expanding this chunk silently.

### Implementation requirements

1. Create the target layout and metadata exactly as recorded above. Keep
   `tool_selector_env=` empty and use version label `24.18`.
2. Configure the official Node external image with the recorded mutable
   upstream discovery tag, immutable top-level index digest, public registry
   access, and exactly `linux/amd64` plus `linux/arm64` platform entries.
3. Implement the thin runtime with shared helpers, `SHIMMY_NPX_IMAGE`,
   `SHIMMY_NPX_IMAGE_PULL=always`, conditional TTY behavior, always-open stdin,
   `$PWD:/work:rw`, `/work` as working directory, and `--entrypoint npx`.
   Preserve argument order and quoting.
4. Add an executable external-image refresh hook supporting `pull` and the
   existing no-op `build` contract. Keep every runnable shell file executable.
5. Add focused preview-contract coverage for the entrypoint, image override,
   pull flag, working-directory mount, stdin mode, conditional TTY behavior
   where the harness can observe it, and absence of host-home/cache/credential
   mounts. Rely on generic catalog tests for schema and four host-platform
   preview combinations rather than duplicating them.
6. Write `guide.md` with upstream links, the pinned image, command examples,
   environment variables, mounts/I/O, ephemeral cache behavior, network and
   arbitrary-code warning, version pinning guidance, local `node_modules`
   compatibility caveat, and the observational `node-llama-cpp` diagnostic.
7. Write canonical `SKILL.md` with installed/source workflows, current
   behavior, safety rules, validation commands, Podman escalation guidance,
   and the explicit GPU boundary. Ensure catalog publication fingerprints it
   and shim lifecycle can materialize it in the profile shims bundle. Do not
   generate repository adapters.
8. Add `npx` in alphabetical order to the `README.md` tool guide table. Do not
   change bootstrap/profile-create defaults; npx remains opt-in through
   `shimmy shim add npx` or exact `shimmy shim add npx@24.18`.
9. If the recorded Node digest has drifted or is unreachable, stop and report
   the newly resolved top-level digest and platform evidence for review rather
   than silently changing the recorded decision. Use `shimmy catalog
   verify --tool npx@24.18 --public-only` only after a retained catalog
   generation containing npx is available.
10. Update this plan only with verification states, durable lessons, and exact
    partial-item notes. Human acceptance remains pending until explicitly
    granted.
11. Treat repository publication and profile adoption as explicit lifecycle
    steps, not side effects of adding the source tree. Record the catalog
    generation, profile pin, npx policy/default role, and exact command used for
    installed acceptance. Do not claim `shimmy shim sync` adopted registry
    current.

### Verification checklist

- [x] Confirm the worktree baseline and preserve unrelated user changes. The
      worktree was clean before implementation.
- [x] Confirm all new runnable shell files pass POSIX syntax checks and retain
      executable mode.
- [x] Run `./commands/run-tool.sh npx --preview-shim --version` and verify the
      pinned image, native platform, `/work` mount, working directory,
      `--entrypoint npx`, and stdin/TTY contract.
- [x] Run the focused `tools/npx/tests/npx.sh` coverage through the repository
      test runner and confirm override/pull/isolation assertions pass.
- [x] The implementation-time `./tests/test.sh` run confirmed catalog
      discovery, metadata/image validation, all platform previews, installation,
      lifecycle, and existing regressions. All then-current 145 tests passed
      after updating the canonical tool-skill count from 19 to 20. This is
      historical pre-redesign evidence, not proof of the current sync surface.
- [x] Run `git diff --check` and inspect the complete diff, including mode bits
      and the absence of unintended shared-code or generated-adapter changes.
- [x] The historical
      `./commands/images.sh verify --shim npx --public-only` run confirmed the
      pinned reference is a reachable OCI index with `linux/amd64` and
      `linux/arm64`, public access, and `upstream=current`. The redesigned
      equivalent is `shimmy catalog verify --tool npx@24.18 --public-only` from
      an installed profile whose pinned retained generation contains npx; do
      not recreate the historical command or selectors.
- [~] Run current focused catalog/profile/shim lifecycle coverage and confirm
      the redesigned update invariants: catalog publication does not mutate
      profile pins; active `shimmy profile sync` adopts registry current and
      advances tracking npx while preserving pinned npx; `shimmy shim sync npx`
      uses only the existing pin; exact sync prepares only an installed exact
      version; and each mutation prepares the image and validates the shims
      bundle before commit. Static inspection confirms the implementation
      routes and generic tests exist, but this post-redesign acceptance run has
      not been recorded in this plan. It is required before final acceptance
      and is not proposed for deferral.
- [~] On native Linux `amd64`, run the version-owned `npx --version` smoke and
      record host platform, concrete version, command, exit status, and output.
      No native Linux `amd64` host was available in this session. Preview and
      index verification passed, but neither substitutes for the required
      native smoke. Run `./commands/run-tool.sh npx --version` on native Linux
      `amd64` before feature acceptance. Current contributor policy requires
      this native result, so it is not proposed for deferral.
- [~] On native Apple Silicon macOS `arm64`, run the same version-owned smoke
      through the correctly activated existing Shimmy profile and record the
      same evidence. Do not provision or replace a Podman machine. Source
      runtime command `./commands/run-tool.sh npx --version` exited 0 on native
      Darwin `arm64` and printed `11.16.0`; it ran Node 24.18.0 for
      `linux/arm64` through the existing reachable engine without machine or
      activation changes. The native runtime is accepted, but the
      installed-profile portion was deferred under the former default/upstream
      model and that reason is no longer current acceptance evidence. Under the
      redesigned surface, use an active profile pinned to a generation
      containing npx, add `npx@24.18` if needed, and run `shimmy shim test
      npx@24.18` plus the installed `npx --version`. Use the exact supported
      `shimmy profile activate <name> --dry-run` and separately approved
      activation workflow when a profile switch is required. Explicit deferral
      remains requested until that installed smoke is recorded.
- [x] On at least one accepted native host, run
      `npx --yes node-llama-cpp@3.19.1 inspect gpu`; confirm package fetch and
      CLI execution complete, record the reported compute backend, and treat
      lack of GPU detection as an expected observational result rather than an
      npx failure. `./commands/run-tool.sh npx --yes node-llama-cpp@3.19.1
      inspect gpu` exited 0 on Darwin `arm64`; it reported Debian 12 `arm64`,
      Node 24.18.0, node-llama-cpp 3.19.1, CPU information, and no GPU backend.
- [~] From an active disposable profile pinned to a retained generation that
      contains npx, run `shimmy shim add npx@24.18`, inspect `shimmy profile
      status --format manifest` and `shimmy shim list --format manifest`, run
      `shimmy shim test npx@24.18` and installed `npx --version`, confirm the
      `shimmy-tool-npx` bundle/link materialization, then run `shimmy shim
      remove npx` and prove only npx-owned wrapper/version/config/skill assets
      are removed. The historical disposable upstream-profile run proved the
      former install/preview/uninstall route and recorded the obsolete
      `npx|24.18|npx_24_18` implementation identity; it is not manifest-v2
      evidence. The redesigned end-to-end installed flow remains required and
      is not proposed for deferral.
- [x] Reconcile every checklist item in this plan. Any unavailable second-host
      native run must be marked `[~]` with what passed, what remains, impact,
      proposed next action, and whether explicit deferral is requested.

### Human review gate

The reviewer confirms that the npx-only public surface, official Node image,
workspace/I/O behavior, isolation choices, security documentation, metadata
and lifecycle tests, catalog-publication/profile-adoption/shim-sync boundaries,
manifest-v2 installed flow, profile-materialized skill, native smoke evidence,
and observational GPU result match the approved scope. The reviewer must
explicitly accept or defer every `[~]` item; the two redesigned lifecycle items
and the native Linux smoke marked non-deferred block acceptance until
completed. No future `node`/`npm` or multi-command work begins from this
acceptance.

## Risk register

| Risk | Impact | Handling |
|---|---|---|
| Arbitrary npm package code receives network and read-write workspace access. | A malicious or mistyped package can exfiltrate data visible in the workspace or modify files. | Preserve npx's prompt, do not auto-consent, mount no home/credentials, document package review and version pinning, and run only in an appropriate directory. |
| The full Bookworm image is large and its pinned OS/npm packages age. | First pull is slower and the immutable digest does not receive security fixes automatically. | Accept the compatibility tradeoff, verify through `shimmy catalog verify`, review digest/version rotations in source, publish a new immutable catalog generation, and require explicit profile adoption. `shimmy shim sync` alone never adopts upstream drift or registry current. |
| The npm cache is ephemeral. | Repeated invocations can redownload packages and require network access. | Document this intentional isolation default; plan persistent cache and credentials separately if experience proves the cost unacceptable. |
| Mounted macOS `node_modules` contains host-native artifacts. | npx may select an incompatible local executable or native addon inside Linux. | Document clean-directory/container-compatible dependency workarounds; do not conceal project dependencies or alter resolution semantics. |
| Root container processes can create files with inconvenient ownership on Linux. | Generated project files may need ownership correction depending on rootless Podman mapping. | Verify native behavior and document observed limitations; a cross-tool user-mapping policy is outside this tool addition. |
| Interactive child CLIs depend on correct terminal detection. | Unconditional TTY allocation breaks automation; no TTY breaks prompts and interactive tools. | Keep stdin open and allocate `-t` only when both standard input and output are terminals; cover preview behavior. |
| `node-llama-cpp inspect gpu` is mistaken for proof of Apple GPU support. | Users may expect Metal/Vulkan acceleration that the generic image and machine do not provide. | Label it observational, pin the package version, record output, and state the LibKrun, device, and patched-Mesa prerequisites explicitly. |
| A shared-code change appears necessary during implementation. | Scope can expand into the deferred multi-command architecture. | Stop at the divergence and return to review; do not modify shared catalog or dispatch behavior in this chunk. |

Rollback respects separate authorities. Revert the `tools/npx/` tree and README
entry in source and publish the reviewed replacement generation, or use
`shimmy catalog rollback` only when its retained previous generation is the
intended registry authority. Neither operation rewrites existing profile pins.
Each affected active profile explicitly runs `shimmy profile sync` to adopt
registry current, while a profile that should only remove its installed command
runs `shimmy shim remove npx`. The pinned image remains recoverable in local
Podman storage and git history; no host cache or credential state is owned by
this tool.

## Lessons learned

### Initial

- Shimmy defines one stable tool directory and one `shim_name`; a profile-local
  shim materializes that tool's installed versions behind one public command.
  npx-only fits without shared changes, whereas a combined Node/npm/npx surface
  requires a separate architecture decision.
- The official Node image already supplies npm and npx, so a local Containerfile
  would add maintenance without solving a required dependency for this scope.
- A practical npx container has two distinct boundaries: arbitrary downloaded
  code can modify the mounted workspace, while keeping home, npm credentials,
  and caches unmounted materially limits ambient authority.
- macOS GPU acceleration is not a property of npx or `node-llama-cpp` alone.
  Podman documents a LibKrun machine, `/dev/dri` passthrough, and specialized
  patched Mesa/Vulkan userspace; the generic Node image is therefore suitable
  for an observational diagnostic, not a GPU acceptance promise.
- Current repository guidance supersedes the generic creation skill where the
  latter mentions tool-local `CONTEXT.md` or `agent/SKILL.md`: this repository
  prohibits tool `CONTEXT.md` files and stores canonical guidance directly at
  `tools/<tool>/SKILL.md`.

### Implementation 2026-08-16

- `tests/test.sh` currently registers each tool-local test explicitly, despite
  the planning inventory expecting discovery. Adding a tool therefore also
  requires the minimal source-and-run registration and an increment to the
  canonical tool-skill inventory assertion.
- Keeping stdin open with a separate conditional `-t` produces a previewable
  contract: non-terminal execution always renders `-i` and never `-t`, while
  interactive execution can add `-t` without conflating the two behaviors.
- The official Node image executed the pinned public package on native
  `linux/arm64` but reported no GPU backend, confirming that package execution
  is functional and GPU availability remains outside this generic wrapper's
  acceptance boundary.

### Control-surface reconciliation 2026-08-22

- Catalog publication, profile adoption, and shim refresh are three different
  operations. Only `shimmy profile sync` adopts registry-current catalog and
  exact main; `shimmy shim sync` is intentionally bounded by the existing
  profile pin.
- Tracking policy controls whether profile/shim synchronization may advance the
  default slot to the pinned generation's catalog default. Exact version
  selection does not itself create a second update authority; explicit pinned
  promotion uses `shimmy shim add npx@<version>` followed by `shimmy shim
  set-version npx@<version>`.
- The old implementation-name record and profile uninstall workflow are not
  valid acceptance evidence after manifest v2. Current installed proof must
  cover shim add/list/test/remove plus profile status and the npx shims bundle.
- Canonical `tools/npx/SKILL.md` remains repository-owned, while the catalog
  fingerprints it and active profiles materialize/link it. Repository
  `.agents/skills/` adapters are not part of this lifecycle.

## Session bootstrap

For a fresh implementation session:

1. Read `AGENTS.md`, `CONTEXT.md`, `CONTRIBUTING.md`,
   `docs/prompt-shimmy-project.md`, this entire plan,
   `plans/wip/redesign-control-surface.md`, `commands/{catalog,profile,shim}.sh`,
   `lib/update/profile.sh`, `lib/shim/shim.sh`, `tools/npx/`,
   `tests/lib/catalog.sh`, current catalog/profile/shim command tests, and the
   README guide table.
2. Recheck worktree status and current upstream Node 24.18 image metadata.
3. Resume only **Chunk 1 — Add, document, and verify the npx tool** at its
   remaining verification and human review boundary; do not redo completed
   implementation without evidence of a regression.
4. Preserve these non-negotiable boundaries: npx is the only public command;
   one immutable default catalog; profile manifest v2; catalog publication,
   profile adoption, and shim refresh remain distinct; no host home, cache, or
   credentials; no machine lifecycle or GPU-device/image work; no generated
   repository skill adapters.
5. Run the current non-deferred catalog/profile/shim update coverage and
   manifest-v2 installed npx add/list/test/remove flow. Record the catalog
   generation, profile pin, npx tracking/pinned mode, default/exact role, image
   preparation result, bundle/link result, commands, and exit status.
6. Mark unavailable native-host checks partial with complete notes, but do not
   propose deferring the required native Linux `amd64` smoke. Update lessons
   learned, summarize the result, surface every `[~]` item distinctly, and
   stop at the Chunk 1 human review gate.
