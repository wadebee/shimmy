# Profile-local shim state

`state.sh` owns only the private target schema for profile manifest `shim` and
`shim_version` records. It validates lexical uniqueness, launcher membership,
tracking/default-slot relationships, exact-version coexistence, and tool
ownership without reading or mutating installed state.
