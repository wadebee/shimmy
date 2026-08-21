# Profile-local shim state

`state.sh` validates schema-2 `shim` and `shim_version` records: lexical
uniqueness, tracking/pinned policy, one default concrete version per tool, and
duplicate-free exact versions.

`shim.sh` resolves the invoking profile and its retained catalog pin. Reads stay
bound to that launcher; mutation requires invoking and active identity to match.
It stages direct `tool|version` runtimes, generated `bin/<tool>` launchers,
typed configuration, manifest-last state, and the deterministic tool-skill
bundle. Internal state and recognized links compensate together; overwritten
foreign skill content is irrecoverable. Smokes select all/tool/exact versions
from `smoke.conf` and propagate runtime status unchanged.
