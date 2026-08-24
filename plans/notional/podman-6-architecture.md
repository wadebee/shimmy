# Podman 6 Capability Assessment for Shimmy

## Objective

Produce an evidence-backed architectural assessment of Podman 6.0 through
6.1 for Shimmy, with particular attention to macOS. Establish how Shimmy can
adopt useful Podman 6 capabilities on Apple Silicon while continuing to support
Intel Mac users on a Podman version that still supports that host.

The deliverable is a decision memo and a prospective implementation approach,
not code. Success means the assessment separates confirmed upstream behavior,
current Shimmy behavior, capability-specific benefits, compatibility risks, and
the decisions required before implementation. The plan does not authorize
changes to runtime shims, engine lifecycle, supported-host policy, tests,
documentation, or installed users' Podman state.

## Target layout and terminology

Shimmy should model support as independent host and Podman capability lanes,
not one global Podman-version requirement:

| Lane | Host | Podman range | Intended Shimmy posture |
| --- | --- | --- | --- |
| Intel macOS | Darwin `amd64` | Podman 5.x | Retain the existing supported machine lifecycle. Podman 6 is unavailable upstream on this host. |
| Apple Silicon macOS | Darwin `arm64` | Podman 5.x and 6.x | Preserve existing machines; evaluate each Podman 6 machine capability independently. |
| Linux | `amd64` and `arm64` | Current rootless Podman, including 6.x | Retain the host-local rootless model; assess 6.x network/config migration effects separately. |

A **capability gate** is a narrow runtime decision based on a verified Podman
feature rather than a broad version assumption. Candidate examples are support
for `machine start --update-connection`, cross-provider machine inspection,
and the host configuration mount in newly created machines.

## Recorded design decisions

1. This is research and assessment only. No source code, tests, docs, user
   state, Podman machine, or support policy will change during this plan.
2. Intel Mac users remain in scope for Shimmy. Podman 6's removal of Intel Mac
   support is a Podman upgrade limitation, not authorization to remove Shimmy
   support.
3. Do not establish a global Podman 6 minimum. New behavior must be adopted by
   independently justified capability gates that preserve a safe existing path
   where the capability is absent.
4. Retain Shimmy's current authority model as the evaluation baseline:
   `lib/profile/activation.sh` owns active engine/default connection changes;
   profile policy remains authoritative; foreign machines are never adopted;
   and explicit trust/privilege opt-ins stay explicit.
5. A future implementation must not replace the current registry projection
   merely because Podman 6 mounts host configuration into a machine. It needs
   native evidence for precedence, same-path visibility, service-reload, and
   rollback behavior first.

## Verified implementation inventory

- The local host currently runs Podman `5.8.1`.
- `lib/engine/podman.sh` already parses the machine provider from `machine
  list`, records it in machine identity, and uses provider-neutral machine
  inspection. Its starts are currently `podman machine start <name>`.
- `lib/profile/activation.sh` is the sole active-engine authority. It stages
  registry policy, protects running workloads, validates target state, and
  explicitly commits the default connection last with rollback.
- The current design deliberately uses the upstream-selected machine provider;
  it does not hardcode AppleHV or libkrun. This is compatible with Podman 6's
  provider-agnostic machine operations.
- Darwin registry policy uses a rootless guest-user drop-in targeting a
  host-mounted engine projection. A changed effective policy recycles only the
  rootless API service, not the VM or its workloads.
- Shimmy's tool model is short-lived `podman run`, not long-lived service or
  workload orchestration. Quadlet, artifacts, GPU selection, and `exec
  --no-session` therefore have no demonstrated product fit.

## Upstream capability assessment

| Capability | Potential alignment with Shimmy | Benefits | Costs and risks | Assessment position |
| --- | --- | --- | --- | --- |
| `machine start --update-connection` | Reinforces Shimmy's noninteractive activation. Pass `false` so Shimmy retains commit-last default-connection selection. | Removes prompts and avoids an accidental early default-connection change. | Requires exact feature detection and tests across a 5.x/6.x matrix. | Strong candidate. |
| Cross-provider machine commands and `init --provider` | Matches Shimmy's named-machine ownership and observed-provider record. | AppleHV and libkrun inventories can coexist without manipulating Podman's global provider selection. | Pinning a provider would add policy/upgrade responsibility without a stated user need. | Keep provider-neutral; validate. |
| libkrun becomes the macOS default | Affects newly created Apple Silicon Podman 6 machines. | Upstream-selected provider becomes the normal path; no Shimmy redesign required. | Podman 6.0.1 fixed a libkrun shutdown issue; acceptance must cover 6.1+ as well as existing AppleHV machines. | Validate; do not hardcode. |
| Host configuration mount at `/etc/containers` | Could simplify the current guest projection path. | Potentially fewer guest-side mutations and less SSH dependence. | Rootless-user precedence, paths outside `$HOME`, cached config, rollback, and existing-machine behavior are unknown. | Research candidate; do not replace current projection yet. |
| `init/set --import-native-ca` | Could improve corporate registry access. | VM trusts organization CA roots after boot. | Silently broadens trust and conflicts with Shimmy's explicit trust/credential policy. | Defer unless an explicit opt-in trust design is approved. |
| `machine os update` and 6.1 `machine restart` | Could provide maintained owned-machine lifecycle. | Explicit upgrade/recovery primitives. | OS update is stateful and rollback/destructive semantics are not covered by current ownership journals; restart must retain workload guards. | Defer to a separate engine-maintenance design. |
| Netavark/Pasta, cgroup v2, nftables, config-parser changes, network isolation default | Directly affect rootless networking and configuration behavior used by all wrapper containers. | Aligns with supported Podman 6 architecture and security defaults. | Existing Linux machines/hosts may need migration; network-tool privileged routes need native validation. | Required compatibility research before supporting 6.x broadly. |
| Intel Mac removal | Defines the boundary between host support and Podman feature availability. | Keeps the decision honest: Intel users can retain a supported Shimmy path. | Two Podman capability lanes require ongoing matrix coverage. | Retain Shimmy support; document Podman 6 unavailable. |

Upstream references: [Podman v6.0.0](https://github.com/podman-container-tools/podman/releases/tag/v6.0.0), [v6.0.1](https://github.com/podman-container-tools/podman/releases/tag/v6.0.1), and [v6.1.0](https://github.com/podman-container-tools/podman/releases/tag/v6.1.0). The supplied VersionLog page is a secondary index; conclusions above rely on the upstream releases and local source inspection.

## Prospective implementation approach

If implementation is later approved, use four bounded, review-gated changes:

1. **Capability inventory and safe start wrapper.** Add a strict Podman
   capability probe behind the existing engine command seam. Use it only to
   choose the `machine start --update-connection=false` form when supported;
   retain the current invocation otherwise. Prove both paths preserve Shimmy's
   explicit default-connection commit and rollback sequence.
2. **Provider-neutral macOS acceptance.** Add Apple Silicon live acceptance on
   Podman 6.1+ for both an existing AppleHV machine where present and a newly
   created libkrun machine. Keep provider observation/ownership evidence as it
   is; do not add an automatic provider migration or hardcoded selector.
3. **Configuration-mount research spike.** In a disposable configuration and
   machine, test `/etc/containers` against the current rootless-user drop-in:
   precedence, XDG paths outside `$HOME`, API-service cache/recycle, rollback,
   and stopped/existing machine behavior. Bring the evidence back for review
   before proposing a projection redesign.
4. **Document and validate the capability matrix.** Add only opt-in native
   acceptance to the default-offline suite: Intel macOS/Podman 5 where
   available, Apple Silicon Podman 5 and 6.1+, and Linux Podman 6 rootless
   networking. Document host prerequisites and unsupported migration paths;
   do not make Shimmy install, update, or recreate Podman machines.

This approach keeps the cost of compatibility proportional: the shared
activation architecture stays stable, only a small start-wrapper branch is
introduced, and the higher-risk configuration change remains evidence-led.

## Unresolved

None for the assessment. Any implementation proposal must return with native
evidence for the configuration-mount question and an explicit test-matrix
maintenance commitment.

## Progress Checklist

- [x] Inventory current Shimmy lifecycle, provider, and registry-projection boundaries.
- [x] Review authoritative Podman 6.0, 6.0.1, and 6.1.0 release material.
- [x] Define the Intel macOS, Apple Silicon macOS, and Linux capability lanes.
- [x] Produce a prospective implementation approach without authorizing it.

## Risk register

- **Feature-detection drift:** capability checks can become another hidden
  compatibility layer. Mitigation: keep probes narrowly scoped, testable via
  the existing command seam, and limited to directly used upstream controls.
- **Provider behavior:** libkrun's new-default status can expose lifecycle
  assumptions not seen with AppleHV. Mitigation: provider-neutral code plus
  separate native acceptance.
- **Configuration precedence:** host mounts may not supersede the existing
  rootless-user configuration. Mitigation: no projection change without a
  disposable native spike and review.
- **Support-matrix cost:** retaining Intel support requires a Podman-5 macOS
  lane. Mitigation: confine divergence to capability gates rather than fork
  Shimmy's lifecycle architecture.
- **Trust expansion:** CA import can change which registries a VM trusts.
  Mitigation: retain explicit opt-in policy and defer the feature.

## Lessons learned

### Initial

- Podman 6's macOS changes do not require a single support cutoff: Intel Mac
  support and Apple Silicon Podman 6 capability adoption are separable.
- Shimmy's existing observed-provider record and commit-last connection model
  are well positioned to use the most relevant Podman 6 machine improvements.
- The config mount is the highest-potential simplification and the highest
  uncertainty; it should be measured before it is designed into the control
  plane.

## Session bootstrap

This assessment is complete and does not authorize ACT. A future implementation
session must first obtain explicit approval, move this plan to `plans/wip/`,
re-read repository guidance and every relevant child context, then execute only
the approved prospective step. Preserve Intel macOS support, provider-neutral
ownership, explicit trust/privilege controls, and `lib/profile/activation.sh`
as the sole active-engine authority.
