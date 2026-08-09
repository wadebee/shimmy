# Management-command test modules

These modules exercise the public command lifecycle using disposable install
XDG configuration homes. They are sourced by `../test.sh` and must not modify
a user's Shimmy installation or shell startup files.

## Files

- `lifecycle.sh` covers install, dispatch, status, update, and uninstall.
- `onboarding.sh` covers sourced and executed repository onboarding, failure
  cleanup, the fixed jq/rg bootstrap baseline, explicit additive installed
  selection, direct shell initialization, PATH precedence, and profile-local
  launcher binding.
- `status.sh` covers profile-local installed and available status output from
  validated version-owned image configuration.
- `management.sh` covers the installed command surface, skills, and netinfo
  behavior.
- `profiles.sh` covers profile precedence, profile-isolated uninstalls, status
  availability and version-owned image descriptions, and profile error
  guidance.
- `update.sh` covers selected-shim and all-profile refresh behavior, version-
  local irrelevant image-refresh actions, manifest-preserving self-update for
  non-baseline kinds and concrete versions, and update request validation.
- `startup.sh` covers shell-initialization idempotence and managed startup-block
  install and repair behavior without a separate initialization command.
- `skills.sh` covers canonical skill sources, checked-in export fingerprints,
  portable manifests, installed-kind selection, explicit repository, home, and
  plugin targets, unconditional profile payload, lifecycle isolation, refresh,
  and manifest-tracked cleanup.
- `dispatcher.sh` covers profile-bound installed dispatchers, ownership, and
  recursion protections; repository previews use `commands/run-tool.sh`.
- `netinfo.sh` covers deterministic CIDR rendering, explicit host-LAN
  precedence, help output, and request validation.
- `install.sh` covers additive installed-kind requests, uninstall request
  validation, and macOS Podman guidance.
- `test.sh` covers installed-profile test request, metadata validation,
  profile binding, public dispatch, and concrete-version orchestration with
  disposable wrapper fixtures rather than live containers.
- `agent-preflight.sh` covers image-metadata-driven approval smoke commands and
  local-build preview selection without requiring a live Podman engine.
