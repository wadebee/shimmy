<!-- PAGE_ID: shimmy-03-command-line-reference -->
<details>
<summary>📚 Relevant source files</summary>

The following files were used as context for generating this wiki page:

- [README.md:1-197](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L1-L197)
- [help.sh:1-1232](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L1-L1232)
- [admin.sh:1-192](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/admin.sh#L1-L192)
- [profile.sh:1-296](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/profile.sh#L1-L296)
- [catalog.sh:1-162](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/catalog.sh#L1-L162)
- [shim.sh:1-194](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/shim.sh#L1-L194)
- [ai-skill.sh:1-74](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/ai-skill.sh#L1-L74)

</details>

# Command-Line Reference

> **Related Pages**: [[Profile Lifecycle|05-profile-lifecycle.md]], [[Catalog Lifecycle|07-catalog-lifecycle.md]], [[Shims and Tool Execution|08-shims-and-tool-execution.md]]

---

<!-- BEGIN:AUTOGEN shimmy-03-command-line-reference-launcher -->
## Launcher and Help Semantics

The installed launcher follows the grammar `shimmy <group> <command> [options]` and exposes exactly five groups ([help.sh:12-23](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L12-L23)).

| Group | Responsibility |
|---|---|
| `admin` | Inspect or remove the complete installation ([help.sh:18-20](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L18-L20)). |
| `profile` | List, inspect, create, clone, activate, synchronize, repair, or delete profiles ([help.sh:19-21](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L19-L21)). |
| `catalog` | Inspect, verify, refresh, publish, or roll back the immutable default catalog ([help.sh:20-22](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L20-L22)). |
| `shim` | Manage profile-local shims and their concrete installed versions ([help.sh:21-23](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L21-L23)). |
| `ai-skill` | Inspect or repair active-profile AI-skill links ([help.sh:22-23](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L22-L23)). |

Invoking the root, a group, or `profile redirect` without a child command is equivalent to adding `--help`: the command returns status `0`, writes byte-identical help to standard output, leaves standard error empty, and performs no installed-state validation or mutation. Explicit action help is also rendered before installed-state validation ([README.md:3-18](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L3-L18)). The help dispatcher has distinct topics for every group, action, and redirect subcommand, and rejects unknown topics ([help.sh:1157-1232](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L1157-L1232)).

The launcher containing the command determines the **invoking profile**. The installation's **active profile** independently owns engine, registry, mutation, and AI-skill-link authority; sourcing a profile's `shell-init.sh` selects that profile on the current shell's `PATH` ([help.sh:28-32](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L28-L32)). Once an action is dispatched, each group requires installed launcher context through `SHIMMY_CONFIG_ROOT`; profile and shim actions additionally validate the invoking-profile identity ([profile.sh:62-70](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/profile.sh#L62-L70), [shim.sh:141-152](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/shim.sh#L141-L152)).

`commands/bootstrap.sh`, `commands/run-tool.sh`, and `commands/agent-preflight.sh` are source-checkout utilities, not additional installed launcher groups ([README.md:191-197](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L191-L197)).

Sources: [README.md:3-18](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L3-L18), [help.sh:10-59](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L10-L59), [help.sh:1157-1232](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L1157-L1232), [profile.sh:62-70](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/profile.sh#L62-L70), [shim.sh:141-152](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/shim.sh#L141-L152)
<!-- END:AUTOGEN shimmy-03-command-line-reference-launcher -->

---

<!-- BEGIN:AUTOGEN shimmy-03-command-line-reference-admin-profile -->
## Admin and Profile Commands

The `admin` group operates at installation scope, except that network inspection uses the active profile's engine context ([help.sh:63-94](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L63-L94)).

| Command | Options | Behavior |
|---|---|---|
| `shimmy admin status` | `[--format human\|manifest]` | Aggregates the active record, default catalog, and every profile; an individual invalid profile is reported within the aggregate rather than hiding the remaining profiles ([README.md:31-42](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L31-L42), [admin.sh:71-123](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/admin.sh#L71-L123)). |
| `shimmy admin engine status` | `[--format human\|manifest]` | Reports binding mode, engine identity and origin, ownership evidence, and projection freshness without mutation ([README.md:40-42](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L40-L42), [admin.sh:157-174](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/admin.sh#L157-L174)). |
| `shimmy admin network` | `[--target <host-or-ip> ...] [--host-name <name>] [--host-ip <ipv4>] [--host-prefix <bits>] [--host-lan <cidr>] [--format human\|manifest]` | Reports shell, host, VM, and container network perspectives through the active profile. `--target` is repeatable; the default route target is `1.1.1.1` ([README.md:33-44](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L33-L44), [help.sh:170-202](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L170-L202)). |
| `shimmy admin uninstall` | `[--stop-running] [--dry-run]` | Removes validated Shimmy-owned installation state and fully proven owned macOS machines. It preserves source checkouts, external or ambiguous machines, Linux host-local engines, unrelated registry policy, unrelated skill names, and the user skill root ([README.md:45-54](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L45-L54)). |

Run `admin uninstall --dry-run` first. Removing an owned machine permanently destroys its VM-local containers, images, volumes, and build caches; `--stop-running` acknowledges deletion of listed running containers, and a partial removal retains a durable journal plus an exact retry command ([help.sh:206-244](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L206-L244)).

The `profile` group separates installation-wide operations from invoking-profile operations. `list`, `create`, and `clone` are installation-wide; `status`, `sync`, `repair-startup`, and redirects act on the invoking profile; `activate` and `delete` take an installed profile name ([help.sh:247-279](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L247-L279)).

| Command | Options | Behavior |
|---|---|---|
| `shimmy profile list` | `[--format human\|manifest]` | Lists all installed profiles and their local validity ([help.sh:283-307](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L283-L307)). |
| `shimmy profile status` | `[--format human\|manifest]` | Inspects the profile containing the launcher, even if another profile is installation-active ([help.sh:310-335](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L310-L335)). |
| `shimmy profile create <name>` | `[--isolated] [--restart] [--stop-running] [--dry-run]` | Creates and automatically activates a sibling profile. The default binding is shared; on macOS, `--isolated` creates an owned `shimmy-<name>` machine ([README.md:82-89](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L82-L89), [help.sh:338-373](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L338-L373)). |
| `shimmy profile clone <source> <target>` | `[--shared \| --isolated] [--restart] [--stop-running] [--dry-run]` | Copies reproducible profile state but regenerates profile and engine identity and does not copy runtime, startup, active, lock, journal, or ownership state. Shared sources clone to shared by default; isolated sources receive a new owned machine ([README.md:84-89](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L84-L89), [help.sh:376-407](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L376-L407)). |
| `shimmy profile activate <name>` | `[--restart] [--stop-running] [--dry-run]` | Switches engine, registry policy, active record, and exact AI-skill links. Direct activation does not alter the parent shell's `PATH`; source the printed `shell-init.sh` afterward ([help.sh:410-443](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L410-L443)). |
| `shimmy profile sync` | none | Synchronizes the invoking active profile to `refs/heads/main` and the registry-current catalog while preserving exact shim versions, explicit defaults, redirects, engine identity, and startup bytes ([help.sh:446-469](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L446-L469)). |
| `shimmy profile repair-startup` | none | Repairs only the invoking profile's recorded startup files ([profile.sh:157-161](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/profile.sh#L157-L161)). |
| `shimmy profile delete <name>` | `[--stop-running] [--dry-run]` | Deletes only an inactive, non-default profile. Shared deletion removes profile state; deletion of a fully proven owned isolated profile also permanently removes its machine, while external and ambiguous machines are preserved ([README.md:99-106](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L99-L106)). |
| `shimmy profile redirect list` | `[--format human\|manifest]` | Shows the invoking profile's redirect entries, effective policy state, and active-link state ([profile.sh:203-245](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/profile.sh#L203-L245)). |
| `shimmy profile redirect set` | `--prefix <logical> --location <physical> [--dry-run]` | Adds or replaces one validated logical-to-physical registry mapping for the invoking profile ([profile.sh:247-263](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/profile.sh#L247-L263)). |
| `shimmy profile redirect delete` | `(--prefix <logical> \| --all) [--detach] [--dry-run]` | Removes one mapping or all mappings. `--detach` is valid only with `--all` ([profile.sh:265-290](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/profile.sh#L265-L290)). |

Activation dry-run is non-mutating and reports engine, registry service, VM, active-record, and skill-link effects. On Linux, `--restart` and `--stop-running` are not applicable; on macOS, `--restart` is explicit VM recovery and a cross-engine transition requires `--stop-running` if listed workloads would be interrupted ([README.md:91-97](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L91-L97)). Active redirect edits apply immediately; inactive edits change only profile source, while a changed effective macOS policy recycles `podman.service` without stopping the VM or containers ([README.md:108-111](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L108-L111)).

Sources: [README.md:28-111](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L28-L111), [help.sh:63-94](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L63-L94), [help.sh:247-279](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L247-L279), [admin.sh:130-192](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/admin.sh#L130-L192), [profile.sh:62-296](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/profile.sh#L62-L296)
<!-- END:AUTOGEN shimmy-03-command-line-reference-admin-profile -->

---

<!-- BEGIN:AUTOGEN shimmy-03-command-line-reference-catalog-shim -->
## Catalog and Shim Commands

Shimmy owns one installation-wide immutable catalog named `default`. Catalog inspection and verification are separate from profile adoption: publishing or rolling back registry authority does not alter profile pins, which change only through explicit profile synchronization or shim lifecycle work ([README.md:126-151](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L126-L151)).

| Command | Options | Behavior |
|---|---|---|
| `shimmy catalog status` | `[--format human\|manifest]` | Renders local default-catalog authority state ([catalog.sh:63-74](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/catalog.sh#L63-L74)). |
| `shimmy catalog tools` | `[--generation <sha256-generation>] [--format human\|manifest]` | Lists tools from current catalog authority or a specified retained generation ([catalog.sh:75-87](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/catalog.sh#L75-L87)). |
| `shimmy catalog verify` | `[--tool <tool[@version]> ...] [--public-only] [--require-current-upstream] [--format human\|manifest]` | Verifies catalog image indexes through the active profile's jq and Skopeo. `--tool` is repeatable, `--public-only` skips authenticated entries, and `--require-current-upstream` turns upstream tag drift into failure ([help.sh:739-769](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L739-L769)). |
| `shimmy catalog refresh <tool@version>` | `[--dry-run]` | From an attached local `main` checkout root, validates and atomically refreshes tag-backed image records for one exact concrete version; it does not publish or update installed catalog/profile state ([README.md:131-140](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L131-L140), [catalog.sh:114-150](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/catalog.sh#L114-L150)). |
| `shimmy catalog publish` | none | From clean attached local `main`, creates or reuses a content-addressed generation from tracked `tools/`; equivalent content is a no-op and retained generations are not deleted ([README.md:142-150](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L142-L150)). |
| `shimmy catalog rollback` | none | Swaps catalog authority to the retained previous valid generation without changing profile pins or deleting generation directories ([help.sh:845-868](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L845-L868)). |

Shim commands read the invoking profile and its pinned catalog. Mutating actions require that profile to be active, and shim materialization changes commit together with tool-skill links ([README.md:176-177](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L176-L177), [shim.sh:130-138](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/shim.sh#L130-L138)).

| Command | Options | Behavior |
|---|---|---|
| `shimmy shim list` | `[--format human\|manifest]` | Lists invoking-profile shims, defaults, policy, and installed versions; it remains invoking-profile scoped even if a sibling profile is active ([help.sh:904-928](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L904-L928)). |
| `shimmy shim add <tool[@version]>` | none | Adds one tool or exact version. An unqualified selector requires an interactive terminal and creates tracking policy; the first explicit version is noninteractive and creates pinned policy ([shim.sh:52-65](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/shim.sh#L52-L65), [shim.sh:162-170](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/shim.sh#L162-L170)). |
| `shimmy shim remove <tool[@version]>` | none | An unqualified tool removes the complete shim and all versions; an exact selector removes a retained non-default version ([README.md:168-170](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L168-L170)). |
| `shimmy shim set-version <tool@version>` | none | Selects an installed exact version as the direct launcher default and changes policy to pinned ([help.sh:988-1010](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L988-L1010)). |
| `shimmy shim sync [<tool[@version]> ...]` | optional selectors | Prepares installed versions and may advance tracking defaults within the pinned generation. With no selector it processes every installed shim; a tool includes its installed versions and `tool@version` narrows image preparation ([help.sh:1013-1038](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L1013-L1038)). |
| `shimmy shim test [<tool[@version]> ...]` | optional selectors | Runs version-owned non-mutating smoke commands. With no selector it tests every installed version, a tool selects its default, and `tool@version` selects that exact installed version ([help.sh:1041-1066](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L1041-L1066)). |

Sources: [README.md:113-177](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L113-L177), [help.sh:739-868](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L739-L868), [help.sh:871-1066](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L871-L1066), [catalog.sh:36-162](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/catalog.sh#L36-L162), [shim.sh:21-194](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/shim.sh#L21-L194)
<!-- END:AUTOGEN shimmy-03-command-line-reference-catalog-shim -->

---

<!-- BEGIN:AUTOGEN shimmy-03-command-line-reference-ai-skill -->
## AI-Skill Commands

AI-skill commands operate on the active profile and the immutable user skill root recorded at bootstrap ([help.sh:1069-1085](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L1069-L1085)).

| Command | Options | Behavior |
|---|---|---|
| `shimmy ai-skill list` | `[--format human\|manifest]` | Classifies the active profile's control and shim bundles plus exact user-link destinations. Unsupported bundles emit no skill rows; malformed supported bundles are reported invalid ([help.sh:1099-1124](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L1099-L1124)). |
| `shimmy ai-skill repair` | none | Stages and validates both supported bundles, replaces exact declared collisions, removes recognized stale Shimmy links, and preserves unrelated names. It never recursively cleans the user skill root ([README.md:179-189](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L179-L189)). |

`repair` has no dry-run, force, backup, broad-cleanup, or recovery option. Every exact bundle-declared destination is reserved and replaced even when it is a file, nonempty directory, foreign link, or broken link; overwritten foreign bytes are not recoverable, while unrelated names and the root survive ([help.sh:1127-1154](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L1127-L1154)). Run `ai-skill list --format manifest` first; profile activation `--dry-run` is the available non-mutating preview of exact link collisions ([help.sh:1087-1089](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L1087-L1089)).

The repair command accepts no arguments. A recoverable warning path writes `WARNING:` to standard error and returns status `2`; other failures use the normal error path ([ai-skill.sh:61-73](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/ai-skill.sh#L61-L73)).

Sources: [README.md:179-189](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L179-L189), [help.sh:1069-1154](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L1069-L1154), [ai-skill.sh:21-74](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/ai-skill.sh#L21-L74)
<!-- END:AUTOGEN shimmy-03-command-line-reference-ai-skill -->

---

<!-- BEGIN:AUTOGEN shimmy-03-command-line-reference-output-contracts -->
## Selectors and Output Contracts

### Selectors

Shim selectors have two forms: unqualified `tool` and exact `tool@version`. A selector may contain at most one `@`; the tool name and optional version are validated independently ([shim.sh:38-50](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/shim.sh#L38-L50)). The same syntax appears in catalog verification filters, but catalog refresh requires exactly one qualified `tool@version` selector ([catalog.sh:88-107](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/catalog.sh#L88-L107), [catalog.sh:114-143](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/catalog.sh#L114-L143)). For automation, use an exact `tool@version` with `shim add`, because an unqualified add requires an interactive terminal ([help.sh:931-957](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L931-L957)).

### Output formats

Human-readable output is the default wherever `--format` is available. Those commands support `human` and stable line-oriented `manifest` output ([README.md:20-21](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L20-L21)).

| Group | Commands accepting `--format human\|manifest` |
|---|---|
| `admin` | `status`, `engine status`, `network` ([admin.sh:33-39](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/admin.sh#L33-L39)). |
| `profile` | `list`, `status`, `redirect list` ([profile.sh:33-44](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/profile.sh#L33-L44)). |
| `catalog` | `status`, `tools`, `verify` ([catalog.sh:40-47](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/catalog.sh#L40-L47)). |
| `shim` | `list` ([shim.sh:25-31](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/shim.sh#L25-L31)). |
| `ai-skill` | `list` ([ai-skill.sh:21-30](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/ai-skill.sh#L21-L30)). |

Manifest output is line-oriented `key=value` data. For example, `admin status` emits the active profile plus encoded per-profile records, while `profile redirect list` emits profile, policy, active-link state, and one line per redirect ([admin.sh:49-77](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/admin.sh#L49-L77), [profile.sh:225-233](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/profile.sh#L225-L233)). Successful `catalog publish` and `catalog rollback` render catalog status in manifest form even though neither action accepts a format option ([catalog.sh:151-160](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/catalog.sh#L151-L160)).

### Dry runs and help

`--dry-run` belongs only to commands whose usage declares it: `admin uninstall`; profile `create`, `clone`, `activate`, `delete`, redirect `set`, and redirect `delete`; and `catalog refresh` ([README.md:30-36](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L30-L36), [README.md:58-71](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L58-L71), [README.md:115-123](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L115-L123)). The exact preview varies by command: activation reports engine, registry, VM, active-record, and skill-link effects, while catalog refresh performs remote resolution and validation without writing the checkout ([README.md:91-97](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L91-L97), [README.md:131-140](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L131-L140)).

Use `shimmy <group> <command> --help` for action-specific scope, options, defaults, remediation, and examples. Help is deliberately available before installed-state validation ([help.sh:14-26](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L14-L26)).

Sources: [README.md:3-26](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/README.md#L3-L26), [help.sh:10-59](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/help.sh#L10-L59), [admin.sh:29-40](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/admin.sh#L29-L40), [profile.sh:29-49](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/profile.sh#L29-L49), [catalog.sh:36-50](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/catalog.sh#L36-L50), [shim.sh:21-50](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/shim.sh#L21-L50), [ai-skill.sh:21-30](https://github.com/wadebee/shimmy/blob/aaebadedc4bd1ac9f56f7e31bd394ae86cd97485/commands/ai-skill.sh#L21-L30)
<!-- END:AUTOGEN shimmy-03-command-line-reference-output-contracts -->

---
