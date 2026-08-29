# Shimmy Architecture — Notional Future State

> **Status:** Architectural direction, not an implementation contract.  
> **Purpose:** Describe Shimmy's intended long-term boundaries, responsibilities, user-facing control plane, and lifecycle model without coupling the design to a particular programming language, operating system, virtualization technology, or execution backend.

## 1. Architectural intent

Shimmy is a tool-execution harness designed for both humans and automated agents.

Its architecture separates four concerns that should remain independently evolvable:

1. **Profile** — the reproducible tool and policy context a user wants to work in.
2. **Engine** — the execution environment in which tool workloads run.
3. **Workload** — a running unit of execution owned by a profile.
4. **Catalog** — the controlled source of available tools, versions, metadata, and runtime definitions.

The central architectural rule is:

```text
Profile != Engine != Workload

Profile describes intent.
Engine provides execution capacity.
Workload is a runtime instance created within that capacity.
```

A profile may use a shared engine or an isolated engine. Multiple profiles may bind to the same shared engine, but the active profile determines the currently projected policy and workload context.

---

## 2. System context

```text
                   +----------------------+
                   |      Human User      |
                   +----------+-----------+
                              |
                              |
                   +----------v-----------+
                   |      AI / Agent      |
                   +----------+-----------+
                              |
                              v
                +---------------------------+
                |    Shimmy Control Plane   |
                |                           |
                | profiles   engines        |
                | catalogs   shims          |
                | policy     workloads      |
                | skills     lifecycle      |
                +-------------+-------------+
                              |
             +----------------+----------------+
             |                                 |
             v                                 v
 +-------------------------+       +-------------------------+
 | Shared Execution Engine |       | Isolated Engine(s)      |
 |                         |       |                         |
 | profile A workloads     |       | profile C workloads     |
 | profile B workloads     |       |                         |
 | shared runtime assets   |       | isolated runtime assets |
 +------------+------------+       +------------+------------+
              |                                 |
              +---------------+-----------------+
                              |
                              v
                  +-----------------------+
                  | External Tool Sources |
                  | and Artifact Sources  |
                  +-----------------------+
```

Shimmy owns the **control-plane contract**. The underlying engine implementation is replaceable.

An engine may eventually be:

- local,
- virtualized,
- remote,
- dedicated,
- shared,
- hardware-specialized,
- or implemented by a future execution backend.

The profile model should not need to change when the engine implementation changes.

---

## 3. Control plane and data plane

Shimmy should maintain a strong distinction between configuration/lifecycle operations and normal tool execution.

```text
+-------------------------------------------------------------------+
|                         CONTROL PLANE                             |
|                                                                   |
|  install  profiles  catalogs  shims  policies  engines  skills   |
|                    activation / lifecycle                         |
+-------------------------------+-----------------------------------+
                                |
                                | produces and reconciles
                                v
+-------------------------------------------------------------------+
|                           DATA PLANE                              |
|                                                                   |
|       tool invocation -> workload -> execution engine             |
|                                                                   |
|       jq ...              process/container/task                  |
|       rg ...              process/container/task                  |
|       future tool ...     process/container/task                  |
+-------------------------------------------------------------------+
```

The control plane is responsible for making the data plane deterministic, inspectable, and safe.

A normal tool invocation should not need to understand:

- engine topology,
- engine ownership,
- profile lifecycle state,
- policy projection,
- runtime initialization,
- or lifecycle journals.

---

## 4. Primary domain model

```text
                           Installation
                                |
        +-----------------------+-----------------------+
        |                       |                       |
        v                       v                       v
     Catalogs                Profiles                Engines
                                |                       ^
                                | engine binding        |
                                +-----------------------+
                                |
                     +----------+----------+
                     |                     |
                     v                     v
                   Shims              Profile Policy
                     |                     |
                     |                     |
                     +----------+----------+
                                |
                                v
                         Active Context
                                |
                                v
                            Workloads
                                |
                                v
                             Engine
```

### Installation

An installation is the top-level authority for Shimmy-managed state.

It owns or tracks:

- installation identity,
- catalogs,
- profiles,
- engines,
- active-profile authority,
- lifecycle journals,
- user integration,
- and machine-readable status.

### Profile

A profile represents a reproducible user or agent context.

A profile owns:

- profile identity,
- catalog selection or pin,
- tool/shim selections,
- tool-version policy,
- source-routing policy,
- user/agent integration metadata,
- engine binding,
- and, in the future, workload ownership metadata.

A profile does **not** inherently own an engine.

### Engine

An engine represents one execution environment.

An engine owns or describes:

- execution endpoint,
- lifecycle state,
- ownership classification,
- shared or isolated scope,
- projected active policy,
- engine-local runtime assets,
- and recovery/transaction state.

An engine must be addressable independently from a profile.

### Workload

A workload is a running execution unit created on behalf of a profile.

Future workload lifecycle management should make profile ownership explicit rather than inferring ownership from engine membership.

### Catalog

A catalog is the controlled source of tool definitions and supported versions.

Profiles consume catalog content; engines do not define tool intent.

### Shim

A shim is the stable user-facing invocation surface for a selected tool.

A shim resolves profile intent into execution through the active engine.

---

## 5. Scope and ownership model

The architecture uses explicit scopes rather than assuming all state belongs to the active profile.

| Scope | Representative state | Lifecycle owner |
|---|---|---|
| Installation | active-profile authority, catalogs, shared engine records, global integration | installation |
| Profile | manifest, tool selections, redirects/policy, engine binding, skill selections | profile |
| Engine | execution environment, engine-local images/artifacts, build cache, projected policy, lifecycle journal | engine |
| Workload | running processes/tasks, ephemeral runtime resources, profile workload identity | profile through workload lifecycle |
| External | pre-existing or ambiguously owned engines/resources | external owner |

Persistent workload data such as named volumes or equivalent storage requires an explicit future policy. It must not be classified as profile-owned or engine-owned merely because of where it happens to be stored.

---

## 6. Engine binding model

A profile selects an engine through an explicit binding.

```text
+-------------+        binding        +----------------+
|  Profile A  | --------------------> |                |
+-------------+                       |                |
                                      | Shared Engine  |
+-------------+        binding        |                |
|  Profile B  | --------------------> |                |
+-------------+                       +----------------+


+-------------+        binding        +----------------+
|  Profile C  | --------------------> | Isolated       |
+-------------+                       | Engine C       |
                                      +----------------+
```

### Shared mode

Shared mode optimizes for:

- low switching latency,
- reuse of engine-local artifacts,
- reuse of image/layer/build caches,
- and reduced infrastructure duplication.

The shared engine is infrastructure shared by profiles. It is **not** a declaration that workloads from different profiles have shared ownership.

### Isolated mode

Isolated mode provides a stronger execution boundary.

```text
Profile A                         Profile B
   |                                 |
   v                                 v
+-----------+                     +-----------+
| Engine A  |                     | Engine B  |
| isolated  |                     | isolated  |
+-----------+                     +-----------+
```

Isolation mode is expected to cost more in:

- startup latency,
- storage,
- lifecycle operations,
- and resource duplication.

The stronger boundary is intentional and should remain an explicit user choice.

### External or ambiguous engines

Unsupported or damaged state may still identify an engine that Shimmy cannot
prove it owns.

```text
Known to Shimmy != Owned by Shimmy
```

Profiles never route through that state. Destructive operations require
explicit, current ownership proof; names, bindings, or historical association
are never sufficient proof by themselves.

---

## 7. Active profile model

An installation has one authoritative active profile context.

```text
Installation
     |
     +---- active profile ----> Profile B
                                  |
                                  +---- engine binding ---> Shared Engine
                                  |
                                  +---- source policy
                                  |
                                  +---- shim/tool policy
                                  |
                                  +---- agent/user integration
                                  |
                                  +---- workload context
```

"Active" should mean that all control-plane projections agree.

A profile is not fully active if only the active-profile pointer changed while its engine, policy, shims, skills, or workload state remain inconsistent.

---

## 8. Future activation transaction

Activation is the primary orchestration boundary.

The notional future behavior for switching between two profiles on the same shared engine is:

```text
Before:

    Active Profile A
           |
           v
    +-------------------+
    |   Shared Engine   |
    |                   |
    | A-owned workloads |
    | shared artifacts  |
    +-------------------+


Activate Profile B
           |
           v

    1. Validate current and target state
    2. Identify Profile A workloads
    3. Stop/reconcile Profile A workloads
    4. Keep the shared engine running
    5. Project Profile B source-routing policy
    6. Reconcile Profile B shims/tool selections
    7. Reconcile user/agent integrations
    8. Validate the target execution context
    9. Commit Profile B as active


After:

    Active Profile B
           |
           v
    +-------------------+
    |   Shared Engine   |
    |                   |
    | shared artifacts  |
    | B workload context|
    +-------------------+
```

The key distinction is:

```text
Shared engine lifecycle     remains stable
Profile workload lifecycle  changes
Profile policy projection   changes
Active authority            changes last
```

### Cross-engine activation

A transition involving an isolated engine has a different cost and boundary:

```text
Profile A / Shared Engine
          |
          | activation
          v
Profile C / Isolated Engine

Preflight -> quiesce affected workloads -> stage target policy
          -> transition engine if required
          -> validate target
          -> commit active authority
```

If an engine transition would interrupt workloads, the user should see the impact before mutation and explicitly acknowledge destructive or interrupting behavior.

---

## 9. Transaction model

Control-plane mutations should follow a common transaction pattern.

```text
        +-----------+
        | Preflight |
        +-----+-----+
              |
              v
        +-----------+
        |   Stage   |
        +-----+-----+
              |
              v
        +-----------+
        | Validate  |
        +-----+-----+
              |
              v
        +-----------+
        |  Commit   |
        | authority |
        |   last    |
        +-----+-----+
              |
              v
          Complete
```

On failure before commit:

```text
failure
   |
   v
restore prior projections
restore prior engine state where reversible
restore prior integration state
retain durable recovery evidence when rollback is incomplete
leave prior active authority authoritative
```

For irreversible operations:

```text
Preflight all destructive work
        |
        v
Write durable journal
        |
        v
Perform ordered removals
        |
        +---- failure ---> retain journal + remaining state
        |
        v
Remove control-plane state last
```

---

## 10. Policy projection

Profiles own policy; engines consume projections of that policy.

```text
+-----------------------+
| Profile A             |
| authoritative policy  |
+-----------+-----------+
            |
            | activate
            v
+-----------------------+
| Engine projection     |
| source = Profile A    |
+-----------+-----------+
            |
            v
+-----------------------+
| Effective runtime     |
| policy                |
+-----------------------+
```

When Profile B activates:

```text
Profile A policy ----X

Profile B policy ----------> Engine projection ----------> Effective runtime
```

The architecture therefore keeps two concepts separate:

- **authoritative profile policy**, and
- **currently loaded engine policy**.

This separation enables validation, rollback, drift detection, and deterministic switching.

---

## 11. Workload ownership — forecasted architecture

Workload ownership is the major lifecycle layer that remains to be fully designed.

The target model should make ownership explicit:

```text
Profile A
   |
   +---- owns ----> Workload A1
   |
   +---- owns ----> Workload A2
   |
   +---- binds ----> Shared Engine


Profile B
   |
   +---- owns ----> Workload B1
   |
   +---- binds ----> Shared Engine
```

The engine answers:

> Where can this workload run?

The profile answers:

> Whose workload is this and under what policy?

This distinction is required so activation can safely stop or reconcile only the workloads belonging to the outgoing profile.

### Workload ownership requirements

The eventual mechanism should support:

- positive ownership identification,
- enumeration by profile,
- safe stop/reconcile operations,
- orphan detection,
- status reporting,
- recovery after interrupted activation,
- and protection of external/unmanaged workloads.

The mechanism may use runtime metadata, durable state, manifests, or a combination. The architecture does not prescribe the implementation.

---

## 12. Runtime asset boundaries

The intended shared-engine optimization is:

```text
                     Shared Engine
                          |
          +---------------+---------------+
          |               |               |
        images          layers         build cache
          |               |               |
          +---------------+---------------+
                          |
                 reusable by profiles
```

Workloads remain profile-scoped:

```text
Profile A                          Profile B
   |                                  |
 workloads                           workloads
   \                                  /
    \                                /
     +--------- Shared Engine -------+
```

This is the central performance/isolation trade:

- engine-local immutable or cache-like assets may be shared,
- live workload ownership remains profile-specific,
- stronger isolation is available through dedicated engines.

---

## 13. User-facing control plane

The user-facing architecture should expose intent-oriented operations and hide backend-specific mechanics whenever possible.

### 13.1 Current surfaces

The current product exposes five primary command groups:

```text
shimmy
 |
 +-- admin
 |    +-- status
 |    +-- engine status
 |    +-- network
 |    +-- uninstall
 |
 +-- profile
 |    +-- list
 |    +-- status
 |    +-- create
 |    +-- clone
 |    +-- activate
 |    +-- sync
 |    +-- repair-startup
 |    +-- delete
 |    +-- redirect
 |
 +-- catalog
 |    +-- status
 |    +-- tools
 |    +-- verify
 |    +-- publish
 |    +-- rollback
 |
 +-- shim
 |    +-- list
 |    +-- add
 |    +-- remove
 |    +-- set-version
 |    +-- sync
 |    +-- test
 |
 +-- ai-skill
      +-- list
      +-- repair
```

Additional current user-visible surfaces include:

```text
bootstrap / installation
        |
        +-- creates initial installation context
        +-- establishes default profile
        +-- establishes the initial engine
        +-- publishes user integration

profile shell/runtime selection
        |
        +-- selects the profile's tool invocation environment

machine-readable status
        |
        +-- stable output for automation and agents

dry-run
        |
        +-- previews mutations and destructive effects

tool shims
        |
        +-- stable data-plane invocation surface
```

### 13.2 Forecasted surfaces

The following are architectural capabilities, not committed command names.

```text
Future control plane
 |
 +-- activation orchestration
 |    +-- outgoing workload discovery
 |    +-- outgoing workload quiesce/stop
 |    +-- policy switch
 |    +-- shim/tool reconciliation
 |    +-- integration reconciliation
 |    +-- target validation
 |
 +-- workload context
 |    +-- list workloads by profile
 |    +-- show ownership
 |    +-- show active/inactive/orphan state
 |    +-- stop/reconcile owned workloads
 |    +-- preserve unmanaged workloads
 |
 +-- richer engine diagnostics
 |    +-- ownership state
 |    +-- policy projection state
 |    +-- health/recovery state
 |    +-- resource/cache visibility
 |
 +-- simplified activation UX
      +-- optional top-level activation entry point
      +-- exact command form remains a product decision
```

A possible future UX could look like:

```text
shimmy activate <profile>          # convenience orchestration surface

shimmy workload status            # conceptual; name TBD
shimmy workload list              # conceptual; name TBD
shimmy workload reconcile         # conceptual; name TBD
```

These names are illustrative only. The architecture commits to the **capabilities**, not the spelling of the CLI.

### 13.3 Surfaces that should remain internal

Backend implementation details should not become normal end-user control surfaces unless a future requirement demands them.

Examples:

```text
raw engine process/service management
raw provider-specific VM operations
internal ownership tokens
internal lifecycle journals
internal policy projection files
backend-specific connection manipulation
```

Users should normally express:

```text
"activate this profile"
"create this profile isolated"
"show me what will be affected"
"remove Shimmy-owned state"
```

rather than orchestrating backend primitives manually.

---

## 14. Control-plane evolution

The preferred direction is to keep high-level concepts stable while allowing implementations beneath them to evolve.

```text
Stable user concepts
--------------------
Profile
Catalog
Shim
Engine
Workload
Activation
Isolation
Status
Dry-run

          |
          v

Replaceable implementation details
----------------------------------
Programming language
Process model
Container/runtime technology
VM technology
Local vs remote engine
Registry/artifact implementation
Operating system integration
Persistence format
```

This allows future implementations to change without redefining the user's mental model.

---

## 15. Observability contract

Every major control-plane object should be inspectable.

```text
Installation status
    |
    +-- active profile
    +-- catalog state
    +-- integration state
    +-- lifecycle recovery state

Profile status
    |
    +-- engine binding
    +-- policy state
    +-- shim/tool state
    +-- active/inactive state
    +-- workload state

Engine status
    |
    +-- engine identity
    +-- ownership classification
    +-- health
    +-- active projected profile
    +-- projection freshness
    +-- workload summary
    +-- lifecycle/recovery state

Workload status
    |
    +-- owning profile
    +-- engine
    +-- running/stopped/orphaned state
    +-- managed/unmanaged classification
```

Human-readable output and stable machine-readable output should represent the same model.

---

## 16. Safety principles

### Ownership must be proven

```text
name match          != ownership
binding             != ownership
historical use      != ownership
current proof       == destructive authority
```

### Destructive scope must be visible before mutation

Users and agents should be able to inspect:

- what will stop,
- what will be deleted,
- which profile owns it,
- which engine contains it,
- what is preserved,
- and what cannot be rolled back.

### Unmanaged resources must fail safe

When ownership is absent or ambiguous:

```text
preserve
report
require explicit remediation
```

Do not silently adopt or destroy.

### Active authority commits last

The active profile record is an assertion that reconciliation succeeded, not a request that reconciliation should begin.

---

## 17. Agent-oriented design

Shimmy is intended to be safe for automated callers as well as humans.

The control plane should therefore favor:

- deterministic commands,
- noninteractive operation when inputs are explicit,
- stable machine-readable status,
- dry-run support,
- bounded side effects,
- clear ownership,
- explicit destructive acknowledgements,
- idempotent retry,
- and durable recovery state.

```text
Agent request
     |
     v
  dry-run
     |
     v
structured impact
     |
     v
 policy / approval
     |
     v
  mutation
     |
     v
structured result
```

An agent should not need to infer safety from free-form console output.

---

## 18. Example future-state topology

```text
+=======================================================================+
|                        SHIMMY INSTALLATION                            |
|                                                                       |
|  +------------------+       +------------------+                      |
|  | Catalog          |       | Active Authority |                      |
|  |                  |       | profile = dev    |                      |
|  +--------+---------+       +---------+--------+                      |
|           |                           |                               |
|           |                           v                               |
|  +--------v--------------------------------------------------------+  |
|  |                         PROFILES                               |  |
|  |                                                                 |  |
|  |  +-------------+  +-------------+  +-------------------------+ |  |
|  |  | dev         |  | test        |  | secure-build            | |  |
|  |  | shims       |  | shims       |  | shims                   | |  |
|  |  | policy      |  | policy      |  | policy                  | |  |
|  |  | workloads   |  | workloads   |  | workloads               | |  |
|  |  +------+------+  +------+------+  +------------+------------+ |  |
|  +---------|----------------|------------------------|--------------+  |
|            |                |                        |                 |
|       shared binding   shared binding          isolated binding      |
|            |                |                        |                 |
|            +--------+-------+                        |                 |
|                     |                                |                 |
|                     v                                v                 |
|          +----------------------+        +------------------------+   |
|          | Shared Engine        |        | Isolated Engine        |   |
|          |                      |        | secure-build           |   |
|          | shared images/cache  |        | private runtime assets |   |
|          | projected dev policy |        | isolated policy        |   |
|          +----------+-----------+        +-----------+------------+   |
|                     |                                |                 |
+=====================|================================|=================+
                      |                                |
                      v                                v
                Tool workloads                  Tool workloads
```

---

## 19. Future activation example

```text
User/Agent
    |
    | activate test
    v
Activation Coordinator
    |
    +--> validate current profile = dev
    |
    +--> resolve dev workloads
    |
    +--> stop/reconcile dev-owned workloads
    |
    +--> shared engine remains running
    |
    +--> project test source policy
    |
    +--> reconcile test shims
    |
    +--> reconcile test user/agent integrations
    |
    +--> validate test runtime
    |
    +--> commit active profile = test
    |
    v
Success
```

If any pre-commit step fails:

```text
failure
   |
   v
restore prior engine projection
restore prior integrations
restore prior workload state where supported
validate prior profile
retain dev as authoritative active profile
```

---

## 20. Architectural invariants

The future architecture should preserve the following invariants:

1. **Profiles and engines are separate identities.**
2. **A profile binds explicitly to an engine.**
3. **Multiple profiles may bind to one shared engine.**
4. **An isolated profile receives a stronger engine boundary.**
5. **Profile policy is authoritative; engine policy is a projection.**
6. **Workloads have explicit profile ownership.**
7. **Shared engine does not imply shared workload ownership.**
8. **Engine-scoped caches may survive profile switches.**
9. **Shared-profile activation should not restart the engine solely to change profiles.**
10. **Outgoing profile workloads are reconciled before a new shared profile becomes authoritative.**
11. **Destructive authority requires current ownership proof.**
12. **External or ambiguous resources are preserved.**
13. **The active-profile authority commits last.**
14. **Interrupted operations remain inspectable and retryable.**
15. **Human and machine-readable control-plane views describe the same state.**
16. **Backend technology is an implementation detail beneath the engine abstraction.**

---

## 21. Deliberately unresolved areas

The architecture intentionally leaves these decisions open for focused future design:

- exact workload ownership metadata,
- persistent workload-data ownership,
- whether inactive-profile workloads may ever remain running,
- whether profile activation may automatically start declared long-running workloads,
- multiple shared engines,
- remote engines,
- hardware-specialized engine selection,
- workload migration between engines,
- engine resource quotas,
- cross-profile cache policy,
- and the exact future workload-management CLI.

These should be resolved through explicit lifecycle or architecture decisions rather than emerging accidentally from implementation.

---

## 22. Summary

The intended architecture can be reduced to the following model:

```text
                    CATALOG
                       |
                       v
                    PROFILE
                  /    |    \
                 /     |     \
             SHIMS   POLICY   WORKLOAD OWNERSHIP
                 \     |      /
                  \    |     /
                   v   v    v
                   ACTIVATION
                       |
                  engine binding
                       |
                       v
                     ENGINE
                       |
                       v
                   WORKLOADS
```

And the primary user experience should remain:

```text
Choose a profile.
Inspect the impact.
Activate it.
Invoke tools normally.
Choose isolation only when stronger boundaries are required.
Let Shimmy manage the execution details safely.
```
