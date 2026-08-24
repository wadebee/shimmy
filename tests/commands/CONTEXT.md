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
- `lifecycle.sh` is the public end-to-end acceptance world: shared-engine bootstrap/collision, owned isolated create/delete retry, true clone, cross-engine activation, explicit migration/rollback, journaled global owned-engine uninstall/retry, active-engine-last ordering, reused-name collision safety, and external/mismatched preservation,
  jq/rg/Skopeo inventory, catalog/shim/profile/skill/network/startup flows,
  sibling isolation, sync/rollback, admin status, deletion, global uninstall,
  unrelated home-skill preservation, complete failed-bootstrap cleanup, and
  retained shared-machine recovery evidence after incomplete rollback.

Command tests call public installed launchers for acceptance. Direct source
entrypoint calls are limited to focused parser/transaction seams.
