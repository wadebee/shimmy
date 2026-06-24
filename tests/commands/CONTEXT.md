# Management-command test modules

These modules exercise the public command lifecycle using disposable install
roots. They are sourced by `../test.sh` and must not modify a user's Shimmy
installation or shell startup files.

## Files

- `lifecycle.sh` covers install, dispatch, status, update, and uninstall.
- `management.sh` covers activation, skills, and netinfo command behavior.
- `profiles.sh` covers profile precedence, profile-isolated uninstalls, status
  availability and version-owned image descriptions, and profile error
  guidance.
- `update.sh` covers selected-shim and all-profile refresh behavior, version-
  local irrelevant image-refresh actions, manifest preservation, and update
  request validation.
- `startup.sh` covers activation idempotence and managed startup-block install
  and repair behavior.
- `skills.sh` covers canonical skill sources, portable manifests, exported
  folders, installed-kind selection, refresh, and manifest-tracked cleanup.
- `dispatcher.sh` covers source dispatcher validation and installed dispatcher
  profile and recursion protections.
- `netinfo.sh` covers deterministic CIDR rendering, explicit host-LAN
  precedence, help output, and request validation.
- `install.sh` covers additive installed-kind requests, uninstall request
  validation, and macOS Podman guidance.
- `test.sh` covers installed-profile test request, metadata validation,
  profile selection, public-dispatch, and concrete-version orchestration with
  disposable wrapper fixtures rather than live containers.
- `agent-preflight.sh` covers metadata-driven approval smoke commands without
  requiring a live Podman engine.
