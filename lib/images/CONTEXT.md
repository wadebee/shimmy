# Catalog image verification

`images.sh` owns `tool|version` selection, image reference enumeration, remote
inspection caching, and jq-backed index parsing. It reads no implementation
names and has no standalone public command.

`catalog.sh` validates the active schema-2 profile and its retained immutable
default-catalog pin, resolves exact active-profile jq and Skopeo dependencies,
and implements `shimmy catalog verify`. Missing dependencies report an exact
versioned `shimmy shim add` remediation. Skopeo carries the active profile's
registry policy; verification does not mutate catalog or profile state.
