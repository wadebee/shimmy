# Commands Context

`commands/` contains executable POSIX shell entrypoints. Installed profiles copy
only the command files needed by the final launcher surface plus source support
that profile operations require.

- `bootstrap.sh` is the checkout bootstrap implementation. It accepts only
  shell/startup policy, derives the config root from XDG/HOME, and creates and
  activates a fresh `default` installation.
- `help.sh` renders root, group, subgroup, and action help before installed-state
  validation. The launcher makes bare root, group, and `profile redirect`
  subgroup invocations exact successful equivalents of their `--help` forms;
  actions retain documented defaults and required inputs.
- `admin.sh` owns installation-wide status, read-only engine status, explicit
  engine migration, network inspection, and uninstall routing.
- `profile.sh` owns profile list/status/create/clone/activate/sync/startup
  repair/delete and strict redirect CRUD. Isolated creation and clone mode
  overrides route through the compensated installation lifecycle.
- `catalog.sh` owns local default-catalog inspection, remote image verification,
  clean-main publication, and retained rollback.
- `shim.sh` owns active invoking-profile shim and concrete-version lifecycle.
- `ai-skill.sh` owns active-profile bundle/link inspection and repair.
- `run-tool.sh` is a source checkout dispatcher, not an installed launcher group.
- `agent-preflight.sh` discovers schema-2 active/installed or source metadata and
  prints safe non-mutating approval smoke commands.

Engine migration installs no compatibility aliases: unbound schema-2 profiles
remain legacy until the explicit command validates the whole installation and
publishes all engine/binding state. Fresh bootstrap publishes the shared engine
as part of its compensated lifecycle.

Installed command handlers receive config-root and invoking-profile identity
only from their rendered launcher. They accept no public environment selector
for another installation or profile.

All mutating handlers must validate complete state before mutation, use the
appropriate catalog/activation/profile/registry lock order, and retain cleanup
traps through commit. Help paths must not require a valid manifest.

Exact user skill collisions are destructive by design: activation and repair
overwrite bundle-declared destinations without backup. Commands must preserve
unrelated names and must never recursively delete the user skill root.

No compatibility forwarding exists for removed management commands. Update
`commands/README.md`, root docs, tests, and installed asset lists whenever the
group grammar changes.
