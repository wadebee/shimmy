# Command tests

- `agent-preflight.sh` proves source and schema-2 active-profile smoke discovery.
- `catalog.sh` covers local status/tools, clean-main publish/rollback, image
  verification, and catalog transaction boundaries.
- `shim.sh` covers tracking/pinning, direct runtime selection, concrete version
  roles, image preparation, manifest-last commit, skill reconciliation, rollback,
  and smoke status propagation.
- `ai-skill.sh` covers bundle list/repair, exact collision replacement,
  recognized stale-link cleanup, unrelated-name preservation, unsupported
  bundles, source mismatch, and compensation.
- `profile.sh` covers arbitrary-name list/status, active immediate and inactive source-only redirects, Linux
  and Darwin activation ordering, dry-run, bundle policy, workload guards,
  rollback, and sourced-shell retargeting.
- `surface.sh` proves complete root/group/subgroup/action help before state
  validation, independently verifies status and streams for bare launcher help
  nodes versus `--help`, and validates exact rendered launcher bytes.
- `lifecycle.sh` owns five independently scheduled, internally indivisible
  public acceptance scenarios: Darwin shared-engine bootstrap/collision; Linux
  bootstrap, initial default-profile inspection, and failed-bootstrap cleanup;
  owned isolated create/delete retry, true clone, and cross-engine activation;
  journaled global owned-engine uninstall/retry; and end-to-end default toolset,
  catalog/shim/profile/skill/network/startup,
  sibling isolation, sync/rollback, administration, deletion, uninstall, and
  unrelated-skill preservation. They copy one
  immutable session template into private Git checkouts and use only generated
  fake Podman state for engine transitions.

Command tests call public installed launchers for acceptance. Direct source
entrypoint calls are limited to focused parser/transaction seams.
