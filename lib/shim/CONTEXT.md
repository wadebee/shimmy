# Profile-local shim state

`state.sh` owns only the private target schema for profile manifest `shim` and
`shim_version` records. It validates lexical uniqueness, two-field
tracking/pinned policy, exactly one authoritative default version per shim,
duplicate-free non-default exact versions, and tool ownership without reading
or mutating installed state.
