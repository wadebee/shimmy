# Automatic Shell Completion Plan

**Status:** not started

## Objective

Add automatic, profile-local command completion for Shimmy without adding or
changing any accepted end-user command, option, manifest, or environment
surface. The existing default-profile bootstrap flow must use its
already-supported `--shell <name>` input (or inferred shell) to select a
shell-specific completion asset. Sourcing `bootstrap.sh` in a
completion-capable matching shell must initialize PATH and activate completion
in that shell as one bootstrap outcome; managed startup files must activate the
same behavior in future matching shell sessions by sourcing the generated
`shell-init.sh`.

Success means:

- `source ./bootstrap.sh --shell bash` activates completion immediately in
  Bash and persists it through the existing Bash startup-file ownership;
- `source ./bootstrap.sh --shell zsh` does the same for zsh;
- an executed bootstrap installs the selected completion asset and managed
  startup integration but, as today, cannot mutate its parent shell;
- completion discovers every documented top-level management command, nested
  action, option, fixed enum value, and authoritative catalog/manifest-backed
  shim selector without Podman, network access, or mutable operations;
- the root bootstrap option grammar, installed `shimmy` commands and options,
  help/usage forms, manifest output, and accepted command forms remain
  unchanged; descriptive bootstrap, startup, and profile-selection prose is
  updated where it currently says shell initialization is PATH-only;
- all shared orchestration, rendering, candidate resolution, installation, and
  validation logic remains POSIX shell; only the selected generated asset uses
  Bash- or zsh-specific completion APIs; and
- completion files participate in the existing staged profile install,
  refresh, rollback, relocation, and uninstall lifecycle.

Compatibility and migration policy:

- Shimmy is unreleased. Backward compatibility with profiles created before
  this feature is not required.
- The user will manually run `shimmy uninstall --global` before using the
  implementation and will bootstrap fresh afterward. Implementation must not
  run or automate that destructive operation.
- Do not add legacy profile migration, compatibility aliases, fallback
  forwarding, old-layout acceptance, or upgrade tests. Freshly generated
  profile fixtures are the acceptance baseline.

Explicit exclusions:

- Do not add `shimmy completion`, hidden launcher commands, new bootstrap
  flags, new environment selectors, or any other public command/API surface.
- Do not change existing command names, action names, flags, parsing, accepted
  help forms, usage grammar, manifest output, or profile binding. Descriptive
  help text that currently calls shell initialization PATH-only must change in
  the same chunk that activates completion.
- Do not complete the separate option surfaces of wrapped tools such as `jq`
  or `rg`; completion covers only the existing `shimmy` management grammar.
- Do not add fish support. Do not claim programmable completion for `sh`,
  `dash`, `ksh`, or `mksh`; those remain valid startup-shell selections and
  retain PATH initialization without completion.
- Do not guess free-form hosts, IP addresses, CIDRs, registry values, arbitrary
  skill names, or other values without an authoritative bounded source.
- Do not add a daemon, cache, external `bash-completion` dependency, zsh dump
  file, profile manifest field, or separately managed user completion file.
- Do not edit generated `.agents/skills/` adapters or implement the separate
  `plans/profile-name-activation.md` plan.

## Target layout and terminology

```text
lib/
  completion/
    CONTEXT.md
    candidates.sh           # internal executable POSIX candidate protocol
    render.sh               # sourceable POSIX asset selector/stager
    bash.sh                 # canonical Bash 3.2-compatible sourced asset
    zsh.sh                  # canonical zsh sourced asset
    active.sh               # generated only in a staged/installed profile
  install/
    startup.sh              # renders shell-init with guarded asset loading
    profile-assets.sh       # stages/validates the selected active asset
<installed-profile>/
  shell-init.sh
  lib/completion/
    candidates.sh
    render.sh
    bash.sh
    zsh.sh
    active.sh               # byte-copy of the recorded shell's canonical asset
```

- **Startup shell** means the existing immutable `startup_shell` recorded for
  a fresh default profile from `--shell` or shell inference. Its accepted
  values do not change.
- **Completion-capable shell** means `bash` or `zsh` in this implementation.
  Other accepted startup shells remain supported for PATH initialization.
- **Canonical shell asset** means `lib/completion/bash.sh` or
  `lib/completion/zsh.sh` in the source/control tree.
- **Active completion asset** means the selected canonical asset copied to
  `lib/completion/active.sh` in the staged profile. It is internal profile
  state, not a public command or user-managed file.
- **Candidate backend** means the internal installed
  `lib/completion/candidates.sh`. Shell assets pass cursor words to it and
  consume its machine-readable results; users do not invoke it through the
  `shimmy` launcher.
- **Completion activation** means registering the completion function for the
  command name `shimmy` in the current matching shell. It does not activate a
  Podman engine or select a different profile.
- **Completion retargeting** means updating an already registered Shimmy
  completion function to use the newly sourced profile's validated backend. A
  profile without an active asset may retarget existing Shimmy completion but
  does not create a registration or initialize a completion system in a fresh
  shell.

The resulting bootstrap behavior is:

| Recorded startup shell | Active asset | When `shell-init.sh` is sourced |
| --- | --- | --- |
| `bash` | Bash asset | Register only when `BASH_VERSION` is set. |
| `zsh` | zsh asset | Register only when `ZSH_VERSION` is set. |
| `sh`, `ksh`, or `mksh` | None | Initialize PATH; in Bash/zsh, only retarget a pre-existing Shimmy registration. |
| `dash` input | Normalized existing `sh` policy | Initialize PATH; in Bash/zsh, only retarget a pre-existing Shimmy registration. |
| upstream profile | None | Initialize PATH; in Bash/zsh, only retarget a pre-existing Shimmy registration. |

If the configured and running shells differ and the user accepts the existing
warning, bootstrap installs for the recorded startup shell but does not load
that shell's asset into the mismatched current interpreter. PATH initialization
still succeeds. The recorded shell's future startup session activates its
asset normally.

### Internal candidate contract

The adapters invoke the backend as:

```text
candidates.sh <zero-based-cursor-index> <word-0> ... <current-word>
```

`word-0` is the stable command name `shimmy`; the current word is included even
when empty. Bash passes `COMP_CWORD` unchanged. zsh converts its one-based
`CURRENT` value to zero-based before invoking the backend. The backend rejects
a non-numeric or out-of-range cursor, a missing/incorrect command word, or an
otherwise malformed request without evaluating any word.

Successful stdout is exactly one of these newline-delimited forms:

```text
candidates
<candidate-1>
<candidate-2>
```

```text
files
```

`candidates` records are non-empty validated grammar tokens with no whitespace,
control characters, or shell syntax. They are de-duplicated, sorted under
`LC_ALL=C`, and already filtered bytewise against the current-word prefix.
`files` delegates the current prefix to the shell's native filesystem
completion. Failure emits no usable records; adapters suppress diagnostics and
return no matches. Neither adapter evaluates backend output.

### Completion authority matrix

Completion follows the documented public grammar, not undocumented combinations
that a permissive parser may happen to accept and ignore.

| Context | Completion authority |
| --- | --- |
| Top level | `catalog`, `images`, `install`, `uninstall`, `netinfo`, `profile`, `skills`, `status`, `test`, `update`, plus the accepted help forms. |
| Group actions | `catalog {list,publish,rollback,rebind}`, `images verify`, `profile {status,activate,redirect}`, `profile redirect {list,remove}`, and `skills {install,update,uninstall}`. |
| Help forms | Top level, `catalog`, and `skills` accept `help|-h|--help`; `images`, `profile`, their nested actions, and non-group commands offer only the help tokens their current parsers document and accept. |
| Direct option form | `profile redirect` offers its documented `--prefix`, `--location`, and `--dry-run` upsert form; it does not invent an `upsert` action token. |
| Fixed values | `human|manifest`, `repo|profile`, and the fixed catalog names `default|upstream` in their documented contexts. |
| Catalog selectors | `install --shim` and explicit `images verify --shim` use safe current authority hints resolved from the invoking profile's named catalog and emit tool plus explicit `tool@version-label` forms. The command performs full validation before acting. |
| Installed selectors | `update --shim` emits installed tools; `test --shim` emits installed tools plus recorded explicit `tool@version-label` forms. |
| Paths | `catalog rebind --checkout` and documented skills `--export`/`--manifest` values request native filesystem completion. |
| Free-form values | Host/IP/CIDR, registry prefix/location, skill-name positionals, and other unbounded values receive no guessed candidates. |

The backend consumes completed words left-to-right, tracks a pending
option-value state, and suppresses already-used singleton or mutually exclusive
options. Documented repeatable options remain eligible. Encountering a
free-form value does not prevent later documented options from being offered.
Grammar candidates are not filtered by profile role, host OS, Podman/engine
state, or registry contents; those remain execution-time concerns. Only the
recorded catalog/manifest selector candidates vary by invoking profile.

## Recorded design decisions

1. Preserve the public command grammar exactly. Do not edit launcher dispatch
   or add a completion entry to launcher/command help. Completion is an
   internal shell-initialization capability selected by the existing bootstrap
   input. Descriptive help and documentation must stop saying initialization is
   PATH-only when that becomes false; this wording change is not a new command
   surface.
2. Support Bash and zsh initially. Bash uses the built-in programmable
   completion interfaces (`complete`, `compgen`, `COMP_WORDS`, `COMP_CWORD`,
   and `COMPREPLY`) with Bash 3.2 as the syntax ceiling. zsh uses its native
   completion system and `compdef`; if `compdef` is unavailable, the asset may
   initialize `compinit` with `-D -i` so it creates no `.zcompdump`, ignores
   insecure completion directories instead of prompting, and remains safe in
   startup. Do not reuse Bash completion through zsh's `bashcompinit` adapter.
3. Keep one POSIX candidate engine for both shell assets. Implement the exact
   zero-based argv request and newline response contract above. It never
   evaluates user words, parses them as shell code, or treats them as
   filesystem paths. Prefix filtering, stable sorting, and de-duplication live
   in the backend for candidate mode; only filesystem matching remains native
   to each adapter.
4. Keep the complete documented management grammar in one case-based backend,
   not duplicated across Bash and zsh and not scraped from help at runtime.
   Cover
   `catalog {list,publish,rollback,rebind}`, `images verify`,
   `profile {status,activate,redirect {list,remove}}`,
   `skills {install,update,uninstall}`, and every documented non-group command.
   Offer only documented options, accepted help forms, fixed values, and native
   filesystem completion recorded in the authority matrix. Parser-permissive
   but undocumented/ignored combinations remain unchanged but are not promoted
   into completion.
5. Respect documented parser state and cardinality. Only documented repeatable
   options remain eligible after use: install/images/update `--shim` and
   netinfo `--target`. Treat images/update/test `--all` versus `--shim`, profile
   redirect remove `--all` versus `--prefix`, and skills target versus export
   destinations as mutually exclusive completion states. Model redirect-remove
   `--detach` as requiring `--all`: either may be offered before a choice, a
   seen `--detach` suppresses `--prefix` and keeps `--all` eligible, and a seen
   `--prefix` suppresses both `--all` and `--detach`. Suppress other documented
   singletons after use even where a parser currently accepts last-value-wins
   repetition. Do not add or permanently test new command rejection rules.
   Omit unbounded free-form values from suggestions.
6. Resolve catalog-backed selectors for `install --shim` and explicit
   `images verify --shim` through a new catalog-owned completion resolver. It
   must strictly validate the invoking manifest binding, registry schema,
   current authority identity, canonical/non-symlink path chain, generation
   name/fingerprint metadata, and direct tools directory without hashing the
   payload, validating the retained prior generation, invoking Git, or creating
   temporary state. Candidate enumeration must additionally reject unsafe or
   symlinked direct tool/version entries and validate every emitted token. The
   actual management command remains the full integrity/authorization boundary
   and may reject a safe completion hint from a subsequently damaged catalog.
   Resolve update selections from installed tools and test selections from
   installed tool/version manifest records. Reuse
   `lib/common/common.sh`, `lib/catalog/catalog.sh`, and
   `lib/profile/profile.sh`; omit the internal `default` pseudo-label, validate
   emitted names/labels, sort in a stable bytewise locale, and de-duplicate.
7. The candidate backend is installed and invoked only by absolute
   profile-local path retained in non-exported shell state. It must not invoke
   the public launcher, `status`, Podman, tool runtimes, image verification,
   locks, temporary directories, or network services. Candidate failure is
   silent and produces no interactive matches.
8. Add a POSIX renderer/staging helper that selects the canonical asset from
   the resolved immutable `STARTUP_SHELL`. During profile staging, copy the
   selected asset to `lib/completion/active.sh` with mode `0644`; render no
   active asset for non-completion shells or upstream. Validate the selected
   staged result before profile commit. Because `lib/` is already replaced as
   one rollback-capable owned directory, do not add a root-level file,
   manifest field, or separate commit transaction.
9. Extend generated `shell-init.sh` while keeping its syntax POSIX-sourceable.
   After PATH selection and before cleaning its local bin-directory value, it
   derives the installed profile root from that already-rendered bin path. For
   a matching completion-capable interpreter only, it validates a readable
   regular non-symlink `active.sh` and executable regular non-symlink candidate
   backend, records the backend's absolute path in shell-specific non-exported
   completion state, and sources the active asset.
10. Completion loading must fail open. Missing, unsafe, unreadable, or failing
    assets and registration errors must leave PATH initialized, return success
    from ordinary, conditional, and `set -e` callers, and avoid leaking
    temporary renderer variables. Among Shimmy-owned state, a successfully
    registered completion function and its one required non-exported
    backend-path value intentionally remain. If zsh has no `compdef`, its
    standard `compinit -D -i` initialization also necessarily establishes zsh
    completion-system state; this is an explicit exception, creates no dump,
    and is skipped when user initialization already exists.
11. Sourcing root `bootstrap.sh` already sources installed `shell-init.sh`; do
    not add a second activation path. A matching sourced bootstrap therefore
    receives completion immediately. An executed bootstrap changes only its
    child process, while the installed managed startup block continues to
    source `shell-init.sh` in future sessions and gains completion through that
    same path.
12. `--no-startup` continues to mean no persistent startup-file mutation. When
    bootstrap itself is sourced in a matching completion-capable shell, the
    generated `shell-init.sh` still activates completion for that current
    session; executing `--no-startup` cannot affect the parent or a future
    shell.
13. Preserve profile relocation in disposable tests. `shell-init.sh` derives
    completion paths from its first rendered bin-directory value, which the
    existing fixture relocation helper already rewrites. Canonical assets must
    not embed the original stage/profile root. Sourcing a profile with a
    matching active asset replaces the retained backend path and re-registers
    completion for the stable `shimmy` command name. Sourcing a valid profile
    with no active asset must not initialize completion in a fresh shell, but
    it retargets an already present Shimmy-owned registration so completion
    never reads a stale sibling profile.
14. No old-profile transition is implemented. The new staged profile is
    internally complete only when a default Bash/zsh policy has its matching
    active asset. Extend `shimmy_profile_structure_validate` to require the
    internal completion directory; regular non-symlink renderer/adapters; and
    a regular non-symlink executable backend for every fresh profile. For a
    default Bash/zsh manifest, require `active.sh` mode `0644` and byte identity
    with the adjacent canonical asset selected by `startup_shell`; require it
    to be absent for other default policies and upstream. Tests build fresh
    profiles from the changed source. The user's manual pre-implementation
    uninstall is an operational prerequisite, not an implementation step or
    test action.
15. Update architecture, startup, onboarding, test, and user documentation to
    state that shell initialization now selects PATH and, for a matching
    supported default-profile shell, registers completion. Do not document an
    opt-in command because none exists.
16. Keep completion coverage in existing test groups so this feature does not
    invalidate the runner's retained 41-group timing assignment. Put the safe
    catalog resolver in `lib-catalog`, backend grammar/public-surface coverage
    in `commands-management`, direct adapter behavior in
    `commands-onboarding`, and profile ownership/startup lifecycle coverage in
    the existing profile, lifecycle, update, onboarding, and startup groups.

## Verified implementation inventory

This is the verified baseline, not permission to ignore newly discovered
dependencies during implementation.

- `bootstrap.sh` accepts `--shell` only for the default profile, identifies a
  sourced Bash or zsh caller, invokes installation in a subprocess, then
  sources the installed `shell-init.sh` in its caller. Executed bootstrap
  cannot modify its parent shell.
- `lib/install/request.sh` preserves the existing `--shell` input and rejects
  it outside checkout bootstrap for the default profile. No parser change is
  needed.
- `lib/install/startup.sh` resolves immutable startup policy before profile
  staging, renders `shell-init.sh`, and updates only recorded managed startup
  files. `lib/startup/startup.sh` owns supported shell normalization, exact
  startup targets, and the one managed marker block.
- `lib/install/profile-assets.sh` copies the complete `lib/` tree into the
  stage, and the existing transaction replaces `lib/` atomically with rollback.
  An active asset below staged `lib/completion/` therefore needs no new root
  ownership transaction.
- `lib/profile/profile.sh` validates installed profile structure.
  `lib/common/common.sh` and `lib/catalog/catalog.sh` expose authoritative
  local manifest/catalog tool and version readers without Podman.
- The existing `shimmy_catalog_profile_resolve` path is intentionally too
  expensive and stateful for TAB completion: it validates the complete current
  and retained catalog payloads, recomputes content fingerprints through
  temporary manifests, and consults Git for a live checkout. Catalog ownership
  therefore needs one completion-specific safe authority resolver; it is a
  hint source, not a replacement for full command-time validation.
- Current management parsing and documented grammar are implemented by
  `lib/install/launcher-template.sh`, `commands/{catalog,images,netinfo,profile,skills,status}.sh`,
  `lib/install/request.sh`, `lib/update/request.sh`,
  `lib/netinfo/request.sh`, and `tests/profile-smoke.sh`. These parsers and
  their accepted forms remain unchanged. Some generic parser branches accept
  combinations not advertised by action help; completion follows the
  documented public surface and does not promote those incidental forms.
- `tests/commands/onboarding.sh` owns sourced/executed bootstrap, Bash/zsh
  source compatibility, immediate shell initialization, PATH precedence,
  mismatch behavior, and relocated profiles. `tests/commands/startup.sh` owns
  inferred/explicit/manual policy, managed startup repair, shell mismatch,
  exact cleanup, and failure retry. `tests/commands/management.sh` owns the
  complete unchanged public command surface.
- `tests/support.sh` relocates profile fixtures by rewriting the first
  shell-init bin path; completion must derive its internal paths from that
  value rather than embed the original profile root.
- `CONTEXT.md`, `lib/CONTEXT.md`, `lib/install/CONTEXT.md`,
  `lib/profile/CONTEXT.md`, `lib/startup/CONTEXT.md`, `tests/CONTEXT.md`, and
  `tests/commands/CONTEXT.md` describe the affected ownership boundaries. The
  new `lib/completion/CONTEXT.md` must be linked from `lib/CONTEXT.md`.
- `README.md`, `BOOTSTRAP.md`, `CONTRIBUTING.md`, and
  `commands/README.md` currently describe shell initialization as PATH-only and
  must be updated without advertising a new command.
- The current Darwin acceptance host provides Bash 3.2.57 and zsh 5.9. The
  [GNU Bash programmable-completion manual](https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion.html)
  defines command-name completion through `complete` and completion-function
  state through `COMP_WORDS`, `COMP_CWORD`, and `COMPREPLY`. The
  [zsh completion-system manual](https://zsh.sourceforge.io/Doc/Release/Completion-System.html)
  requires `compinit` for its native completion system, documents `-D` as
  disabling dump creation, `-i` as silently ignoring insecure directories,
  and `compdef` as the command-to-function registration interface.
- The test runner's canonical registry and fixed two-/three-worker assignment
  currently contain 41 groups. Reusing existing ownership-aligned groups
  avoids an unrelated timing/scheduler rebaseline for this feature.
- `plans/profile-name-activation.md` is not started and may later define a
  `shimmy` shell function. Registration by stable command name and replacing
  the retained profile-local backend path whenever shell init is sourced are
  compatible with that target without implementing it now.

## Unresolved

None.

## Progress Checklist

- [ ] Chunk 1 — Add and prove a catalog-owned safe current-authority resolver
  suitable for per-keystroke completion.
- [ ] Chunk 2 — Implement and prove the internal candidate protocol, documented
  management grammar, parser state, and profile-local metadata selectors.
- [ ] Chunk 3 — Implement and directly prove the Bash 3.2 and native zsh
  adapters without activating them from shell initialization.
- [ ] Chunk 4 — Stage, validate, refresh, roll back, relocate, and uninstall the
  completion assets as one fresh-profile schema transition.
- [ ] Chunk 5 — Activate completion through `shell-init.sh` and bootstrap,
  update documentation, and complete end-to-end regression verification.

Active chunk: Chunk 1. Implementation has not been authorized.

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

## Chunk 1 — Safe catalog completion authority

### Goal

Add one catalog-owned resolver that maps a validated invoking-profile binding
to safe current catalog authority hints without performing the full
fingerprint/Git/prior-generation work that is unsuitable for each TAB request.
No completion backend, shell adapter, profile schema, shell initialization, or
public behavior is added in this chunk.

### Files

Primary change surface:

- `lib/catalog/{catalog.sh,CONTEXT.md}`;
- `tests/lib/{catalog.sh,CONTEXT.md}`; and
- this plan for progress and lessons.

### Implementation requirements

1. Add `shimmy_catalog_completion_state_reset` and
   `shimmy_catalog_completion_resolve <manifest> <config-root>`. On success the
   resolver sets exactly `SHIMMY_CATALOG_COMPLETION_NAME`,
   `SHIMMY_CATALOG_COMPLETION_SOURCE_TYPE`,
   `SHIMMY_CATALOG_COMPLETION_AUTHORITY_ROOT`, and
   `SHIMMY_CATALOG_COMPLETION_TOOLS_DIR`; generic authority outputs remain
   empty and `SHIMMY_CATALOG_HEALTH` remains `unknown`. Failure may use the
   existing catalog error/invalid-health convention but returns no completion
   state.
2. Validate the manifest's one safe catalog binding and matching profile
   identity, the exact catalog registry schema/name/source type, the absolute
   non-symlink registry path chain, and the current authority form before
   returning any path.
3. For a generation, validate the current generation name against the registry
   fingerprint, its exact canonical directory, and matching regular
   `generation.conf` metadata. Do not resolve, traverse, or validate the
   retained previous generation. For a checkout, require the registry's source
   path to be absolute, canonical, available, and non-symlink without invoking
   Git.
4. For either authority form, require a regular non-symlink `catalog.conf` with
   the exact accepted format/schema plus a regular non-symlink direct `tools/`
   directory under the expected authority. This helper resolves authority
   only; Chunk 2 owns validation of direct tool/version entries before emitting
   candidates.
5. Reset completion-specific state before every request and fail closed with no
   usable completion authority on malformed, missing, unsafe, symlinked, or
   inconsistent state. Reuse catalog-owned registry/metadata validators instead
   of duplicating their schemas.
6. Perform no payload fingerprinting, full payload/schema traversal, Git
   command, temporary file/directory work, lock, network access, cache, or
   mutation.
7. Add focused default-generation and upstream-checkout tests plus the
   lowest-cost malformed/path/symlink cases protecting this new read-only trust
   boundary. Prove forbidden expensive/mutable paths are not invoked.

### Implementation notes

- Keep the helper beside `shimmy_catalog_profile_resolve` and follow the
  catalog module's established error conventions. Existing internal validators
  may populate generic parsing state transiently; copy the accepted values into
  `SHIMMY_CATALOG_COMPLETION_*` outputs and clear generic full-resolution state
  before successful return so callers cannot mistake hints for fully validated
  catalog health.
- Reuse strict registry and generation metadata parsing. The deliberate seam is
  content integrity: completion validates safe authority identity/path, while
  the real command later repeats the full payload fingerprint and schema
  validation before acting.
- Validate only the current generation. Reading the retained rollback
  generation on every TAB adds latency without affecting current selector
  hints.
- Keep tests focused on the resolver contract. Do not add completion grammar or
  shell fixtures in this chunk.

### Verification checklist

- [ ] `lib/catalog/catalog.sh` passes `sh -n` and exposes the documented
  completion-specific resolver/state without changing existing full resolver
  behavior.
- [ ] Safe default-generation and upstream-checkout fixtures resolve the exact
  current authority/tools paths and never report full catalog health.
- [ ] Binding, registry, catalog/generation metadata, canonical path, direct
  tools directory, and symlink damage fail closed without returning stale
  state.
- [ ] Instrumented coverage proves no payload fingerprint, prior-generation
  traversal, Git, temporary state, lock, cache, network, or mutation path runs.
- [ ] Existing full catalog resolution and validation tests remain unchanged in
  behavior and continue to pass.
- [ ] `./tests/test.sh --group lib-catalog` passes.
- [ ] `./tests/context-tree.sh` and `git diff --check` pass; diff inspection
  confirms no completion files, public command/help changes, or profile/shell
  behavior.
- [ ] Human review accepts Chunk 1; implementation does not mark this item
  complete before explicit acceptance.

### Human review gate

Reviewers confirm that the new helper returns only safe current-authority hints,
does not weaken or impersonate full catalog validation, and is bounded enough
for per-keystroke use. Explicit acceptance authorizes only Chunk 2.

## Chunk 2 — Candidate protocol and management grammar

### Goal

Add one internal, installed-profile candidate backend that implements the
recorded argv/record protocol, the documented Shimmy management grammar, parser
state, fixed values, and local catalog/manifest selectors. It is copied by the
existing `lib/` staging behavior but is not registered with Bash/zsh or loaded
by `shell-init.sh` in this chunk.

### Files

Primary change surface:

- new `lib/completion/{CONTEXT.md,candidates.sh}`;
- `lib/CONTEXT.md`;
- `tests/commands/management.sh` and
  `tests/commands/CONTEXT.md`; and
- this plan for progress and lessons.

Newly discovered direct dependencies may be updated within this chunk, but it
must not add shell adapters, active-asset rendering, profile schema validation,
shell-init loading, documentation claims that completion is active, or any
public command/help entry.

### Implementation requirements

1. Implement the exact zero-based argv request and newline response contract in
   an executable POSIX `candidates.sh`. Validate request shape before resolving
   profile/catalog state, emit only the recorded modes/tokens, and fail without
   usable output.
2. Derive the installed profile root from the backend's own canonical path,
   validate that it is the invoking `default` or `upstream` profile, and source
   only the local common, profile, and catalog helpers required for read-only
   metadata resolution.
3. Encode the documented top-level, nested-action, option, value, help, and
   path-mode matrix in one backend. Track pending values, completed positionals,
   repeatable options, singletons, and mutual exclusions without adding parser
   behavior or invoking public commands.
4. Resolve install and explicit image selectors through the accepted
   `shimmy_catalog_completion_resolve` authority, then fail closed on any
   unsafe/symlinked direct tool, version, or required metadata entry before
   emitting safe tool and explicit `tool@version-label` tokens. Resolve update
   and test selectors from the validated installed manifest. Omit the internal
   `default` pseudo-label and emit stable explicit version labels only.
5. Validate dynamic tokens, de-duplicate them, set `LC_ALL=C` for bytewise
   sorting/prefix matching, and treat every input word as opaque data. Do not
   use `eval`, temporary state, Podman, the network, locks, public management
   commands, or mutable catalog/profile operations.
6. Extend existing management coverage with one authoritative completion
   grammar/protocol matrix and checksum-based non-mutation proof. Preserve
   current public command/help assertions rather than adding a second generic
   rejection suite.

### Implementation notes

- Prefer small alphabetically ordered POSIX helpers for request validation,
  candidate collection, prefix filtering, metadata selection, and context
  dispatch; keep the main left-to-right state machine readable as a direct
  mapping to the authority matrix.
- Treat the current word separately from completed words. Consume an option's
  required value before interpreting later tokens, and stop suggesting a
  singleton only after its value is complete.
- Return `files` as a semantic directive; do not enumerate the filesystem in
  the backend.
- Use the catalog helper only to resolve safe current authority. Validate the
  direct entries actually used for candidate hints, and let the real
  install/images command repeat full catalog validation before acting.
- Snapshot representative public grammar in tests rather than scraping help or
  executing management commands on each TAB. That keeps completion local and
  prevents incidental parser permissiveness from becoming a documented API.

### Verification checklist

- [ ] `lib/completion/candidates.sh` is mode `0755`, passes `sh -n`, and its
  context is linked from `lib/CONTEXT.md`.
- [ ] Valid and malformed direct protocol requests prove the zero-based cursor,
  required `shimmy` command word, empty current word, exact first record, safe
  token validation, stable sort, de-duplication, and prefix filtering contract.
- [ ] Representative top-level, nested action, documented option, help, fixed
  value, path-mode, repeatable, singleton, and mutually exclusive contexts
  match the frozen authority matrix.
- [ ] Catalog-backed install/images selectors and manifest-backed update/test
  selectors come from the invoking profile, omit pseudo-labels, and change when
  safe current local metadata changes without changing the backend.
- [ ] Unsafe/symlinked direct catalog tool/version/metadata entries fail closed;
  a valid safe hint is still revalidated by the real command before any action.
- [ ] Candidate requests leave manifest, catalog registry, registry policy,
  shell-init, and source asset checksums unchanged and do not invoke full
  payload fingerprint/Git, Podman, network, lock, cache, temporary, or mutable
  management paths.
- [ ] `./tests/test.sh --group commands-management --group lib-catalog --group commands-catalog --group commands-install --group commands-test --jobs 3`
  passes.
- [ ] `./tests/context-tree.sh` and `git diff --check` pass; diff inspection
  confirms no public command, flag, help entry, manifest field, or shell
  activation change.
- [ ] Human review accepts Chunk 2; implementation does not mark this item
  complete before explicit acceptance.

### Human review gate

Reviewers confirm that the protocol is unambiguous, the candidate set matches
the documented public grammar rather than incidental parser behavior, dynamic
selectors use only safe invoking-profile authority/manifest hints, and the new
installed backend is still dormant. Explicit acceptance authorizes only
Chunk 3.

## Chunk 3 — Bash and zsh adapters

### Goal

Add thin Bash 3.2 and native zsh adapters that translate each shell's cursor
state into the shared protocol, translate backend records into native matches,
and register the stable `shimmy` command name when directly sourced. The
profile staging and `shell-init.sh` rendering remain unchanged, so automatic
activation is still dormant.

### Files

Primary change surface:

- new `lib/completion/{bash.sh,zsh.sh}`;
- `lib/completion/CONTEXT.md`;
- `tests/commands/onboarding.sh` and
  `tests/commands/CONTEXT.md`; and
- this plan for progress and lessons.

### Implementation requirements

1. Implement the Bash asset with Bash 3.2-compatible arrays and builtins only.
   Convert `COMP_WORDS`/`COMP_CWORD` to the recorded request, populate
   `COMPREPLY` from validated candidate records, and use native filesystem
   completion for `files`.
2. Implement the native zsh asset with its one-based `words`/`CURRENT` state,
   `compadd` for candidate records, and native file completion for `files`.
   Use an existing `compdef` when present; otherwise initialize
   `autoload -Uz compinit` followed by `compinit -D -i` before registering the
   stable command name.
3. Keep grammar, metadata lookup, prefix filtering, and option state out of both
   adapters. Invoke the absolute retained backend exactly once per completion
   request, pass user words as separately quoted arguments, suppress backend
   diagnostics, and never evaluate output.
4. Make direct adapter sourcing idempotent and fail open. Validate the proposed
   backend before replacing retained Shimmy state, register only after function
   definition succeeds, clean partial Shimmy-owned state on failure, and allow
   later sourcing for a sibling profile to replace the backend path.
5. Add direct-source adapter tests against installed disposable profile assets.
   Cover a zsh session with pre-existing `compdef` and one without it, and
   compare normalized Bash/zsh matches for the same backend requests.

### Implementation notes

- Keep the shell functions as translators: normalize cursor data, call the
  backend, inspect the first record, and hand matches to `COMPREPLY` or
  `compadd`. Any context-specific branch in an adapter is a design regression.
- Avoid Bash features newer than 3.2 such as associative arrays, `mapfile`, or
  relying on `compopt`. Parse newline records without unquoted expansion.
- In zsh, localize completion parameters used by the adapter and preserve an
  existing completion setup by checking for `compdef` before calling
  `compinit`.
- Stage a proposed backend path separately from the retained path so a failed
  source/registration attempt cannot redirect an already working completion to
  a damaged profile.

### Verification checklist

- [ ] `bash.sh` and `zsh.sh` are regular non-executable mode-`0644` assets;
  `/bin/bash -n` and `/bin/zsh -n` pass.
- [ ] Direct sourcing registers `shimmy` idempotently in Bash 3.2 and zsh 5.9,
  and direct test calls return the backend's representative candidate sets and
  native file mode.
- [ ] Bash and zsh return equivalent candidate sets for top-level, nested,
  option, fixed-value, prefix, repeatable, mutually exclusive, catalog, and
  manifest contexts.
- [ ] zsh reuses existing `compdef` without reinitializing user completion; the
  fallback `compinit -D -i` path creates or modifies no `.zcompdump`.
- [ ] Missing, non-executable, malformed, and failing backends plus registration
  failure produce no matches, return control, clean temporary Shimmy state, and
  do not replace a previously working retained backend.
- [ ] `./tests/test.sh --group commands-onboarding --group commands-management --jobs 3`
  passes.
- [ ] `./tests/context-tree.sh` and `git diff --check` pass; diff inspection
  confirms `shell-init.sh` rendering, profile validation, bootstrap behavior,
  and user documentation are still unchanged.
- [ ] Human review accepts Chunk 3; implementation does not mark this item
  complete before explicit acceptance.

### Human review gate

Reviewers confirm that Bash/zsh are thin equivalent adapters over one POSIX
authority, Bash 3.2 is the syntax ceiling, zsh initialization is bounded and
dump-free, and adapter failure cannot corrupt a prior Shimmy registration.
Explicit acceptance authorizes only Chunk 4.

## Chunk 4 — Atomic profile completion ownership

### Goal

Make every freshly generated profile internally complete for the new
completion schema: stage all canonical assets, select the default profile's
active Bash/zsh asset from immutable startup policy, validate the installed
shape, and preserve it through refresh, rollback, relocation, and uninstall.
Do not load completion from `shell-init.sh` yet.

### Files

Primary change surface:

- new `lib/completion/render.sh`;
- `lib/completion/CONTEXT.md` and `lib/CONTEXT.md`;
- `lib/install/{install.sh,profile-assets.sh,CONTEXT.md}`;
- `lib/profile/{profile.sh,CONTEXT.md}`;
- `tests/commands/{onboarding,startup,profiles,lifecycle,update}.sh` and the
  nearest retained test contexts;
- `tests/support.sh` only if the existing relocation rewrite is proven
  insufficient; and
- this plan for progress and lessons.

### Implementation requirements

1. Source the POSIX completion renderer in install orchestration and use the
   already-resolved immutable `STARTUP_SHELL` plus profile identity to select
   the active asset after the complete `lib/` tree is copied and before staged
   profile validation.
2. Copy `bash.sh` or `zsh.sh` byte-for-byte to staged
   `lib/completion/active.sh` with mode `0644` for matching fresh default
   profiles. Leave `active.sh` absent for default `sh`/`ksh`/`mksh` policies
   and upstream.
3. Extend canonical profile structure validation to require a regular
   non-symlink completion directory, canonical renderer/adapters, executable
   backend, and the exact active/absent state derived from the validated
   manifest. Compare active bytes with the adjacent selected canonical asset;
   do not introduce a manifest field or compatibility exception.
4. Preserve the existing whole-`lib/` stage/commit/rollback transaction.
   Exercise additive install, management refresh, failed commit restoration,
   fixture relocation, and uninstall without adding a separate completion
   ownership transaction.
5. Update retained contexts to describe the new internal ownership and
   validation boundary while still accurately stating that generated
   `shell-init.sh` is PATH-only at this review gate.
6. Add the lowest-cost durable structure/symlink-safety assertions to existing
   profile/lifecycle scenarios. Do not add an old-profile upgrade fixture or a
   generic absence suite.

### Implementation notes

- Keep `render.sh` sourceable and policy-focused: resolve one source path,
  validate regular/non-symlink shape, copy, compare, set mode, or intentionally
  leave no active file.
- Let the manifest drive installed validation. Do not rely on ambient
  `STARTUP_SHELL` once a profile is staged or installed.
- Treat this as the atomic schema transition. Chunks 2 and 3 may leave dormant
  extra files in `lib/`, but this chunk is the first point at which their exact
  presence and active selection become mandatory for every fresh profile.
- Reuse the existing relocation seam. Because canonical assets are
  path-independent, only the rendered bin path should require rewriting.

### Verification checklist

- [ ] `render.sh` is mode `0644` and passes `sh -n`; all canonical completion
  assets have their required modes.
- [ ] Fresh default Bash and zsh stages contain a mode-`0644`, byte-identical
  `active.sh`; default non-completion-shell and upstream stages contain no
  active asset.
- [ ] The canonical validator accepts each correct fresh shape and rejects one
  authoritative unsafe/damaged/mismatched shape per durable structure boundary
  without duplicating generic rejection coverage.
- [ ] Additive install and management refresh reproduce the selected active
  asset; injected stage/commit failure restores prior `lib/` and shell-init
  state; uninstall removes completion state only through existing profile-root
  ownership.
- [ ] Relocated profile fixtures retain valid path-independent completion
  assets without embedding their original stage/profile root.
- [ ] `./tests/test.sh --group commands-onboarding --group commands-startup --group commands-profiles --jobs 3`
  passes.
- [ ] `./tests/test.sh --group commands-lifecycle --group commands-update --group commands-install --jobs 3`
  passes.
- [ ] `./tests/context-tree.sh` and `git diff --check` pass; final inspection
  confirms no separate transaction, manifest field, public command, or
  shell-init activation.
- [ ] The complete default `./tests/test.sh` suite passes with normal bounded
  parallel execution because profile validation and installation lifecycle are
  broad shared boundaries. Rerun only failing groups serially for diagnosis.
- [ ] Human review accepts Chunk 4; implementation does not mark this item
  complete before explicit acceptance.

### Human review gate

Reviewers confirm that the fresh-profile schema is internally complete and
atomically owned, active selection is derived only from manifest startup
policy, unsafe/mismatched assets fail profile validation, and user-visible shell
behavior remains PATH-only until the final chunk. Explicit acceptance
authorizes only Chunk 5.

## Chunk 5 — Automatic activation, documentation, and final regression

### Goal

Load the validated active asset from generated `shell-init.sh` after PATH
selection, complete sourced/executed bootstrap and managed-startup behavior,
prove fail-open and profile-switching semantics, update all user and contributor
guidance, and finish full regression review.

### Files

Primary change surface:

- `lib/install/startup.sh`;
- `bootstrap.sh` descriptive help text only;
- `CONTEXT.md`, `lib/install/CONTEXT.md`,
  `lib/startup/CONTEXT.md`, `tests/CONTEXT.md`, and
  `tests/commands/CONTEXT.md`;
- `tests/commands/{onboarding,startup,management}.sh`;
- `tests/support.sh` only if a relocation defect was demonstrated in Chunk 4;
- `README.md`, `BOOTSTRAP.md`, `CONTRIBUTING.md`,
  `commands/README.md`, and `docs/testing.md` when affected; and
- this plan for progress and lessons.

### Implementation requirements

1. Render POSIX-sourceable `shell-init.sh` so existing PATH selection and
   Podman PATH fallback complete first. Derive the profile root only from the
   relocatable rendered bin path, then guard the expected interpreter,
   completion directory, active regular non-symlink asset, and executable
   regular non-symlink backend before sourcing.
2. Pass a proposed absolute backend path to the active adapter and commit its
   retained non-exported path only after successful registration. Re-sourcing
   the same profile is idempotent; sourcing a sibling with a matching active
   asset replaces the retained path and re-registers the stable `shimmy`
   command. A valid profile with no active asset retargets an existing
   Shimmy-owned registration but never creates one.
3. Make every missing, unsafe, unreadable, malformed, backend, source, and
   registration failure recoverable after PATH initialization under ordinary
   sourcing, sourcing used as a condition, and `set -e` Bash/zsh callers.
   Clean temporary Shimmy variables and partial Shimmy-owned function/
   registration state; finish with success. If PATH has switched to a profile
   whose backend cannot be validated, disable Shimmy-owned completion rather
   than leave it querying the prior profile.
4. Preserve current bootstrap orchestration. A sourced matching default
   bootstrap gains immediate completion through its one existing
   `shell-init.sh` source; an executed bootstrap affects only its process and
   future managed startup sessions. `--no-startup` remains current-session-only
   when sourced, mismatch consent never loads the wrong shell asset, and
   upstream/non-completion policies do not create completion in a fresh shell.
5. Extend existing onboarding/startup tests for immediate and future sessions,
   Bash/zsh parity, mismatch, `--no-startup`, relocation, sibling profile
   switching, no `.zcompdump`, fail-open behavior, variable hygiene, and the
   read-only/no-Podman boundary.
6. Preserve exact public command/action/option/help-form and manifest
   inventories. Update only descriptive help/documentation that must now say
   matching default Bash/zsh initialization also registers Shimmy management
   completion; do not advertise an opt-in command.
7. Inspect the complete diff and modes, reconcile every checklist item, update
   lessons, and stop at the final human review gate. Do not run the user's
   manual global uninstall.

### Implementation notes

- Generate the completion block as one guarded conditional whose branches end
  successfully; test the rendered artifact, not only the renderer source.
- Keep the candidate backend path in one shell-specific, non-exported retained
  variable. Use distinct temporary names and remove them on every branch.
- Source the active adapter in a conditional context and explicitly normalize
  the final status so caller `errexit` behavior cannot turn optional completion
  failure into shell-startup failure.
- Test profile switching with relocated disposable sibling profiles to prove
  that neither canonical adapter embeds a stage path and the last sourced
  matching profile is authoritative.
- Update prose and behavior together in this chunk; at no review gate should
  the repository claim PATH-only behavior after automatic loading exists.

### Verification checklist

- [ ] The rendered `shell-init.sh` passes `sh -n`, `/bin/bash -n`, and
  `/bin/zsh -n`; generated-artifact inspection confirms quoting, cleanup,
  interpreter guards, and PATH-before-completion ordering.
- [ ] Sourced fresh Bash and zsh bootstrap activates completion immediately;
  fresh managed Bash/zsh sessions do the same; executed bootstrap retains
  child-only immediate behavior and future managed activation.
- [ ] Bash and zsh completion results agree for the supported grammar,
  catalog/installed selectors, prefix filtering, parser state, and file mode;
  zsh creates or changes no `.zcompdump`.
- [ ] `--no-startup`, shell mismatch, unsupported completion shells, upstream,
  profile switching, and relocated profile behavior match the recorded
  decisions.
- [ ] Completion source/registration failures are recoverable under ordinary,
  conditional, and `set -e` Bash/zsh callers; PATH and Podman fallback remain
  correct, temporary Shimmy variables do not leak, and a failed profile switch
  cannot leave completion querying a stale sibling backend.
- [ ] Candidate requests do not invoke Podman/network/mutable operations and do
  not change profile manifest, registry policy, catalog registry, shell-init,
  or completion asset checksums.
- [ ] The installed `shimmy` top-level/nested documented command inventory,
  options, accepted help forms, manifest output, and existing rejection
  contracts are unchanged and expose no completion command.
- [ ] `./tests/test.sh --group commands-onboarding --group commands-startup --group commands-management --jobs 3`
  passes.
- [ ] `./tests/test.sh --group commands-profiles --group commands-lifecycle --group commands-update --jobs 3`
  passes.
- [ ] `./tests/test.sh --group runner --group lib-catalog --group commands-catalog --group commands-install --group commands-test --jobs 3`
  passes.
- [ ] `./tests/context-tree.sh` and `git diff --check` pass; final inspection
  confirms correct modes and no public command/flag/manifest additions.
- [ ] The complete default `./tests/test.sh` suite passes with normal bounded
  parallel execution. Rerun only failing groups serially for diagnosis.
- [ ] Documentation consistently describes automatic matching-shell
  completion, fresh-install-only compatibility, `--no-startup`, upstream and
  non-completion-shell behavior, and the unchanged public command grammar.
- [ ] Human review accepts Chunk 5; implementation does not mark this item
  complete before explicit acceptance.

### Human review gate

Reviewers confirm that a fresh default bootstrap automatically activates
equivalent Bash/zsh management completion through the existing `--shell`
policy, POSIX code remains the shared authority, internal assets fail open and
remain profile-local/read-only, and the launcher/bootstrap command and option
surface has not changed. Review also confirms that no compatibility or
migration work was added and that the user's manual uninstall remains outside
implementation. Explicit acceptance completes the plan.

## Risk register

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Completion grammar drifts from public parsers/help. | TAB advertises stale or incidental forms even though Bash/zsh agree. | Freeze the documented authority matrix in `commands-management`, do not scrape help at runtime, and update parser/help/completion coverage together in future command changes. |
| Shell-specific grammar diverges. | Bash and zsh suggest different or invalid inputs. | Keep grammar and metadata in one POSIX backend; adapters only translate cursor state and native file results. |
| Automatic loading breaks shell startup under `set -e`. | A completion defect can prevent login or PATH initialization. | Initialize PATH first, guard interpreter/asset shapes, make sourcing/registration conditional and fail-open, and test ordinary, conditional, and `set -e` callers. |
| zsh fallback initialization changes completion-system state or prompts. | Automatic bootstrap may alter widgets/functions when the user has not initialized zsh completion. | Reuse existing `compdef`; otherwise explicitly permit `compinit -D -i`, which disables dump creation and silently ignores insecure directories; assert no `.zcompdump` creation/change. |
| Internal metadata becomes shell injection. | Completion could execute typed or catalog-controlled text. | Never eval candidate output, validate emitted tokens, use shell-native arrays/match APIs, and pass user words only as quoted positional arguments to the backend. |
| Completion invokes expensive or mutable paths. | TAB becomes slow, noisy, networked, or state-changing. | Read validated manifests and bounded catalog hints only; prohibit the full fingerprint/Git resolver per request, block Podman/network/mutating commands in tests, and suppress backend errors in adapters. |
| Lightweight catalog hints observe damaged content that full validation would reject. | TAB may offer a safe token that the real command refuses. | Validate binding, registry/current-authority identity, paths, direct entries, and emitted tokens in the hint resolver; retain full catalog validation as the command-time authority. |
| Failed profile switching leaves stale completion authority. | TAB silently queries a damaged or prior sibling profile after PATH changed. | Validate a proposed backend separately, commit retained state last, and disable Shimmy-owned completion on switch failure rather than retain stale authority. |
| Relocated fixtures retain an original path. | Tests pass only in the source install and cloned profiles query the wrong authority. | Derive profile/backend from the relocatable shell-init bin path and retain no rendered absolute path in canonical shell assets. |
| `--shell` differs from the running interpreter. | The wrong syntax is sourced into the current shell. | Retain mismatch confirmation, guard on interpreter identity, skip completion in the mismatched caller, and let the recorded startup shell load it later. |
| Active asset is missing or damaged. | Completion disappears or shell startup fails. | Validate staged assets, guard installed shapes, fail open after PATH initialization, and protect symlink/unreadable/malformed cases as a durable safety boundary. |
| Public command surface accidentally grows or descriptive help remains contradictory. | An internal protocol becomes a compatibility burden, or help falsely claims PATH-only behavior. | Keep completion below `lib/`, do not edit dispatch/usage grammar, assert the exact public inventory, and update descriptive help in the activation chunk. |
| Chunk boundaries expose half-active behavior. | Dormant code may be mistaken for an accepted user feature. | Chunk 1 adds only authority hints, Chunks 2–3 add dormant backend/adapters, Chunk 4 owns the complete internal schema without loading it, and only Chunk 5 changes shell behavior and docs. |
| Old profiles fail after the internal layout change. | Existing local installs are rejected once the fresh-profile schema becomes mandatory. | Compatibility is explicitly excluded; the user performs manual global uninstall before using the changed implementation, and acceptance starts from freshly generated profiles. |

## Lessons learned

### Initial

- POSIX defines no programmable-completion interface; portable architecture
  requires a POSIX grammar/backend with shell-specific adapters.
- The iteratively expanded scope no longer fits one reviewable chunk. The
  catalog hint boundary, dormant backend, dormant adapters, atomic profile
  schema, and user-visible activation are independent coherent review seams.
- Completion must follow documented public grammar, not every combination a
  generic parser happens to accept. Otherwise completion would accidentally
  promote ignored or undocumented forms into supported API.
- The full catalog resolver is inappropriate for each TAB because it hashes
  complete current/retained payloads through temporary manifests and consults
  Git for live checkouts. Completion needs a catalog-owned safe hint resolver;
  the real command remains the integrity and authorization boundary.
- Bash and zsh expose different cursor indexing. Normalizing an argv request to
  zero-based indexing, including `shimmy` as word zero and the empty current
  word, removes an implementation ambiguity before adapter work begins.
- The existing `--shell` value is recorded immutably before profile staging,
  so it is already the correct renderer authority and requires no new option.
- Root bootstrap already sources installed `shell-init.sh` when sourced, while
  managed startup files source the same asset later. Loading completion there
  produces immediate and persistent behavior through one path.
- `shell-init.sh` can remain POSIX syntax while conditionally sourcing a
  matching Bash/zsh asset. It is no longer semantically PATH-only for matching
  default-profile shells, so every retained description must change together.
- The complete `lib/` tree is already staged and atomically replaced. Keeping
  `active.sh` under `lib/completion/` avoids a new root-level ownership and
  rollback transaction.
- Fixture relocation already rewrites the rendered profile bin path. Deriving
  completion paths from that value avoids embedding stale source-profile paths.
- Bash provides native command-name programmable completion and exposes cursor
  words to a completion function. zsh's native system requires `compinit` and
  provides `compdef`; `compinit -D -i` avoids a dump file and interactive
  insecure-directory prompts when automatic initialization is necessary.
- A zsh fallback `compinit` call necessarily retains standard zsh completion
  state. The plan can promise only that Shimmy-owned temporary state is cleaned
  and that existing `compdef` initialization is not repeated.
- Existing ownership-aligned test groups can cover this feature without adding
  a 42nd group and invalidating the retained static worker assignment. The
  profile-schema chunk still requires a complete suite because its validator
  is consumed by nearly every installed command.
- Generated sourceable shell artifacts require ordinary, conditional, and
  `set -e` caller tests; renderer-source syntax alone cannot prove fail-open
  behavior.
- `--no-startup` separates persistence from current sourced-shell
  initialization: it can still activate completion now without writing a
  startup file.
- The user explicitly accepts a fresh-install-only transition and will perform
  destructive uninstall manually; implementation must neither preserve old
  layouts nor perform that operation.

## Session bootstrap

Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`, this plan,
`lib/CONTEXT.md`, `lib/common/CONTEXT.md`, `lib/catalog/CONTEXT.md`,
`tests/CONTEXT.md`, and `tests/lib/CONTEXT.md`. Then inspect
`lib/common/common.sh`, `lib/catalog/catalog.sh`, `tests/lib/catalog.sh`, and
the accepted catalog registry/generation fixtures used by that test module.

The active scope is Chunk 1 only: add and verify the catalog-owned safe current
authority resolver and its completion-specific state. Do not add candidate or
shell-adapter files, grammar parsing, active-asset staging, profile validation,
shell-init loading, user documentation claims, public commands/flags/help
entries, compatibility, migration, other shells, wrapped-tool completion, or
named/custom profile work. Do not perform the user's manual uninstall. Execute
and record Chunk 1's verification checklist, update lessons learned, and stop
at its human review gate.
