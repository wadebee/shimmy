# Profiles

`profile.sh` resolves `default` and `upstream` profiles, their installation
paths, version-2 manifests, materialized installation structure, and upstream
source validity. The canonical roots are
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>`; a non-empty
relative `XDG_CONFIG_HOME` is invalid. Installed launchers and dispatchers
derive identity from their enclosing canonical profile and never select a
sibling profile. Each manifest must bind `default` to the shared `default`
catalog or `upstream` to the shared `upstream` catalog; missing, mismatched,
duplicate, or unsafe bindings reject the profile before mutation. Shell
selection is performed by sourcing that profile's generated `shell-init.sh`.
A valid current profile has no `plugins/` or retired `agent/` directory. Its
`tools/`, `implementations/`, and shim configuration contain exactly the tools
and concrete versions recorded by the manifest; canonical skills and
unselected catalog entries are invalid mixed-layout payload.

`activation.sh` owns deterministic engine discovery, read-only status,
workload-guarded Darwin transitions, commit-last default selection, rollback
reporting, and local-rootless Linux validation. Only `shimmy profile activate`
uses its machine start/stop operations; it never provisions or removes a VM.
