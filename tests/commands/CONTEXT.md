# Management-command test modules

These modules exercise the public command lifecycle using disposable install
XDG configuration homes. They are sourced by `../test.sh` and must not modify
a user's Shimmy installation or shell startup files.

## Files

- `images.sh` covers source and installed selection, fixture-driven OCI/Docker
  parsing, request deduplication, authentication skips/failures, drift policy,
  stable output, and command availability without target-registry access.
- `image-fixtures/` owns committed raw manifest responses for those tests. Its
  retained context is [image-fixtures/CONTEXT.md](image-fixtures/CONTEXT.md).
- `lifecycle.sh` covers install, dispatch, status, update, and uninstall. Its
  layout, launcher-refresh, and profile-removal cases clone their initial
  profiles while retaining real refresh, additive-install, and uninstall
  operations.
- `onboarding.sh` covers sourced and executed repository onboarding, failure
  cleanup, the fixed jq/rg bootstrap baseline, explicit additive installed
  selection, direct shell initialization, PATH precedence, and profile-local
  launcher binding. Its selection-policy case uses the session's real
  bootstrap fixtures for initial default/upstream baselines while retaining an
  isolated rejected request and a real default refresh after additive install;
  shell-initialization PATH behavior also runs against relocated clones.
- `status.sh` covers profile-local installed and available status output from
  validated version-owned image configuration. It starts from pristine profile
  clones and retains a real additive install for local-build status coverage.
- `management.sh` covers the installed command surface, skills, and netinfo
  behavior.
- `profiles.sh` covers profile precedence, profile-isolated uninstalls, status
  availability and version-owned image descriptions, and profile error
  guidance. Its identity, malformed-manifest, invalid-upstream-checkout,
  partial-profile, and independent shell-init damage cases start from pristine
  profile clones while retaining real invalid-XDG and bootstrap
  repair-rejection checks.
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
- `skills.sh` covers split canonical skill sources, checked-in adapter
  fingerprints, one-file repository/home and portable exports, management
  plugin discovery, installed-tool selection, unconditional profile payload,
  lifecycle isolation, refresh, and manifest-tracked cleanup. Its
  target-ownership lifecycle and retryable external-target failure start from
  pristine profile clones.
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
