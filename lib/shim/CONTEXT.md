# Profile-local shim state

`state.sh` owns the private target schema for profile manifest `shim` and
`shim_version` records. It validates lexical uniqueness, two-field
tracking/pinned policy, exactly one authoritative default version per shim,
duplicate-free non-default exact versions, and tool ownership.

`target.sh` owns the private target shim lifecycle. It resolves the invoking
profile and its retained immutable catalog pin; reads remain bound to that
launcher even when a sibling is active, while mutation requires invoking and
active identity to match before image work. It applies first-default and
tracking/pinned role transitions, stages direct `<tool>|<version>` runtimes,
generated launchers/config, and a typed shim-bundle input, prepares images
before locking, regenerates the deterministic shims AI-skill bundle, then
commits shim-owned assets with the manifest last and reconciles exact user
links under activation/profile locks. Internal state and compensable Shimmy
links roll back together; overwritten foreign content is reported as
unrecoverable. It also selects non-mutating all/tool/version smokes and
propagates runtime status unchanged. Current public commands do not source it.
