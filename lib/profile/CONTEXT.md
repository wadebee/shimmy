# Profiles

`profile.sh` resolves `default` and `upstream` profiles, their installation
paths, version-1 manifests, materialized installation structure, and upstream
source validity. A valid source checkout requires executable root
`bootstrap.sh`, the control, library, and tool trees, and the launcher
template. The canonical profile roots are
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>`; a non-empty
relative `XDG_CONFIG_HOME` is invalid. Installed launchers and dispatchers
derive identity from their enclosing canonical profile and never select a
sibling profile. Each manifest must bind `default` to the shared `default`
catalog or `upstream` to the shared `upstream` catalog; missing, mismatched,
duplicate, or unsafe bindings reject the profile before mutation. Shell
selection is performed by sourcing that profile's generated `shell-init.sh`.
A default manifest requires one normalized startup shell and permits unique
absolute `startup_file` ownership entries; zero entries is manual policy.
Upstream manifests forbid both startup fields.
A valid current profile has no `plugins/` or retired `agent/` directory. Its
`tools/` and shim configuration contain exactly the tools and concrete versions
recorded by the manifest; canonical skills and unselected catalog entries are
invalid mixed-layout payload.

`activation.sh` owns deterministic engine discovery, read-only status,
side-effect-free activation-state labels and conservative recommended actions,
workload-guarded Darwin transitions, commit-last default selection, rollback
reporting, Linux active-link plus fresh local-rootless validation, and Darwin
same-path registry projection before target engine validation. Darwin
activation records projected config freshness only after rootless remote
validation; stale running state requires explicit workload-guarded restart.
Uninstall reuses bounded start, stop, restart, validation, and restoration
primitives while holding the activation lock. Neither lifecycle provisions or
removes a VM.

Path resolution also records the authoritative profile-specific
`registries.conf`, adjacent transaction lock, exact Linux user drop-in, exact
Darwin VM link, and optional profile-local machine projection record. Current
profiles require the authoritative file to be a regular non-symlink with exact
profile/version markers; any retained projection record must have strict
identity, target, fingerprint, and mode. Only the installer may recognize an
absent registry file as the valid pre-feature upgrade shape.
