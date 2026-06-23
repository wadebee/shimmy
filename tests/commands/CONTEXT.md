# Management-command test modules

These modules exercise the public command lifecycle using disposable install
roots. They are sourced by `../test.sh` and must not modify a user's Shimmy
installation or shell startup files.

## Files

- `lifecycle.sh` covers install, dispatch, status, update, and uninstall.
- `management.sh` covers activation, skills, and netinfo command behavior.
- `profiles.sh` covers profile precedence, profile-isolated uninstalls, status
  availability, and profile error guidance.
- `update.sh` covers selected-shim and all-profile refresh behavior, manifest
  preservation, and update request validation.
