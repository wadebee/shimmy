# Profiles

`profile.sh` resolves `default` and `upstream` profiles, their installation
paths, manifests, installation layout compatibility, and upstream source
validity. Stable commands dispatch to the selected profile; profile precedence
remains explicit argument, active environment, then `default`.
