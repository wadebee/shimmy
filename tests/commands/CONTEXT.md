# Management-command test modules

These modules exercise the public command lifecycle using disposable install
XDG configuration homes. They are sourced by `../test.sh` and must not modify
a user's Shimmy installation or shell startup files. Large checkout, catalog,
profile, and source-tree fixtures use the boundary-checked copy helper from
`../support.sh`; small direct copies remain local when duplication or mutation
is the behavior under test.

## Files

- `catalog.sh` covers complete deterministic named-catalog listing, list input
  validation and non-mutation, exact schema rejection, live-checkout
  registration and explicit rebind, immediate dirty upstream visibility,
  clean committed publication, immutable provenance, ignored-content
  exclusion, and retained rollback generation state, atomic rollback,
  invalid-current recovery, integrity rejection, explicit catalog-default
  profile update, and final checkout-HEAD rechecking.
- `images.sh` covers source and installed selection, fixture-driven OCI/Docker
  parsing, request deduplication, authentication skips/failures, drift policy,
  stable output, and command availability without target-registry access.
- `image-fixtures/` owns committed raw manifest responses for those tests. Its
  retained context is [image-fixtures/CONTEXT.md](image-fixtures/CONTEXT.md).
- `lifecycle.sh` covers install, selected-only materialization, catalog-loss
  execution, installed control-plane refresh boundaries, dispatch, status,
  update, rollback, profile-only uninstall, and explicit global uninstall. Its
  layout, launcher-refresh, isolation, and profile-removal cases clone their
  initial profiles while retaining real refresh, additive-install, and
  uninstall operations. Registry lifecycle cases preserve valid Darwin
  projection-record bytes across update and require detach before profile or
  global uninstall.
- `onboarding.sh` covers sourced and executed repository onboarding, failure
  cleanup, the fixed jq/rg bootstrap baseline, explicit additive installed
  selection, direct shell initialization, PATH precedence, and profile-local
  launcher binding. Its selection-policy case uses the session's real
  bootstrap fixtures for initial default/upstream baselines while retaining an
  isolated rejected request and a real default refresh after additive install;
  shell-initialization PATH behavior also runs against relocated clones.
- `status.sh` covers profile-local installed status output from validated
  version-owned image configuration. It starts from pristine profile clones
  and retains a real additive install for local-build status coverage.
- `management.sh` covers the installed command surface, complete second- and
  third-level help discovery, action guidance before validation, profile
  binding, skills, and netinfo behavior.
- `profiles.sh` covers profile precedence, profile-isolated uninstalls, status
  identity and version-owned image descriptions, and profile error
  guidance. Its identity, malformed-manifest, invalid-upstream-checkout,
  partial-profile, and independent shell-init damage cases start from pristine
  profile clones while retaining real invalid-XDG and bootstrap
  repair-rejection checks.
- `profile.sh` covers profile command help and rejection, installed control
  materialization, read-only state, deterministic profile identity, and
  override redaction through the fake Podman seam. It also covers strict
  redirect CRUD, Linux link activation/current status, active-edit rollback,
  inactive edits, detach, Darwin active-edit restart guidance, projection
  freshness status, exact/stopped/missing/foreign detach behavior, rejected
  aliases/options, and profile isolation.
- `update.sh` covers selected-shim and all-profile refresh behavior, version-
  local irrelevant image-refresh actions, manifest-preserving self-update for
  non-baseline tools and concrete versions, and update request validation. Its
  self-update scenario starts from session-scoped pristine profile clones so
  it measures update behavior without repeating repository bootstraps.
- `startup.sh` covers automatic zsh and Bash bootstrap integration,
  shell-initialization idempotence, and managed startup-block install and
  repair behavior without a separate initialization command. Its
  upstream-isolation case clones upstream while retaining the real default
  startup installation.
- `skills.sh` covers split catalog-owned canonical skill sources, checked-in
  adapter fingerprints, one-file repository/home and portable exports,
  profile-local activation/workload/provisioning guidance in refreshed exports,
  Skopeo registry-policy readiness and strict OC redirect guidance,
  management plugin discovery, installed-tool selection, absence of canonical
  skill sources from profile payloads, live-upstream versus published-default
  visibility, coherent staged target replacement, catalog failure boundaries,
  lifecycle isolation, refresh, and manifest-tracked cleanup. Its
  target-ownership lifecycle, catalog-authority cases, and retryable
  external-target failure start from pristine profile clones.
- `dispatcher.sh` covers profile-bound installed dispatchers, ownership, and
  recursion protections using isolated pristine clones for destructive cases;
  repository previews use `commands/run-tool.sh`.
- `netinfo.sh` covers deterministic CIDR rendering, explicit host-LAN
  precedence, help output, and request validation.
- `install.sh` covers additive installed-tool requests, uninstall request
  validation, and macOS Podman guidance.
- `test.sh` covers installed-profile test request, metadata validation,
  profile binding, public dispatch, and concrete-version orchestration. Its
  installed profile-binding scenario starts from a pristine clone; runtime
  orchestration uses disposable wrapper fixtures rather than live containers,
  including a failing smoke that must propagate its nonzero status.
- `agent-preflight.sh` covers image-metadata-driven approval smoke commands and
  local-build preview selection without requiring a live Podman engine.
