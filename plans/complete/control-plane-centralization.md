### Shared control-plane feasibility assessment

The current installed default profile contains this control payload:

| Profile-local asset | Files | Logical bytes | Allocated size |
|---|---:|---:|---:|
| `commands/` | 13 | 106,836 | 132 KiB |
| `lib/` | 40 | 354,866 | 432 KiB |
| `tests/` | 40 | 357,807 | 452 KiB |
| **Total** | **93** | **819,509** | **1,016 KiB** |

For two profiles on the same control revision, one shared copy would therefore
avoid approximately 93 duplicate files and 1,016 KiB. Each additional profile
on that same revision adds the same theoretical saving. This is about 64 times
the current default profile's 16 KiB implementation-wrapper allocation, so it
is the materially larger deduplication opportunity.

That number overstates safely shareable code. Concrete runtimes directly load
profile-rooted libraries: `lib/runtime/` is used by the tool runtimes,
Skopeo additionally uses `lib/common/`, `lib/profile/`, and `lib/registries/`,
and the dispatcher uses the latter profile-validation boundary. Those four
directories total 152,351 logical bytes and 164 KiB allocated before counting
`dispatch-tool.sh` and `run-tool.sh`. Moving them to one shared root would mean
that damage, partial update, or removal of one shared control payload breaks
already-materialized tools in every profile. That is a larger capability loss
than the current plan requires.

A single mutable shared control plane is technically possible but is not
recommended because it would:

- make an update initiated through one profile silently replace management
  behavior for every sibling profile;
- eliminate independent default/upstream control revisions and invalidate
  existing source-ref/status attribution;
- turn control corruption or an interrupted shared update into a multi-profile
  outage;
- require a global control lock and cross-profile compatibility validation for
  every install, update, uninstall, and future schema transition;
- make last-profile and global uninstall responsible for distinguishing shared
  control ownership from unrelated root state; and
- overturn completed architectural decisions and pending custom-profile work
  that rely on profile-local launchers and mutation boundaries.

The safer central design is a content-addressed store such as:

```text
shimmy/
  control/
    generations/<content-identity>/
      control.conf
      commands/
      lib/
      tests/
  profiles/<profile>/
    install-manifest.txt   # explicit control_generation=<content-identity>
    bin/                   # profile-bound launcher/dispatcher surface
    lib/runtime/...        # minimum independent runtime plane
    tools/...              # selected materialized runtimes
```

Profiles on the same generation can share bytes without sharing a mutable
binding; updating one profile publishes a new immutable generation and changes
only that profile's manifest. This preserves revision isolation but introduces
a new shared schema, fingerprinting, generation publication, profile binding,
reference validation, locking, garbage collection, rollback, and global
uninstall lifecycle. It also requires a deliberate definition of which
libraries remain in the independent runtime plane. Those concerns are larger
than the implementation-adapter refactor and must not be smuggled into its
manifest-v4 change.

Decision: retain profile-local control planes in this plan. If central control
deduplication becomes an objective, create a separate `plan-review-act` plan
that supersedes the relevant decisions in
`plans/catalog-profile-separation.md` and
`plans/profile-name-activation.md`. The later plan should compare immutable
generation sharing against the lower-risk alternative of pruning the installed
test payload and other non-runtime files while leaving each profile independent.