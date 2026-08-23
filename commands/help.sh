#!/bin/sh
# Installed command-surface help.
set -eu

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

shimmy_help_root() {
  cat <<'EOF'
Manage the active Shimmy installation and the profile containing this launcher.

Usage:
  shimmy <group> <command> [options]
  shimmy <group> <command> --help

Groups:
  admin       Inspect or remove the complete installation.
  profile     List, inspect, create, activate, sync, repair, or delete profiles.
  catalog     Inspect, verify, publish, or roll back the immutable default catalog.
  shim        Manage profile-local shims and their installed versions.
  ai-skill    Inspect or repair active-profile AI-skill links.

Options:
  -h, --help  Show help without validating installed state.

Defaults:
  Human-readable output is the default where --format is available.
  The profile containing this launcher is the invoking profile. The installation
  active profile independently owns engine, registry, mutation, and AI-skill-link
  authority. Source a profile's shell-init.sh to select it in the current shell.

Scope:
  This launcher manages one installation rooted beside its profiles directory.
  Only the installation-owned immutable catalog named default is supported.
  Shim selectors are unqualified tool or tool@version values.

Overwrite warning:
  Activation and AI-skill reconciliation unconditionally replace every exact
  bundle-declared user skill destination without backup or recovery. They never
  recursively delete the user skill root or unrelated skill names. Use
  'shimmy profile activate <name> --dry-run' to inspect exact collisions first.

Remediation:
  Use 'shimmy admin status --format manifest' for installation-wide diagnosis,
  'shimmy profile status --format manifest' for the invoking profile,
  'shimmy profile repair-startup' for its recorded startup ledger, and
  'shimmy ai-skill repair' for active-profile links. Missing catalog verification
  dependencies report the exact versioned 'shimmy shim add' command to run.

Examples:
  shimmy admin status
  shimmy profile create team-one --dry-run
  shimmy shim add jq@1.8
  shimmy catalog verify --public-only
  shimmy ai-skill list --format manifest

Run 'shimmy <group> --help' to list a group's commands.
EOF
}

shimmy_help_admin() {
  cat <<'EOF'
Inspect or remove the complete Shimmy installation.

Usage:
  shimmy admin <command> [options]

Commands:
  status      Aggregate catalog and per-profile state.
  engine      Inspect or explicitly migrate engine bindings.
  network     Show active-profile host, VM, and container network perspectives.
  uninstall   Remove all validated Shimmy-owned installation state.

Scope:
  Admin commands are installation-wide. Network inspection uses the active
  profile. Uninstall preserves source checkouts, Podman machines, operator
  registry policy, the user skill root, and unrelated user skill names.

Remediation:
  Run 'shimmy admin status --format manifest' before destructive administration.

Examples:
  shimmy admin status
  shimmy admin network --format manifest
  shimmy admin uninstall

Run 'shimmy admin <command> --help' for command options and defaults.
EOF
}

shimmy_help_admin_engine() {
  cat <<'EOF'
Inspect or migrate the installation engine registry.

Usage:
  shimmy admin engine <command> [options]

Commands:
  status   Report binding, engine, ownership, and projection state.
  migrate  Explicitly migrate a schema-2 per-profile-engine installation.

Migration never adopts an existing machine. On macOS, every existing profile
is recorded as legacy-external and a new owned shared machine named shimmy is
created only after collision and identity preflight.

Scope:
  Installation-wide. Status is read-only; migration is explicit.

Remediation:
  Run engine status, then migration --dry-run before migration.
EOF
}

shimmy_help_admin_engine_status() {
  cat <<'EOF'
Inspect engine registry state without mutation.

Usage:
  shimmy admin engine status [--format human|manifest]

Scope:
  Installation-wide and read-only.

Options:
  --format human|manifest  Output format. Default: human.
  -h, --help               Show this help before installed-state validation.

Defaults:
  Output format: human.

Remediation:
  Run migration --dry-run when the schema state is unmigrated.

Examples:
  shimmy admin engine status
  shimmy admin engine status --format manifest
EOF
}

shimmy_help_admin_engine_migrate() {
  cat <<'EOF'
Explicitly publish engine and profile-binding state.

Usage:
  shimmy admin engine migrate [--dry-run]

Scope:
  Installation-wide compatibility transition. Existing profile machines remain
  external and are not renamed, adopted, stopped, started, or removed.

Options:
  --dry-run   Validate collisions, machine identities, and the write set without
              creating a machine or changing installation state.
  -h, --help  Show this help before installed-state validation.

Defaults:
  Migration performs no VM restart and never claims an existing machine.

On macOS, migration preserves every existing profile machine as external and
creates the installation-owned shared machine shimmy for future profiles.

Remediation:
  Resolve every reported collision before retrying. Shimmy does not adopt it.

Examples:
  shimmy admin engine migrate --dry-run
  shimmy admin engine migrate
EOF
}

shimmy_help_admin_status() {
  cat <<'EOF'
Aggregate local catalog and per-profile status without mutation.

Usage:
  shimmy admin status [--format human|manifest]

Scope:
  Installation-wide. Profile inspection errors are reported per profile while
  profiles-root, active-record, catalog, or orchestration errors are fatal.

Options:
  --format human|manifest  Output format. Default: human.
  -h, --help               Show this help before installed-state validation.

Defaults:
  Output format: human.

Remediation:
  Manifest output identifies the active profile and nests each profile status
  record for machine-readable diagnosis.

Examples:
  shimmy admin status
  shimmy admin status --format manifest
EOF
}

shimmy_help_admin_network() {
  cat <<'EOF'
Show network perspectives using the active profile's engine context.

Usage:
  shimmy admin network [--target <host-or-ip> ...]
    [--host-name <name>] [--host-ip <ipv4>] [--host-prefix <bits>]
    [--host-lan <cidr>] [--format human|manifest]

Scope:
  Read-only active-profile inspection. Explicit host inputs disambiguate shells
  running inside a VM or container.

Options:
  --target <host-or-ip>    Add a route-perspective target. Repeatable.
  --host-name <name>       Resolve a host-side DHCP or DNS name.
  --host-ip <ipv4>         Supply the host-side IPv4 address.
  --host-prefix <bits>     Derive a LAN CIDR with --host-ip or --host-name.
  --host-lan <cidr>        Supply the host-side LAN CIDR directly.
  --format human|manifest  Output format. Default: human.
  -h, --help               Show this help before installed-state validation.

Defaults:
  Route target: 1.1.1.1. Output format: human.

Remediation:
  If host LAN discovery is ambiguous, rerun with --host-lan or with --host-ip
  and --host-prefix.

Examples:
  shimmy admin network
  shimmy admin network --target 192.168.1.1 --host-lan 192.168.1.0/24
  shimmy admin network --format manifest
EOF
}

shimmy_help_admin_uninstall() {
  cat <<'EOF'
Remove all validated Shimmy-owned installation state.

Usage:
  shimmy admin uninstall [--stop-running]

Scope:
  Installation-wide and destructive. Removes validated profiles, retained
  default-catalog generations, the active record, exact startup blocks,
  recognized projections, and recognized direct Shimmy user-skill links.

Options:
  --stop-running  Acknowledge interruption of listed running containers when a
                  projected macOS machine must stop.
  -h, --help      Show this help before installed-state validation.

Defaults:
  Running workloads are never interrupted without --stop-running.

Remediation:
  Run without --stop-running first. If Shimmy reports running containers, review
  the exact list and retry only after explicitly accepting their interruption.

Examples:
  shimmy admin uninstall
  shimmy admin uninstall --stop-running
EOF
}

shimmy_help_profile() {
  cat <<'EOF'
Manage independently materialized Shimmy profiles.

Usage:
  shimmy profile <command> [options]

Commands:
  list              List every installed profile.
  status            Inspect the profile containing this launcher.
  create            Create and automatically activate a sibling profile.
  clone             Clone reproducible profile state under a new identity.
  activate          Activate an installed profile by name.
  sync              Sync the invoking active profile from refs/heads/main.
  repair-startup    Repair the invoking profile's exact startup ledger.
  delete            Delete an inactive non-default profile.
  redirect          List or mutate invoking-profile registry redirects.

Scope:
  List, create, and clone are installation-wide. Status, sync, repair-startup,
  and redirect use the invoking profile. Activate and delete take an installed name.

Remediation:
  Run 'shimmy profile status --format manifest' and an activation --dry-run
  before changing engine authority.

Examples:
  shimmy profile list
  shimmy profile status
  shimmy profile create team-one --dry-run
  shimmy profile activate default

Run 'shimmy profile <command> --help' for command options and defaults.
EOF
}

shimmy_help_profile_list() {
  cat <<'EOF'
List installed profiles and their local validity.

Usage:
  shimmy profile list [--format human|manifest]

Scope:
  Installation-wide and read-only.

Options:
  --format human|manifest  Output format. Default: human.
  -h, --help               Show this help before installed-state validation.

Defaults:
  Output format: human.

Remediation:
  Inspect an invalid profile through its absolute launcher and
  'shimmy profile status --format manifest'.

Examples:
  shimmy profile list
  shimmy profile list --format manifest
EOF
}

shimmy_help_profile_status() {
  cat <<'EOF'
Inspect the profile containing this launcher.

Usage:
  shimmy profile status [--format human|manifest]

Scope:
  Invoking-profile and read-only. Active identity remains installation-wide and
  may name a different profile.

Options:
  --format human|manifest  Output format. Default: human.
  -h, --help               Show this help before installed-state validation.

Defaults:
  Output format: human.

Remediation:
  Use 'shimmy profile activate <name> --dry-run' when engine, registry, or active
  authority is not aligned.

Examples:
  shimmy profile status
  shimmy profile status --format manifest
EOF
}

shimmy_help_profile_create() {
  cat <<'EOF'
Create a sibling profile from the invoking profile's exact control and catalog pin.

Usage:
  shimmy profile create <name> [--isolated] [--restart] [--stop-running] [--dry-run]

Scope:
  Installation-wide creation from the invoking profile. The new profile receives
  a shared-engine binding, catalog-default jq, rg, and Skopeo and is
  automatically activated. --isolated creates an owned shimmy-<name> machine.

Options:
  --restart       Explicitly restart a stopped or unhealthy macOS VM; normal
                  shared policy activation recycles only podman.service.
  --isolated      Create and bind an installation-owned isolated macOS machine.
  --stop-running  Acknowledge interruption of listed running containers.
  --dry-run       Read and classify the complete image, engine, link, and startup
                  plan without persistent mutation.
  -h, --help      Show this help before installed-state validation.

Defaults:
  No restart, no workload interruption, and mutation enabled.

Overwrite warning:
  Activation replaces exact bundle-declared user skill destinations without
  backup. A dry run lists those collisions and never changes them.

Remediation:
  Run with --dry-run first. Add --restart only for explicit VM recovery and add
  --stop-running only after reviewing an exact VM-transition workload refusal.

Examples:
  shimmy profile create team-one --dry-run
  shimmy profile create team-one
EOF
}

shimmy_help_profile_clone() {
  cat <<'EOF'
Clone one profile's reproducible state and activate the new profile.

Usage:
  shimmy profile clone <source> <target> [--shared | --isolated]
    [--restart] [--stop-running] [--dry-run]

Scope:
  Installation-wide. Clone copies validated control/catalog pins, shim policy,
  exact versions, and registry redirects. It regenerates profile and engine
  identity and never copies startup, active, lock, journal, or ownership state.

Options:
  --shared        Bind the clone to the shared engine.
  --isolated      Create a fresh owned shimmy-<target> machine.
  --restart       Explicit VM recovery during activation.
  --stop-running  Acknowledge listed workloads interrupted by an engine switch.
  --dry-run       Validate and print the clone, engine, image, and link plan.
  -h, --help      Show this help before installed-state validation.

Defaults:
  Shared sources clone to shared. Isolated and legacy-isolated sources create a
  new owned isolated machine. Mutation is enabled.

Remediation:
  Run --dry-run first. Review exact workloads before adding --stop-running.

Examples:
  shimmy profile clone default experiment --dry-run
  shimmy profile clone legacy-team replacement --shared
EOF
}

shimmy_help_profile_activate() {
  cat <<'EOF'
Activate an installed profile's engine, registry policy, active record, and links.

Usage:
  shimmy profile activate <name> [--restart] [--stop-running] [--dry-run]

Scope:
  Installation-wide activation of the named profile. It does not change the
  parent shell's PATH unless invoked through a sourced Shimmy shell wrapper.

Options:
  --restart       Explicitly restart a stopped or unhealthy macOS VM; normal
                  shared policy activation recycles only podman.service.
  --stop-running  Acknowledge interruption of listed running containers.
  --dry-run       Inspect the complete transition and exact link collisions
                  without persistent mutation.
  -h, --help      Show this help before installed-state validation.

Defaults:
  No restart, no workload interruption, and mutation enabled.

Overwrite warning:
  Successful activation replaces exact bundle-declared user skill destinations
  without backup. Unrelated user skill names and the user skill root survive.

Remediation:
  Run --dry-run first. After direct activation, source the exact shell-init.sh
  path printed by Shimmy to select that profile in the current shell.

Examples:
  shimmy profile activate team-one --dry-run
  shimmy profile activate team-one
EOF
}

shimmy_help_profile_sync() {
  cat <<'EOF'
Sync the invoking active profile to explicit refs/heads/main and catalog current.

Usage:
  shimmy profile sync

Scope:
  Invoking profile; mutation requires that profile to be active. Preserves exact
  shim versions, explicit defaults, redirects, engine identity, and startup bytes.

Options:
  -h, --help  Show this help before installed-state validation.

Defaults:
  Control ref: refs/heads/main. Catalog: registry-current immutable default.

Remediation:
  Activate the invoking profile first. If an exact version is unavailable in the
  new generation, remove it or roll back catalog authority before retrying.

Examples:
  shimmy profile sync
EOF
}

shimmy_help_profile_repair_startup() {
  cat <<'EOF'
Repair only the invoking profile's recorded startup files.

Usage:
  shimmy profile repair-startup

Scope:
  Invoking profile. No startup ledger is a successful no-op; no arbitrary path
  or shell selector is accepted.

Options:
  -h, --help  Show this help before installed-state validation.

Defaults:
  Uses only startup_shell and startup_file records from the profile manifest.

Remediation:
  Changing startup policy requires uninstalling and bootstrapping a new default
  profile; repair cannot adopt new files.

Examples:
  shimmy profile repair-startup
EOF
}

shimmy_help_profile_delete() {
  cat <<'EOF'
Delete an installed inactive non-default profile.

Usage:
  shimmy profile delete <name> [--stop-running] [--dry-run]

Scope:
  Named profile deletion. The default profile and active profile cannot be
  deleted. User AI-skill links are unchanged because only an inactive profile
  is eligible.

Options:
  --stop-running  Acknowledge interruption of listed running containers during
                  guarded owned isolated-machine deletion.
  --dry-run       Print the exact engine ownership and deletion action.
  -h, --help      Show this help before installed-state validation.

Defaults:
  Shared engines and external machines are preserved. An owned isolated machine
  is deleted by default; its VM-local data is permanently destroyed.

Remediation:
  Activate a retained sibling first, then retry deletion. Review any workload
  refusal before adding --stop-running.

Examples:
  shimmy profile delete team-one
  shimmy profile delete team-one --dry-run
EOF
}

shimmy_help_profile_redirect() {
  cat <<'EOF'
Inspect or mutate strict invoking-profile registry redirects.

Usage:
  shimmy profile redirect <command> [options]

Commands:
  list    List exact prefix-to-location redirects.
  set     Add or replace one exact redirect.
  delete  Delete one redirect or all redirects.

Scope:
  Invoking profile. Mutation requires that profile to be active.

Remediation:
  Use list --format manifest to inspect policy. Use delete --all --detach only
  for explicit recovery that must remove the exact active projection.

Examples:
  shimmy profile redirect list
  shimmy profile redirect set --prefix registry.example --location mirror.example
  shimmy profile redirect delete --prefix registry.example

Run 'shimmy profile redirect <command> --help' for options and defaults.
EOF
}

shimmy_help_profile_redirect_list() {
  cat <<'EOF'
List strict registry redirects for the invoking profile.

Usage:
  shimmy profile redirect list [--format human|manifest]

Scope:
  Invoking-profile and read-only.

Options:
  --format human|manifest  Output format. Default: human.
  -h, --help               Show this help before installed-state validation.

Defaults:
  Output format: human.

Remediation:
  A stale shared macOS projection is repaired by ordinary profile activation;
  --restart is reserved for explicit VM recovery.

Examples:
  shimmy profile redirect list
  shimmy profile redirect list --format manifest
EOF
}

shimmy_help_profile_redirect_set() {
  cat <<'EOF'
Add or replace one exact invoking-profile registry redirect.

Usage:
  shimmy profile redirect set --prefix <logical> --location <physical> [--dry-run]

Scope:
  Invoking profile. Active edits apply and validate immediately; inactive edits
  change only their source policy. Uses replacement semantics, never mirrors.

Options:
  --prefix <logical>      Exact logical registry prefix. Required.
  --location <physical>  Exact replacement registry location. Required.
  --dry-run               Render the candidate and report whether the active
                          shared API service would recycle, without mutation.
  -h, --help              Show this help before installed-state validation.

Defaults:
  Mutation enabled; no prefix or location default.

Remediation:
  Use --dry-run first. Shared-policy changes recycle podman.service while the VM
  and running containers remain up.

Examples:
  shimmy profile redirect set --prefix registry.example --location mirror.example --dry-run
  shimmy profile redirect set --prefix registry.example --location mirror.example
EOF
}

shimmy_help_profile_redirect_delete() {
  cat <<'EOF'
Delete one or all invoking-profile registry redirects.

Usage:
  shimmy profile redirect delete (--prefix <logical> | --all)
    [--detach] [--dry-run]

Scope:
  Invoking profile. Active edits apply immediately; inactive edits change only
  their source. Legacy --detach removes only an exact owned active projection
  and is valid only with --all.

Options:
  --prefix <logical>  Delete one exact logical prefix.
  --all               Delete every generated redirect while retaining valid
                      empty managed policy.
  --detach            With --all, detach the exact owned active projection.
  --dry-run           Render the candidate and shared-service action without
                      mutation.
  -h, --help          Show this help before installed-state validation.

Defaults:
  Mutation enabled; exactly one of --prefix or --all is required.

Remediation:
  Reserve --all --detach for recovery or debugging. Normal profile deletion and
  admin uninstall perform their own guarded projection cleanup.

Examples:
  shimmy profile redirect delete --prefix registry.example
  shimmy profile redirect delete --all --dry-run
EOF
}

shimmy_help_catalog() {
  cat <<'EOF'
Inspect and maintain the installation-owned immutable default catalog.

Usage:
  shimmy catalog <command> [options]

Commands:
  status    Show local registry-current and retained-previous authority.
  tools     List tools in current or one retained generation.
  verify    Verify configured remote image indexes and upstream drift.
  publish   Publish clean committed local main content.
  rollback  Swap current with the retained valid previous generation.

Scope:
  Only the catalog literally named default is supported. No external catalog,
  membership, qualified-selector, or release-channel command exists.

Remediation:
  Use status and tools before publication. Catalog verify reports exact
  versioned shim-add remediation when jq or Skopeo is absent.

Examples:
  shimmy catalog status
  shimmy catalog tools
  shimmy catalog verify --public-only

Run 'shimmy catalog <command> --help' for command options and defaults.
EOF
}

shimmy_help_catalog_status() {
  cat <<'EOF'
Show local immutable default-catalog authority.

Usage:
  shimmy catalog status [--format human|manifest]

Scope:
  Installation-wide, local-only, and read-only.

Options:
  --format human|manifest  Output format. Default: human.
  -h, --help               Show this help before installed-state validation.

Defaults:
  Catalog: default. Output format: human.

Remediation:
  Use 'shimmy catalog rollback' only when a retained valid previous generation
  is present.

Examples:
  shimmy catalog status
  shimmy catalog status --format manifest
EOF
}

shimmy_help_catalog_tools() {
  cat <<'EOF'
List tools in current or one retained default-catalog generation.

Usage:
  shimmy catalog tools [--generation <id>] [--format human|manifest]

Scope:
  Installation-wide, local-only, and read-only. Tool availability is distinct
  from profile-local shim installation.

Options:
  --generation <id>       Inspect one retained sha256 generation.
  --format human|manifest  Output format. Default: human.
  -h, --help               Show this help before installed-state validation.

Defaults:
  Generation: registry current. Output format: human.

Remediation:
  Use the exact generation shown by profile status when inspecting a profile pin.

Examples:
  shimmy catalog tools
  shimmy catalog tools --format manifest
EOF
}

shimmy_help_catalog_verify() {
  cat <<'EOF'
Verify default-catalog image indexes, required platforms, digests, and drift.

Usage:
  shimmy catalog verify [--tool <tool[@version]> ...]
    [--public-only] [--require-current-upstream] [--format human|manifest]

Scope:
  Catalog selection is installation-wide; jq and Skopeo execute only from the
  active profile's exact materialization with its strict registry policy.

Options:
  --tool <tool[@version]>       Narrow verification. Repeatable.
  --public-only                 Skip authenticated entries visibly.
  --require-current-upstream    Treat upstream tag drift as failure.
  --format human|manifest       Output format. Default: human.
  -h, --help                    Show this help before installed-state validation.

Defaults:
  Verify every current-catalog version, include authenticated entries, warn on
  upstream drift, and render human output.

Remediation:
  Missing jq or Skopeo prints the exact 'shimmy shim add <tool>@<version>'
  command. Activate the intended profile before retrying verification.

Examples:
  shimmy catalog verify
  shimmy catalog verify --tool jq@1.8 --format manifest
  shimmy catalog verify --public-only --require-current-upstream
EOF
}

shimmy_help_catalog_publish() {
  cat <<'EOF'
Publish clean committed local main content as an immutable default generation.

Usage:
  shimmy catalog publish

Scope:
  Run from the repository root on attached local main. Publication advances only
  the installation default-catalog registry; profile pins remain unchanged.

Options:
  -h, --help  Show this help before installed-state validation.

Defaults:
  Source ref: refs/heads/main. Catalog: default. Retained generations are never
  deleted.

Remediation:
  Commit or remove worktree changes, attach main, and ensure HEAD still equals
  refs/heads/main before retrying.

Examples:
  shimmy catalog publish
EOF
}

shimmy_help_catalog_rollback() {
  cat <<'EOF'
Swap default-catalog current with its retained valid previous generation.

Usage:
  shimmy catalog rollback

Scope:
  Installation-wide default-catalog registry mutation. Profile pins and retained
  generation directories remain unchanged.

Options:
  -h, --help  Show this help before installed-state validation.

Defaults:
  Catalog: default. No generation selector is accepted.

Remediation:
  Rollback requires a retained valid previous generation. Use catalog status to
  inspect current and previous authority.

Examples:
  shimmy catalog rollback
EOF
}

shimmy_help_shim() {
  cat <<'EOF'
Manage profile-local shims and their installed concrete versions.

Usage:
  shimmy shim <command> [options]

Commands:
  list         List invoking-profile shims, defaults, policy, and versions.
  add          Add one tool or exact version.
  remove       Remove one exact non-default version or the complete shim.
  set-version  Select an installed exact version as the shim default.
  sync         Prepare installed versions and advance tracking defaults.
  test         Run non-mutating version-owned smoke commands.

Scope:
  Reads use the invoking profile. Mutation requires the invoking profile to be
  active and uses only that profile's pinned immutable catalog generation.

Remediation:
  Activate the invoking profile before mutation. Use catalog tools --generation
  with the pinned generation shown by profile status to inspect availability.

Examples:
  shimmy shim list
  shimmy shim add jq@1.8
  shimmy shim sync
  shimmy shim test

Run 'shimmy shim <command> --help' for command options and defaults.
EOF
}

shimmy_help_shim_list() {
  cat <<'EOF'
List invoking-profile shims and installed versions.

Usage:
  shimmy shim list [--format human|manifest]

Scope:
  Invoking-profile and read-only, even when a sibling profile is active.

Options:
  --format human|manifest  Output format. Default: human.
  -h, --help               Show this help before installed-state validation.

Defaults:
  Output format: human.

Remediation:
  Use profile status to inspect the invoking profile's catalog pin and active
  authority independently.

Examples:
  shimmy shim list
  shimmy shim list --format manifest
EOF
}

shimmy_help_shim_add() {
  cat <<'EOF'
Add one tool or exact version to the invoking active profile.

Usage:
  shimmy shim add <tool[@version]>

Scope:
  Invoking-profile mutation; the invoking profile must be active. Availability
  comes only from its pinned default-catalog generation.

Options:
  -h, --help  Show this help before installed-state validation.

Defaults:
  Unqualified tool selection is interactive, defaults to the catalog default,
  and creates tracking policy. An explicit first tool@version is noninteractive
  and creates pinned policy. Later versions are exact slots.

Remediation:
  Automation must use tool@version. Activate the invoking profile before retrying
  an inactive-profile mutation.

Examples:
  shimmy shim add jq
  shimmy shim add jq@1.8
EOF
}

shimmy_help_shim_remove() {
  cat <<'EOF'
Remove one exact non-default version or a complete shim.

Usage:
  shimmy shim remove <tool[@version]>

Scope:
  Invoking active profile. Removing a tool removes every installed version,
  launcher, configuration, and its generated tool AI skill.

Options:
  -h, --help  Show this help before installed-state validation.

Defaults:
  tool removes the complete shim; tool@version removes one exact slot. The
  selected default version cannot be removed directly.

Remediation:
  Use shim set-version to select another installed exact version before removing
  the former default, or remove the complete shim.

Examples:
  shimmy shim remove jq@1.7
  shimmy shim remove jq
EOF
}

shimmy_help_shim_set_version() {
  cat <<'EOF'
Select an installed exact version as the shim default.

Usage:
  shimmy shim set-version <tool@version>

Scope:
  Invoking active profile. Atomically swaps the exact and default roles and sets
  the shim policy to pinned.

Options:
  -h, --help  Show this help before installed-state validation.

Defaults:
  No selector default; an exact installed tool@version is required.

Remediation:
  Add the version first with shim add tool@version when it is not installed.

Examples:
  shimmy shim set-version jq@1.8
EOF
}

shimmy_help_shim_sync() {
  cat <<'EOF'
Prepare installed shim versions and advance selected tracking defaults.

Usage:
  shimmy shim sync [<tool[@version]> ...]

Scope:
  Invoking active profile and its pinned immutable catalog generation. Exact
  slots stay pinned; tracking defaults may advance within that generation.

Options:
  -h, --help  Show this help before installed-state validation.

Defaults:
  With no selectors, sync every installed shim. A tool selector includes its
  installed versions; tool@version narrows image preparation to that version.

Remediation:
  If an installed exact version is absent from the pinned generation, remove the
  version or change profile catalog authority through profile sync/rollback.

Examples:
  shimmy shim sync
  shimmy shim sync jq oc@4.20
EOF
}

shimmy_help_shim_test() {
  cat <<'EOF'
Run version-owned non-mutating smoke commands.

Usage:
  shimmy shim test [<tool[@version]> ...]

Scope:
  Invoking-profile read/execution. Runtime affinity may still require that the
  invoking profile be installation-active.

Options:
  -h, --help  Show this help before installed-state validation.

Defaults:
  With no selectors, test every installed version. A tool selects its default;
  tool@version selects that exact installed version.

Remediation:
  Activate the invoking profile when a runtime reports profile-affinity failure.

Examples:
  shimmy shim test
  shimmy shim test jq
  shimmy shim test jq@1.8
EOF
}

shimmy_help_ai_skill() {
  cat <<'EOF'
Inspect or repair direct user links from the active profile's AI-skill bundles.

Usage:
  shimmy ai-skill <command> [options]

Commands:
  list    Classify control/shim bundles and exact user-link destinations.
  repair  Reconcile supported bundles and exact active-profile links.

Scope:
  Active profile and the immutable user skill root recorded at bootstrap.

Overwrite warning:
  Repair unconditionally replaces exact bundle-declared destinations without
  backup or recovery. It never recursively deletes the root or unrelated names.

Remediation:
  Use list --format manifest before repair. Profile activation --dry-run is the
  available non-mutating collision preview; repair has no dry-run option.

Examples:
  shimmy ai-skill list
  shimmy ai-skill repair

Run 'shimmy ai-skill <command> --help' for command options and defaults.
EOF
}

shimmy_help_ai_skill_list() {
  cat <<'EOF'
Classify active-profile AI-skill bundles and exact user-link destinations.

Usage:
  shimmy ai-skill list [--format human|manifest]

Scope:
  Active-profile and read-only. Unsupported bundles emit no skill rows; malformed
  supported bundles are reported invalid.

Options:
  --format human|manifest  Output format. Default: human.
  -h, --help               Show this help before installed-state validation.

Defaults:
  Output format: human.

Remediation:
  Run ai-skill repair for supported bundle/link drift. Sync or reinstall the
  active profile when supported bundle contents are malformed.

Examples:
  shimmy ai-skill list
  shimmy ai-skill list --format manifest
EOF
}

shimmy_help_ai_skill_repair() {
  cat <<'EOF'
Reconcile supported active-profile AI-skill bundles and exact user links.

Usage:
  shimmy ai-skill repair

Scope:
  Active profile and its recorded immutable user skill root.

Options:
  -h, --help  Show this help before installed-state validation.

Defaults:
  No dry-run, force, backup, broad-cleanup, or recovery option exists.

Overwrite warning:
  Every exact bundle-declared destination is reserved and is replaced even when
  it is a file, nonempty directory, foreign link, or broken link. Foreign bytes
  are not recoverable. Unrelated names and the user skill root survive.

Remediation:
  Run ai-skill list first. Use profile activation --dry-run to preview exact
  collisions without mutation. Sync or reinstall malformed supported bundles.

Examples:
  shimmy ai-skill repair
EOF
}

shimmy_help_group=${1:-root}
case "$shimmy_help_group" in
  root) shimmy_help_root ;;
  admin)
    case "${2:-}" in
      ''|help|-h|--help) shimmy_help_admin ;;
      status) shimmy_help_admin_status ;;
      engine)
        case "${3:-}" in
          ''|help|-h|--help) shimmy_help_admin_engine ;;
          status) shimmy_help_admin_engine_status ;;
          migrate) shimmy_help_admin_engine_migrate ;;
          *) fail "unknown admin engine help topic: ${3:-}" ;;
        esac
        ;;
      network) shimmy_help_admin_network ;;
      uninstall) shimmy_help_admin_uninstall ;;
      *) fail "unknown admin help topic: ${2:-}" ;;
    esac
    ;;
  profile)
    case "${2:-}" in
      ''|help|-h|--help) shimmy_help_profile ;;
      list) shimmy_help_profile_list ;;
      status) shimmy_help_profile_status ;;
      create) shimmy_help_profile_create ;;
      clone) shimmy_help_profile_clone ;;
      activate) shimmy_help_profile_activate ;;
      sync) shimmy_help_profile_sync ;;
      repair-startup) shimmy_help_profile_repair_startup ;;
      delete) shimmy_help_profile_delete ;;
      redirect)
        case "${3:-}" in
          ''|help|-h|--help) shimmy_help_profile_redirect ;;
          list) shimmy_help_profile_redirect_list ;;
          set) shimmy_help_profile_redirect_set ;;
          delete) shimmy_help_profile_redirect_delete ;;
          *) fail "unknown profile redirect help topic: ${3:-}" ;;
        esac
        ;;
      *) fail "unknown profile help topic: ${2:-}" ;;
    esac
    ;;
  catalog)
    case "${2:-}" in
      ''|help|-h|--help) shimmy_help_catalog ;;
      status) shimmy_help_catalog_status ;;
      tools) shimmy_help_catalog_tools ;;
      verify) shimmy_help_catalog_verify ;;
      publish) shimmy_help_catalog_publish ;;
      rollback) shimmy_help_catalog_rollback ;;
      *) fail "unknown catalog help topic: ${2:-}" ;;
    esac
    ;;
  shim)
    case "${2:-}" in
      ''|help|-h|--help) shimmy_help_shim ;;
      list) shimmy_help_shim_list ;;
      add) shimmy_help_shim_add ;;
      remove) shimmy_help_shim_remove ;;
      set-version) shimmy_help_shim_set_version ;;
      sync) shimmy_help_shim_sync ;;
      test) shimmy_help_shim_test ;;
      *) fail "unknown shim help topic: ${2:-}" ;;
    esac
    ;;
  ai-skill)
    case "${2:-}" in
      ''|help|-h|--help) shimmy_help_ai_skill ;;
      list) shimmy_help_ai_skill_list ;;
      repair) shimmy_help_ai_skill_repair ;;
      *) fail "unknown AI-skill help topic: ${2:-}" ;;
    esac
    ;;
  *) fail "unknown help group: $shimmy_help_group" ;;
esac
