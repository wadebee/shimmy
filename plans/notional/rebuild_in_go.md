# Rebuilding Shimmy’s Control Plane in Go

## Executive assessment

**I would restart Shimmy’s control plane in Go now.** I would keep a deliberately tiny POSIX layer for bootstrap and shell integration, keep the existing POSIX tool shims initially, and make the installed management plane a compiled Go application with Cobra as its CLI adapter.

More importantly, I would **not port the current shell implementation line by line**. I would use the existing implementation, tests, completed plans, and work-in-progress plans as an unusually detailed body of requirements discovery, write the product requirements document that Shimmy never had at its beginning, and then design a new internal model around those requirements.

That conclusion is based less on Go being “faster than shell” than on what Shimmy has become. The repository now describes a stateful control plane responsible for profiles, immutable catalog generations, engine ownership, registry policy, filesystem transactions, startup integration, AI-skill reconciliation, locking, rollback, destructive machine lifecycle, multi-architecture image contracts, and source provenance. The project explicitly defines the repository as both its source catalog and source control plane, while profile mutations use staged validation, locks, exact commit checks, and compensating rollback. fileciteturn5file0L2-L2

The ongoing engine-lifecycle work reinforces that trajectory. It now specifies shared and isolated engines, durable lifecycle journals, exact ownership evidence, service recycling, migration of legacy machines, workload guards, ambiguous-state handling, and transaction ordering; that plan contains dozens of explicit design decisions and still explicitly requires preserving the POSIX-shell architecture. fileciteturn20file0L2-L2 The multi-architecture work likewise introduces strict image schemas, index-digest validation, cache identities, architecture normalization, registry verification, and cross-platform acceptance requirements. fileciteturn19file0L2-L2

That is the inflection point. **POSIX shell remains excellent glue. Shimmy’s control plane is no longer principally glue.**

My recommended target is therefore:

| Concern | Recommended implementation |
|---|---|
| First-contact bootstrap | Very small POSIX `bootstrap.sh` |
| Parent-shell activation | Generated POSIX `shell-init.sh` |
| `shimmy admin/profile/catalog/shim/ai-skill` | Go |
| CLI command tree and flags | Cobra |
| Domain/state/transaction logic | Plain Go packages, independent of Cobra |
| Git operations | Go adapter around installed `git`, initially |
| Podman operations | Go adapter around installed `podman` |
| Internal machine-owned state | Strongly consider versioned JSON rather than shell assignments |
| Human/public manifest output | Preserve only where the PRD says it is an API |
| Tool runtime wrappers | Keep POSIX initially |
| Release installation | Precompiled native binaries; users should not need a Go toolchain |
| Developer build | Go toolchain becomes a contributor prerequisite |
| Control-plane versioning | Prefer one installation-wide control-plane version rather than copies per profile |

The last row is potentially more important than the language choice. Today each profile materializes a control plane and records its source commit, while an installation-wide active record and engine/catalog state span profiles. fileciteturn5file0L2-L2 If independent per-profile **control-plane versions** are not an explicit product requirement, I would remove that architecture during the rewrite. A single installation-wide Go control plane operating on profile data would eliminate an entire class of mixed-version schema and migration problems.

The timing is unusually favorable. Shimmy is unreleased, and the project has already used an intentional hard-cut strategy for an unreleased redesign: the completed control-surface plan explicitly rejected compatibility aliases and old-state readers rather than preserving obsolete concepts. fileciteturn7file0L2-L2 You have essentially the ideal opportunity for an architectural reset and almost none of the normal customer-migration liabilities.

**My recommendation is therefore stronger than “Go is worth evaluating”: freeze new shell-control-plane expansion, write the PRD, and make the Go control plane the next architectural baseline.**

## What Shimmy has actually become

The original POSIX decision was sound for the product Shimmy initially appeared to be. The current README still introduces Shimmy as small POSIX shell wrappers around `podman run`, and the documented prerequisites are `/bin/sh`, Git, Podman, and a reachable rootless engine. fileciteturn4file0L2-L2 If the project were still primarily:

```text
tool arguments
      |
      v
small shim
      |
      v
podman run ...
```

I would probably argue against rewriting it.

But the control plane surrounding those wrappers has become much more substantial.

The installed command hierarchy already contains `admin`, `profile`, `catalog`, `shim`, and `ai-skill`; profiles are independently materialized installations; catalogs retain immutable generations; profiles pin catalog generations; engine and registry authority are separately tracked; and the active profile owns mutation and user-integration authority. fileciteturn4file0L2-L2

The completed control-surface redesign goes further. Its definition of “control plane” encompasses the launcher, management commands, shared libraries, tests, and control skills materialized into profiles. It defines strict profile/catalog records, lock ordering, staged filesystem operations, active versus invoking profile semantics, dry-run planning, catalog provenance, synchronization, rollback, skill reconciliation, startup ownership, and command-specific failure semantics. fileciteturn7file0L2-L2

The repository structure itself shows the effect. The `commands` directory contains, among other things, a roughly 36.8 KB custom `help.sh`, 16.2 KB `profile.sh`, 10.5 KB `agent-preflight.sh`, 9.4 KB `shim.sh`, and 8.5 KB `admin.sh`. fileciteturn16file0L2-L2 The test infrastructure has a roughly 28.4 KB `runner.sh`, plus support and test-driver code and command/library test trees. fileciteturn9file0L2-L2 File size is not a software-quality metric, but here it is useful evidence that Shimmy has had to build significant CLI and testing infrastructure itself rather than merely expressing domain behavior.

The work-in-progress plans demonstrate where this is going rather than merely where it has been. Several individual design plans are already tens of kilobytes long: engine lifecycle, multi-architecture images, registry redirects, profile activation, profile create/clone, and other lifecycle work. fileciteturn17file0L2-L2 Again, document size by itself proves nothing, but the content of those plans shows increasingly intricate state transitions and safety invariants. fileciteturn19file0L2-L2 fileciteturn20file0L2-L2

### The “no dependencies” premise deserves revision

I would challenge one part of the original rationale: **the current shell implementation is not actually runtime-dependency-free.**

At the product level, Shimmy already requires Git and Podman in addition to `/bin/sh`. fileciteturn4file0L2-L2 At the implementation level, representative catalog logic invokes `awk`, `find`, `grep`, `mktemp`, `sort`, `basename`, `/bin/sh`, and either `sha256sum` or `shasum`, including platform-specific fallback logic for SHA-256. fileciteturn13file0L2-L2

So the real trade is not:

```text
POSIX = no dependencies
Go    = dependencies
```

It is closer to:

```text
Current shell control plane
    /bin/sh
    + Unix userland behavior
    + Git
    + Podman
    + platform-specific utility differences

Precompiled Go control plane
    one native shimmy executable
    + Git
    + Podman
    + the operating-system interfaces Shimmy actually needs
```

Cobra does introduce a **build-time source dependency**, and Go modules track and authenticate direct and indirect module content through `go.mod`/`go.sum`; the Go command verifies downloaded module content against cryptographic hashes. citeturn8search3 That is materially different from requiring an end user to install a language runtime. A released precompiled executable can be consumed without installing the Go toolchain; Go itself is routinely distributed to users as precompiled binary packages, and its toolchain supports architecture/OS-targeted compilation. citeturn6search0turn6search4

I would therefore restate Shimmy’s desirable property as:

> **A Shimmy user should not need to install a programming-language runtime, compiler, or package ecosystem before using Shimmy.**

A prebuilt Go executable can preserve that property.

### The more consequential architectural question

There is an even bigger question hiding behind the language migration:

> **Does a profile actually need its own copy/version of the control plane?**

Today Shimmy records control source provenance per profile, materializes commands/libraries/tests into profiles, and distinguishes an “invoking profile” from the installation-wide “active profile.” fileciteturn5file0L2-L2 The redesign plan likewise installs `bin/`, `commands/`, `lib/`, `tests/`, and other control assets below each profile. fileciteturn7file0L2-L2

That design made sense while shell source files *were* the installed application. In a compiled architecture it deserves a fresh requirements decision, not automatic preservation.

If two profiles can contain two different control-plane revisions while both interact with one installation-wide catalog, active record, engine registry, and external Podman state, Shimmy eventually has to reason about something like:

```text
profile A control schema/version
             \
              +--> shared installation state
             /
profile B control schema/version
```

That naturally creates compatibility, migration, writer/reader ordering, and rollback questions—even before Shimmy has external customers.

Unless “different shells must be able to use different Shimmy control-plane releases concurrently” is a genuine product requirement, I would instead target:

```text
                 installation
                     |
              shimmy binary vX
                     |
        +------------+------------+
        |            |            |
     profile A    profile B    profile C
       data         data         data
        |            |            |
        +--------- catalog --------+
                     |
                  engines
```

Profiles can still independently own shim selections, catalog pins, redirects, startup selection, skill bundles, and engine bindings. They simply would not carry independent implementations of the state machine that interprets those records.

That change could simplify Shimmy more than replacing shell with Go by itself.

## Performance and testability

The most compelling Go argument is **development-cycle latency**, but it should be stated precisely.

I would not expect merely replacing `/bin/sh` with a Go executable to make Podman machine initialization, image pulls, registry access, Git fetches, VM starts, or service restarts dramatically faster. Those are external operations whose latency is dominated by Podman, Git, the filesystem, virtualization, or the network.

The opportunity is in everything Shimmy currently does *around* those operations.

Representative catalog validation currently launches external commands repeatedly for configuration parsing, file walking, sorting, hashing, and validation. fileciteturn13file0L2-L2 Moving those operations into one process eliminates repeated shell parsing and subprocess creation and, more importantly, makes that logic callable directly from tests rather than only through process boundaries.

The current test suite already tries to compensate for its cost. It has a canonical group registry, runs up to three workers, creates private logs, splits lifecycle acceptance into separate selectable groups, prepares reusable checkout templates, and has explicit timing instrumentation. fileciteturn6file0L2-L2 That is evidence that test-harness execution is already an architectural concern, not merely an inconvenience.

Go directly addresses several of those pain points. Its standard testing tool automates package-level tests, and `go test` caches successful package test results in package-list mode so unchanged successful tests can be reused. citeturn8search7 Go also has native coverage-guided fuzzing, which is particularly attractive for Shimmy’s strict parsers, path validators, selectors, record codecs, manifest encoders, and hostile/corrupted-state handling. citeturn6search2

Cobra also exposes useful in-process CLI seams. `Command.SetArgs` explicitly exists for overriding `os.Args`, particularly for testing; `SetOut`, `SetErr`, and `SetIn` redirect command I/O; and `ExecuteC`/`ExecuteContextC` allow the command tree to execute within the test process. citeturn7view0turn7view1turn7view2turn7view3

That enables a very different test pyramid.

### A better test pyramid

I would structure the rewritten suite approximately like this:

| Layer | What it exercises | Real external processes? | Expected role |
|---|---|---:|---|
| Domain unit tests | validation, state transitions, planners, ownership rules | No | Vast majority |
| Codec tests | profile/catalog/engine/journal parsing and encoding | No | Very large |
| Fuzz tests | malformed manifests, paths, selectors, config records | No | Continuous/CI subset |
| CLI tests | Cobra arguments, flags, output, exit mapping | No | Large |
| Application tests | use cases with fake filesystem/runner/clock where needed | Usually no | Large |
| Adapter integration | actual filesystem, actual Git repo, fake Podman | Sometimes | Focused |
| Bootstrap contract | POSIX sourcing behavior and generated shell init | Yes, shell only | Small |
| Native Podman acceptance | engine, VM, registry, destructive lifecycle | Yes | Small and deliberately expensive |

The current shell suite necessarily mixes more of those concerns because sourced libraries, subprocess boundaries, temporary files, shell globals, command stubs, and executable scripts are the natural seams of shell. The Go rewrite gives you the option of expressing “what activation *plans* to do” separately from “execute these six Podman/filesystem actions,” which should make most activation behavior testable without booting or mutating anything.

A particularly useful architecture would make mutation commands follow:

```text
Parse request
     |
     v
Load + validate state
     |
     v
Build immutable Plan
     |
     +------> dry-run renderer
     |
     v
Preflight external world
     |
     v
Record durable intent
     |
     v
Apply operations through adapters
     |
     v
Validate result
     |
     v
Commit authoritative state last
```

That is not a new semantic model for Shimmy. It is a clearer implementation of invariants the current project already emphasizes: staged validation, durable lifecycle intent, compensating rollback, and commit-last authority. fileciteturn5file0L2-L2 fileciteturn20file0L2-L2

### Do not promise yourself a speedup number yet

I would explicitly resist setting “Go must be 10× faster” or similar as the rationale. The right pre-rewrite move is to establish a few reproducible baselines using Shimmy’s existing timing facility. The suite already supports stable setup/group/total timing records. fileciteturn6file0L2-L2

Useful benchmark cases would be:

| Workload | Why measure it |
|---|---|
| Root/group help generation | isolates CLI-framework overhead |
| `profile status` against fixture state | common read-heavy control path |
| `catalog tools` / full catalog validation | parser/walk/hash-heavy path |
| Profile activation dry-run | complex planner without live mutation |
| Complete source-only test suite | developer feedback metric |
| A focused profile/catalog test group | edit-test loop metric |
| Real Podman activation | establishes how much latency Go cannot remove |

The goal should be less “Go wins every benchmark” and more:

> **Most correctness changes should be verifiable without paying an operating-system-process, Git, Podman, or VM lifecycle cost.**

That is the long-term development advantage.

## Bootstrap and distribution model

The bootstrap concern is real, but I think a hybrid architecture solves it cleanly.

The current root `bootstrap.sh` is already very close to the shell component I would retain. It is a small, sourceable facade: it locates the real checkout bootstrap, invokes it, and after successful installation sources the generated `shell-init.sh` so the current parent shell can acquire Shimmy’s PATH selection. fileciteturn14file0L2-L2

A Go subprocess cannot directly alter its parent shell’s environment. Therefore, retaining POSIX at this boundary is not architectural compromise; it is the correct interface.

The future flow should look roughly like this:

```text
             bootstrap.sh
                  |
                  | detect host / locate binary
                  v
          native shimmy executable
                  |
                  | bootstrap transaction
                  v
       installation + default profile
                  |
                  | generate
                  v
             shell-init.sh
                  ^
                  |
      bootstrap.sh sources it
      when bootstrap was sourced
```

In other words:

```sh
# conceptual, not proposed production code

shimmy_binary=...
"$shimmy_binary" bootstrap "$@" || return $?

# Only shell can alter the caller's environment.
. "$generated_shell_init"
```

The existing distinction between sourcing bootstrap and executing it already acknowledges precisely this parent-shell boundary. fileciteturn14file0L2-L2

### Separate acquisition from runtime prerequisites

I would also challenge the assumption that the source checkout must remain the end-user distribution artifact.

Today first installation requires a complete checkout plus `/bin/sh`, Git, and Podman, and the checkout must be clean, committed, attached to `main`, and match `refs/heads/main`. fileciteturn15file0L2-L2 That is an excellent contributor/development provenance contract, but it need not be the best eventual **product installation contract**.

A Go implementation creates an opportunity to separate two paths:

**Developer path**

```text
git clone
   |
Go toolchain
   |
go test / go build
   |
local bootstrap
```

**Release-user path**

```text
platform-specific Shimmy release bundle
   |
bootstrap.sh + native shimmy binary
   |
installed Shimmy
```

That would preserve the “no user language runtime” property while allowing contributors to have a conventional Go development environment.

Go can produce OS/architecture-specific binaries using `GOOS` and `GOARCH`. citeturn6search0turn6search4 This maps naturally onto the host matrix Shimmy already designs for: Linux and Darwin on `amd64` and `arm64`. fileciteturn19file0L2-L2

The initial release matrix therefore need only be:

```text
darwin/amd64
darwin/arm64
linux/amd64
linux/arm64
```

That is a manageable cost for the portability Shimmy currently supports.

### Do not bootstrap the Go control plane from Podman

I would **not** make the primary design:

```text
POSIX bootstrap
    -> Podman container containing Go
    -> build/extract shimmy
```

On Linux that can look attractive because Podman is already a requirement. On macOS it creates the wrong dependency direction: current bootstrap itself is responsible for validating or creating the installation-owned machine, establishing ownership evidence, starting it, and setting the initial projection transactionally. fileciteturn15file0L2-L2 Making the engine a prerequisite for acquiring the program responsible for safely managing the engine turns a clean bootstrapping boundary into a chicken-and-egg problem.

The Go executable should exist **before** Shimmy mutates Podman state.

### Release integrity becomes an explicit responsibility

Compiled artifacts do add one responsibility shell source largely sidesteps: you now have to publish trustworthy binaries for every supported tuple.

That is a real con, but it is manageable rather than disqualifying. GitHub supports artifact attestations that bind build provenance to information including repository, workflow, commit SHA, and triggering event. citeturn6search7 GitHub's immutable releases also generate release attestations covering the release tag, commit SHA, and release assets. citeturn6search3

There is a bootstrap paradox here too: strong local attestation verification usually requires a verification utility, and GitHub's documented command-line verification path uses the GitHub CLI. citeturn6search23 Therefore I would not claim that supply-chain attestation magically preserves Shimmy's “nothing else installed” property. Instead:

- use reproducible, pinned CI builds;
- publish hashes and attestations;
- enable immutable releases;
- sign/code-sign where appropriate;
- make provenance verifiable for environments that have the tooling;
- do not introduce `gh`, `cosign`, or another verifier as a mandatory first-run dependency unless the PRD deliberately accepts it.

The release pipeline is additional engineering, but it is also a substantial improvement in having an identifiable product artifact instead of treating the tip of a development checkout as the installed implementation.

### `go:embed` can simplify installed control assets

Go's standard `embed` package can compile files into the executable and expose them through an embedded filesystem. citeturn9search0 For Shimmy I would use that selectively for **control-plane-owned immutable assets** such as templates, built-in schemas, generated shell fragments, or canonical control skills.

I would not automatically embed the entire default catalog. Catalog generations have their own provenance and lifecycle in Shimmy; conflating them with the control executable could destroy a useful separation. The current catalog is explicitly installation-owned, immutable by generation, and independently pinned by profiles. fileciteturn4file0L2-L2

## Architecture to rebuild, not port

The greatest risk in this project is not that a rewrite fails. It is that the rewrite succeeds technically while preserving every implementation-shaped assumption that accumulated because the original implementation was POSIX shell.

I would start with a PRD and classify existing behavior into three buckets:

| Category | Treatment |
|---|---|
| Product requirement | Preserve deliberately |
| Safety invariant | Preserve aggressively |
| Shell implementation artifact | Reconsider from zero |

For example:

**Preserve deliberately:** catalog immutability, profile-specific tool selections, dry-run capability, clear human/structured output, platform matrix, rootless Podman, active profile concepts where genuinely needed.

**Preserve aggressively:** fail-closed ownership checks, exact machine identity, preflight before destructive mutation, journals before irreversible operations, commit-last authoritative records, preserving ambiguous/external resources, exact collision handling, rollback reporting. Those are some of the strongest parts of the current design. fileciteturn5file0L2-L2 fileciteturn20file0L2-L2

**Reconsider from zero:** shell-assignment state files, copies of `commands/`, `lib/`, and `tests/` inside every profile, hand-built help rendering, exact-byte help equivalence, broad dependence on Unix utilities, control source revisions independently materialized per profile, and any internal API whose only reason for existence was shell sourcing.

### Cobra should be an adapter, not the application architecture

Cobra is a good fit for Shimmy's nested command surface. It provides nested commands, flags, help machinery, and CLI execution semantics rather than requiring Shimmy to maintain those itself. citeturn6search1

But I would make this rule non-negotiable:

> **No domain package imports Cobra.**

A command should look conceptually like:

```go
func newProfileActivateCmd(app *app.App) *cobra.Command {
    var dryRun bool

    cmd := &cobra.Command{
        Use:  "activate <name>",
        Args: cobra.ExactArgs(1),
        RunE: func(cmd *cobra.Command, args []string) error {
            result, err := app.ActivateProfile(
                cmd.Context(),
                app.ActivateProfileRequest{
                    Name:   args[0],
                    DryRun: dryRun,
                },
            )
            if err != nil {
                return err
            }

            return renderResult(cmd.OutOrStdout(), result)
        },
    }

    cmd.Flags().BoolVar(&dryRun, "dry-run", false, "show the plan without applying it")
    return cmd
}
```

The important part is not the syntax. It is the dependency direction:

```text
Cobra
  |
  v
CLI adapter
  |
  v
Application/use cases
  |
  v
Domain + transaction model
  |
  +--> filesystem adapter
  +--> Git adapter
  +--> Podman adapter
  +--> clock
  +--> terminal/input
```

This allows virtually every meaningful behavior to be tested without constructing a command tree.

For CLI tests, create a **fresh** root command with injected dependencies for each test:

```go
func NewRoot(deps Dependencies) *cobra.Command
```

Then use Cobra's `SetArgs`, `SetOut`, and `SetErr` seams instead of globals. Cobra explicitly documents those APIs and notes that overridden arguments are particularly useful for testing. citeturn7view0turn7view1turn7view2

I would avoid the common generated-Cobra style of package-global `rootCmd`, global flag variables, and `init()` registrations. That style is convenient for tiny CLIs but works against the deterministic, parallel, dependency-injected test architecture Shimmy needs.

### Suggested Go package structure

A reasonable initial structure would be:

```text
cmd/
  shimmy/
    main.go

internal/
  cli/
    root.go
    admin.go
    profile.go
    catalog.go
    shim.go
    aiskill.go

  app/
    bootstrap.go
    activate.go
    profile_create.go
    profile_sync.go
    catalog_publish.go
    uninstall.go
    ...

  domain/
    profile.go
    catalog.go
    engine.go
    shim.go
    transaction.go
    errors.go

  state/
    install.go
    profile.go
    catalog.go
    engine.go
    journal.go
    atomic.go
    lock.go

  podman/
    client.go
    machine.go
    service.go
    registry.go

  git/
    client.go

  platform/
    host.go
    paths.go

  runtime/
    image.go
    platform.go

  assets/
    assets.go
    shell/
    skills/

  testkit/
    fake_runner.go
    fixture.go
```

I would not create interfaces simply because Go allows them. Put abstractions at nondeterministic or expensive boundaries—Podman, Git, filesystem mutation, clock, prompts—not around every data type.

### Model subprocesses explicitly

Both Git and Podman should initially remain external dependencies rather than being reimplemented with Go libraries.

Create one carefully controlled command-running boundary such as:

```go
type Runner interface {
    Run(ctx context.Context, req Command) (Result, error)
}
```

A `Command` can explicitly carry:

```text
executable
argument vector
working directory
environment additions/removals
stdin
stdout/stderr policy
sensitive argument/output policy
```

Then application logic never calls `exec.Command` ad hoc.

That is particularly important to Shimmy because environment variables such as Podman connection and registry variables already form part of its authority/safety model, and current diagnostics deliberately identify masking variables without exposing their contents. fileciteturn4file0L2-L2

It also means a test can assert:

```text
Activation plan says:

1. inspect target engine
2. stage registry projection
3. stop only podman.service
4. issue validation request
5. commit active record
```

without running Podman.

### Consider changing machine-owned state to JSON

I would seriously consider replacing internal shell-assignment manifests with strict versioned JSON.

The current state formats were designed for a shell implementation and are intentionally rigid. fileciteturn7file0L2-L2 Once bootstrap no longer has to source or parse those records, their shell syntax ceases to provide much architectural value.

For machine-owned state, something like:

```json
{
  "schemaVersion": 1,
  "profile": "default",
  "engine": {
    "mode": "shared",
    "id": "shared"
  },
  "catalog": {
    "name": "default",
    "generation": "sha256-..."
  }
}
```

would map directly into typed Go structs and can be decoded strictly, validated semantically, staged into temporary files, `fsync`ed as necessary, and atomically renamed according to Shimmy's transactional rules.

I would **not** use YAML for authoritative machine state simply because it is friendlier to humans. Human editing is not currently Shimmy's state-authority model, and YAML would add parser complexity and another dependency. JSON is available in the Go standard library.

This does not mean public `--format manifest` output must disappear. If line-oriented output is valuable for automation, make it a **public API format** with its own renderer. The key is to stop making implementation storage format and public output format the same thing accidentally.

### Keep the tool shims in POSIX—for now

I would not rewrite every generated tool wrapper into Go as part of this transition.

Those wrappers ultimately launch `podman run`, whose process/container startup dominates a tiny shell wrapper's execution cost. The project still fundamentally exposes containerized CLI tools through those wrappers. fileciteturn4file0L2-L2 Rewriting them simultaneously expands scope while providing relatively little development-cycle payoff.

The clean boundary is:

```text
POSIX:
    first bootstrap
    shell initialization
    simple generated per-tool shims

Go:
    everything that manages Shimmy itself
```

Later, if measurements show shim latency or wrapper generation becoming a problem, a multicall Go runtime launcher can be considered separately.

## Risks and tradeoffs

Starting over is not free, and several cons deserve to be taken seriously rather than treated as migration chores.

| Dimension | Go redesign advantage | Cost or risk | My assessment |
|---|---|---|---|
| End-user runtime | No Go runtime needed with prebuilt artifacts | Need native release binaries | Strongly favorable |
| Developer dependencies | Conventional Go environment | Go + Cobra become contributor dependencies | Acceptable |
| Shell ubiquity | Tiny shell retained where needed | Cannot ship only textual source anymore | Manageable |
| Unix portability | Removes many utility-specific code paths | OS-specific code still exists | Favorable |
| CLI mechanics | Cobra owns parsing/help/completion primitives | Framework dependency and defaults | Favorable if isolated |
| Testing | In-process, cacheable, fuzzable logic | Live Podman tests remain slow | Strongly favorable |
| State safety | Typed models, explicit errors/transitions | Rewrite can lose mature edge cases | Favorable only with contract tests |
| Distribution | Versioned product artifact | Build/release/provenance pipeline required | Real new work |
| Installed footprint | One binary can replace many control files | Binary is larger than shell text | Operationally minor |
| Debugging | Structured errors and diagnostics | Shell source is easier to inspect/edit in place | Mixed |
| Per-profile revisions | Can centralize control plane | Changes an existing conceptual model | High-value redesign |
| Rewrite scope | Opportunity to remove accidental complexity | Temptation to reinvent everything at once | Must be tightly governed |

### The largest risk is semantic regression

The existing shell implementation contains hard-won behavior that a clean Go implementation could easily make prettier and less safe.

For example, current engine work distinguishes Shimmy-created machines from migrated/external/ambiguous machines and refuses to infer ownership merely from names. Destructive operations require exact ownership evidence; lifecycle intent is durably recorded before machine mutation; incomplete rollback preserves evidence instead of pretending success. fileciteturn20file0L2-L2 Those are excellent safety properties.

A Go rewrite should not turn that into:

```go
if machine.Name == expectedName {
    podman.Remove(machine.Name)
}
```

just because typed code looks cleaner.

The shell code should therefore be treated as a **behavioral oracle**, particularly around failure and rollback. The migration criterion should not be “all happy paths implemented”; it should be “the new state machine demonstrates the same or better safety invariants under injected failures.”

### A rewrite can become architecture astronautics

The opposite danger is over-design. Go makes it easy to invent repositories, managers, service layers, interfaces, mocks, DTOs, factories, and abstractions around things that are fundamentally five file operations and one Podman command.

I would keep the design centered on **use cases and state transitions**, not enterprise layering.

For example:

```text
ProfileActivation
    Load()
    Plan()
    Preflight()
    Apply()
    Commit()
    Compensate()
```

is useful because those are actual domain concepts already present in Shimmy. fileciteturn5file0L2-L2

By contrast:

```text
ProfileActivationManagerFactoryProvider
```

would be a warning sign.

### Cobra itself should not drive the rewrite

Cobra is mature and exposes nested commands, flags, help and testable command I/O/argument interfaces. citeturn6search1turn7view0turn7view1 But the architectural return comes from Go's application structure and testing model, not from Cobra specifically.

Were Cobra to disappear later, ideally only `internal/cli` changes.

That is the test of whether the rewrite has produced a durable control plane rather than a “Cobra application.”

### Binary distribution weakens one nice property of shell

Today, source and installed behavior are inspectable as text. A user can examine exactly what a shell script will execute.

A binary is less transparent at point of execution. That should be compensated through predictable structured output, excellent `--dry-run`, immutable source-to-artifact provenance, release metadata, and retaining generated tool wrappers in a readable form.

Shimmy already invests heavily in dry-run reporting and fail-closed state inspection; those qualities become even more valuable after compilation. fileciteturn20file0L2-L2

## Recommended decision and cutover

I would make the restart a **product-definition exercise followed by a greenfield control-plane implementation**, not an incremental translation of `.sh` files into `.go`.

### Write the PRD before writing the new command tree

The PRD should settle at least these questions:

| Product question | Why it must be decided now |
|---|---|
| What is Shimmy's one-sentence product promise? | Prevents the implementation from defining the product |
| What hosts are officially supported? | Defines binary/release matrix |
| How does a user acquire Shimmy? | Separates release model from developer checkout |
| Is Git an end-user dependency or only a contributor/update mechanism? | Determines sync architecture |
| Is Podman the permanent runtime contract? | Prevents premature runtime abstraction |
| What exactly is a profile? | Current concept carries both state and control implementation |
| Does every profile need an independent control-plane version? | Major architecture decision |
| What does “active profile” mean? | Defines global mutation authority |
| What does “shell-selected profile” mean? | Defines per-shell UX |
| Which state belongs installation-wide versus profile-wide? | Avoids future schema ambiguity |
| What is a catalog and who updates it? | Defines provenance/release model |
| What is a shim and what state does it own? | Keeps runtime/control separation clear |
| Which operations may access the network? | Important for predictable and secure behavior |
| Which mutations must be reversible? | Defines transaction model |
| Which irreversible mutations need journals? | Defines destructive safety model |
| What constitutes ownership proof? | Essential for Podman machines and user content |
| What are public machine-readable output contracts? | Stops accidental byte-level compatibility obligations |
| What is the latency budget for common control commands? | Makes performance an explicit requirement |
| What is the expected local edit-test feedback loop? | Makes testability an explicit product-development requirement |

The existing plans should feed that document, but they should not automatically become requirements. Some plans encode decisions made because of the current implementation.

That distinction matters enormously.

### Preserve invariants; discard incidental contracts

I would create an explicit rewrite ledger:

| Keep | Reconsider |
|---|---|
| Fail closed on unknown ownership | Per-profile copies of control source |
| Catalog generation immutability | Shell-assignment internal records |
| Exact destructive ownership evidence | Hand-written CLI parsing/help |
| Durable intent before irreversible mutation | Exact help bytes unless actually needed |
| Commit authoritative state last | Tests installed with every profile |
| Dry-run before dangerous operations | Utility-by-utility portability fallbacks |
| Preserve external/ambiguous machines | Source checkout as mandatory release installer |
| Explicit engine/profile authority | Control-plane revision tied to profile revision |
| Platform-native image selection | Shell globals as internal APIs |
| Strict malformed-state rejection | Sourceable control libraries |

The current project has already demonstrated willingness to do this kind of hard cut when the prior model became wrong for the unreleased product. fileciteturn7file0L2-L2 The Go redesign should use that freedom fully rather than carrying forward compatibility with an architecture that has never shipped.

### Build vertical slices instead of translating directories

A sensible sequence is:

| Slice | What proves it is complete |
|---|---|
| Product/domain baseline | PRD, state ownership map, failure model, package boundaries |
| CLI/read-only state | `help`, status, list, strict state readers, fixture tests |
| Catalog | validation, fingerprinting, generation publication/rollback |
| Shim management | selection, materialization plans, runtime preview |
| Profile model | create/clone/status and profile state |
| Activation | dry-run planner first, then transactional external application |
| Engine and registry lifecycle | exact ownership, projection, service/machine lifecycle |
| Bootstrap and startup | tiny POSIX facade calling Go, shell-init generation |
| Destructive lifecycle | delete/uninstall journals, failure injection, recovery |
| Native acceptance | Linux/Darwin and supported architectures, real Podman behavior |
| Hard cut | old shell control plane removed rather than indefinitely maintained |

The important thing about that sequence is that the hardest destructive functionality comes **after** the state and transaction model has already been exercised extensively.

During development, the shell implementation can remain a reference oracle rather than becoming a permanent compatibility layer. Because Shimmy has not shipped, there is little value in a long-lived strangler architecture where every operation exists twice.

### Centralize the control plane unless the PRD forbids it

My preferred installed layout would look more like:

```text
~/.config/shimmy/
  state/
    installation.json
    active-profile.json

  engines/
    shared/
      engine.json
      lifecycle.json
      projection.json
    profile-foo/
      ...

  catalogs/
    default/
      registry.json
      generations/
        sha256-.../

  profiles/
    default/
      profile.json
      registries.conf
      shell-init.sh
      bin/
        shimmy       # tiny selector wrapper or link
        jq
        rg
        ...

    team-one/
      profile.json
      registries.conf
      shell-init.sh
      bin/
        shimmy
        ...

  control/
    shimmy           # one installation-wide Go binary
```

The exact paths are not the point. The separation is:

```text
control implementation  !=  profile state  !=  catalog state  !=  runtime shims
```

A profile-local `bin/shimmy` can be an extremely small selector wrapper that calls the installation-wide binary with validated profile context. Active-only operations would still compare that context against authoritative installation state before mutating anything. This preserves the current useful distinction between shell selection and installation-wide active authority without duplicating the program implementing those rules.

If independent profile control-plane versions turn out to be a real requirement, I would still avoid copying entire control trees. Store immutable control binaries content-addressed once:

```text
control/
  sha256-aaa.../shimmy
  sha256-bbb.../shimmy

profiles/
  default -> control sha256-aaa...
  experimental -> control sha256-bbb...
```

But I would choose that complexity only if the PRD requires it, because supporting multiple writers against shared installation state creates a permanent compatibility obligation.

### Final judgment

The decision matrix, in my view, is decisive:

| Question | Assessment |
|---|---|
| Has Shimmy outgrown “small shell glue”? | **Yes** |
| Is shell still valuable at bootstrap/shell boundaries? | **Yes** |
| Does Go force end users to install Go? | **No, with prebuilt releases** citeturn6search0turn6search4 |
| Does Go remove Git/Podman latency? | **No** |
| Can it remove large amounts of shell/subprocess test overhead? | **Yes, structurally** |
| Does Cobra fit the existing hierarchical CLI? | **Yes** citeturn6search1 |
| Can Cobra command behavior be tested in process? | **Yes** citeturn7view0turn7view1turn7view2turn7view3 |
| Does Go improve parser/state-machine testing options? | **Yes; standard testing, caching, and fuzzing are directly relevant** citeturn8search7turn6search2 |
| Does the rewrite introduce release engineering? | **Yes** |
| Is that release engineering manageable for four existing target tuples? | **Yes**; Go supports OS/architecture-targeted builds and Shimmy already specifies those four host combinations. citeturn6search4 fileciteturn19file0L2-L2 |
| Is the absence of backward compatibility unusually valuable here? | **Yes**; Shimmy has already deliberately used unreleased hard cuts. fileciteturn7file0L2-L2 |
| Should current behavior simply be ported? | **No** |
| Should current safety invariants be preserved? | **Absolutely** |

The architectural decision I would record is:

> **Shimmy should retain POSIX shell only where shell semantics are intrinsically required—first-contact bootstrap, parent-shell initialization, and initially the lightweight tool wrappers. The Shimmy management/control plane should be reimplemented as a precompiled Go application with Cobra at the CLI boundary. The rewrite should begin from a product requirements document and a simplified installation/domain model, not from a source-to-source translation of the existing shell. Existing shell implementation and tests should serve as requirements evidence and behavioral oracles, with particular emphasis on preserving ownership, fail-closed validation, transaction ordering, immutable catalog provenance, destructive-operation journals, and rollback semantics.**

And I would add one more decision immediately beneath it:

> **Unless independent per-profile control-plane versions are established as an explicit product requirement, Shimmy should have one installation-wide control-plane binary and treat profiles as data.**

That second decision is where I suspect the largest long-term simplification lies.

The original choice of POSIX shell was not a mistake. It allowed Shimmy's concepts to evolve rapidly while there was no stable product definition. The repository now contains the information that was impossible to know at the beginning: concrete command semantics, ownership boundaries, failure behavior, profile/catalog relationships, engine lifecycle requirements, multi-architecture requirements, and destructive-safety rules.

**The shell implementation has therefore done its job extremely well: it discovered the product. I would not require it to also be the final implementation architecture of that product.**