# Profiles

`profile.sh` resolves `default` and `upstream` profiles, their installation
paths, version-3 manifests, flat installation structure, and upstream source
validity. The canonical roots are
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>`; a non-empty
relative `XDG_CONFIG_HOME` is invalid. Installed launchers and dispatchers
derive identity from their enclosing canonical profile and never select a
sibling profile.
