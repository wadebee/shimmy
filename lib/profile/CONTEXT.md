# Profiles

`profile.sh` resolves `default` and `upstream` profiles, their installation
paths, version-4 manifests, flat installation structure, and upstream source
validity. The canonical roots are
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>`; a non-empty
relative `XDG_CONFIG_HOME` is invalid. Installed launchers and dispatchers
derive identity from their enclosing canonical profile and never select a
sibling profile. Shell selection is performed by sourcing that profile's
generated `shell-init.sh`. A valid current profile contains `plugins/` and
`tools/` but does not require the retired top-level `agent/` directory.
