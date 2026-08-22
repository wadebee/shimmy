# Tool grouping exploration
**Status:** not started

## Status

Product brainstorming. This plan defines the concept space and a recommended
direction. It does not specify final shell helper names, exact file formats, or
implementation sequencing.

## Context

Shimmy currently models tools as:

- **Tool**: the stable user-facing command, such as `jq`, `rg`, `oc`, or
  `terraform`.
- **Version**: the concrete implementation selected by a tool, such as
  `oc_4_20`.

Grouping should sit above tools. It should select multiple existing tools for
management commands such as install, update, status, and test. It should not
change runtime dispatch, version resolution, image behavior, or the small
POSIX-shell runtime shim model.

Example target commands:

```sh
shimmy install --family networking
shimmy test --family cloud
```

## Goals

- Let users install or test related tools with one command.
- Keep the existing tool/version model intact.
- Support tools that naturally belong to more than one domain.
- Keep group names stable, documented, and discoverable.
- Avoid hiding high-risk or change-capable tools inside broad defaults.
- Keep catalog metadata POSIX-shell-friendly.

## Non-goals

- Do not create a package manager dependency solver.
- Do not add language runtimes, YAML, JSON, or database-backed metadata.
- Do not add runtime grouping behavior to individual tool shims.
- Do not pin versions through families in the first pass.
- Do not make `shimmy install` install every member of a broad family by
  default.

## Terminology Options

### Family

Best candidate for the user-facing term.

Pros:

- Fits the earlier reserved meaning: organizational grouping above tool tools.
- Reads well in commands: `--family networking`.
- Implies related tools without implying a vendor bundle or strict taxonomy.
- Can support many-to-many membership without sounding wrong.

Cons:

- Slightly informal.
- Needs clear documentation that a family selects tool tools, not concrete
  versions.

### Group

Acceptable internal concept, weaker as user-facing command language.

Pros:

- Generic and easy to understand.
- Common enough for filtering and selection.

Cons:

- Too broad: could mean Unix group, permission group, profile group, or command
  grouping.
- `--grouping` is awkward command language.

### Suite

Useful later for a stronger curated bundle.

Pros:

- Implies an intentionally curated set.
- Works for opinionated bundles such as a future `homelab-suite` or
  `platform-engineering-suite`.

Cons:

- Too strong for lightweight metadata grouping.
- Suggests the tools are installed and versioned as a unit.
- Poor fit for simple domain selectors like `networking`.

### Category

Better for documentation than command behavior.

Pros:

- Familiar for browsing and status output.

Cons:

- Implies a single primary bucket.
- Encourages a brittle taxonomy where every tool needs one "right" category.

### Tag Or Label

Best candidate for the metadata mechanism.

Pros:

- Naturally supports many-to-many membership.
- Scales as tools are added.
- Fits tools such as `nmap`, `skopeo`, `terraform`, and `jq` that cross
  domains.

Cons:

- Too implementation-oriented for primary user commands.
- Needs validation to prevent near-duplicates such as `dev`, `development`,
  and `developer-tools`.

## Recommended Product Model

Use **family** as the supported user-facing selector and **labels** as the
catalog mechanism.

In product terms:

- A family is a documented, supported label.
- A tool tool may belong to many families.
- `shimmy install --family <name>` expands to the current default version of
  every tool in that family.
- Multiple requested families form a union and deduplicate tools.
- Families are selection-time convenience, not a persistent subscription.

This gives users a stable command surface while avoiding the false precision of
a one-family-per-tool taxonomy.

## One-To-One Family Mapping

This model gives every tool exactly one family.

Example:

```text
aws -> cloud
nmap -> networking
jq -> parsers
```

Pros:

- Simple metadata.
- Easy browsing and table rendering.
- Easy validation because every tool has one family.

Cons:

- Forces arbitrary choices. `nmap` is networking, security, and diagnostics.
- Makes some families incomplete unless tools are duplicated.
- Creates churn when a tool's "best" family changes.
- Does not match how users assemble workflows.
- Makes command behavior misleading. A user asking for `security` would likely
  expect `nmap`, but a one-to-one model may have already assigned it to
  `networking`.

This is not a good fit for Shimmy beyond maybe a display-only primary category.

## Many-To-Many Labels

This model lets each tool tool declare several supported family labels.

Example:

```text
nmap -> networking, security, diagnostics
jq -> parsers, development, automation
skopeo -> containers, security
terraform -> infrastructure, cloud, automation
```

Pros:

- Matches real tool usage.
- Adds future tools without taxonomy rewrites.
- Supports narrow and broad user intents.
- Keeps `install --family`, `test --family`, and `status --family` as simple
  selectors over existing tools.

Cons:

- Needs a controlled vocabulary.
- Broad families can become unexpectedly large.
- Membership changes can surprise users if they rerun an install later.
- Requires careful handling for risky tools, especially admin-capable tools.

This is the preferred direction, with a small registry of supported family
names and descriptions to prevent drift.

## Candidate Families

Initial family names should be lowercase kebab-case, stable, and documented.

| Family | Purpose | Current likely members | Future likely members |
|---|---|---|---|
| `development` | General software development workflow tools | `go`, `gh`, `rg`, `jq`, `task`, `textual`, `tessl` | `node`, `python`, `maven`, `gradle`, `fd`, `fzf` |
| `parsers` | Structured data and text processing | `jq` | `yq`, `xq`, `dasel`, `fx` |
| `search` | Repository and filesystem search | `rg` | `fd`, `ripgrep-all`, `fzf` |
| `automation` | Repeatable local or remote task execution | `task`, `gh`, `gdrive`, `jq`, `terraform` | `just`, `ansible`, `make`, `act` |
| `cloud` | Public cloud provider CLIs and cloud-adjacent tools | `aws`, `gcloud`, `gdrive`, `terraform` | `az`, `doctl`, `flyctl`, `pulumi` |
| `infrastructure` | Infrastructure provisioning and platform operations | `terraform`, `aws`, `gcloud`, `oc`, `skopeo` | `opentofu`, `packer`, `pulumi`, `vault` |
| `containers` | Container image, registry, and platform tooling | `skopeo`, `oc` | `crane`, `oras`, `helm`, `kubectl`, `buildah` |
| `kubernetes` | Kubernetes and OpenShift workflows | `oc`, `gcloud` | `kubectl`, `helm`, `kustomize`, `stern`, `kind` |
| `networking` | Network discovery, diagnostics, and network system access | `netcat`, `nmap`, `opnsense-mcp-read-only` | `curl`, `dig`, `mtr`, `iperf3`, `tcpdump` |
| `security` | Security inspection, auditing, and policy workflows | `nmap`, `skopeo`, `opnsense-mcp-read-only` | `trivy`, `grype`, `cosign`, `sops`, `age` |
| `homelab` | Home lab operations and local infrastructure | `nmap`, `netcat`, `opnsense-mcp-read-only`, `task` | `tailscale`, `restic`, `rclone`, `dnscontrol` |
| `mcp` | Model Context Protocol servers and agent-facing tools | `opnsense-mcp-read-only`, `opnsense-mcp-admin`, `gdrive` | additional MCP server shims |
| `admin` | Change-capable administrative tools | `opnsense-mcp-admin` | other write-capable admin MCP tools |

`admin` should be explicit. Do not include change-capable tools in broad
families by accident. For example, `opnsense-mcp-read-only` can be in
`networking`, `security`, `homelab`, and `mcp`; `opnsense-mcp-admin` should
require an explicit family such as `admin` or `mcp-admin` if it is grouped at
all.

## Command Behavior

Proposed first-pass command language:

```sh
shimmy install --family networking
shimmy install --family cloud --family security
shimmy test --family development
shimmy status --available --families
shimmy status --available --family networking
```

Rules:

- `--family` is repeatable.
- `--family` may be combined with `--shim`; the final tool set is the union.
- Unknown families fail and print available families.
- Empty families fail in tests.
- Installed duplicate tool/version entries are deduplicated through the
  existing tool resolver.
- Family install uses each tool's default version.
- Family install should not persist a subscription to future family membership.

Avoid in the first pass:

- `shimmy uninstall --family ...`, because destructive group operations need
  stronger UX and probably a preview mode.
- Family version pins, because that turns families into release bundles.
- Arbitrary user-defined groups, because that is a different feature from
  supported Shimmy families.

## Manifest And Status

The profile manifest should continue to record installed `tool=` and
`tool_version=` entries as the source of truth. A family install is just a
convenient way to select those entries.

Open product choice:

- Do not record family origin initially. This keeps installs deterministic and
  avoids stale family-subscription semantics.
- Consider optional informational fields later, such as
  `install_request_family=networking`, only if status output needs to explain
  why a tool was installed.

Status should expose family metadata independently:

```text
available_families:
- networking: netcat, nmap, opnsense-mcp-read-only
- cloud: aws, gcloud, gdrive, terraform
```

Manifest-format status could eventually emit shell-readable lines such as:

```text
shimmy_available_family=networking
shimmy_available_family_tool=networking|nmap
```

## High-Level Implementation Shape

Likely affected surfaces:

- Tool metadata: add family labels to `tools/<tool>/tool.conf` or an adjacent
  catalog-owned metadata file.
- Catalog helpers: list supported families and resolve family names to tools.
- Install request parsing: accept repeatable `--family <name>` and merge with
  `--shim` requests.
- Test selection: accept `--family <name>` and expand to tool tests.
- Status: show available families and family membership.
- Documentation: README, contributing guidance, testing docs, and relevant
  agent skills.
- Tests: metadata validation, family expansion, unsupported family errors,
  install deduplication, and status rendering.

No runtime tool shim should need to change.

## Pitfalls

- **Broad family surprise**: `cloud` or `development` can grow large and pull or
  build more images than users expect. Mitigate with status visibility and, in a
  later phase, a dry-run or preview.
- **Admin-capable tools**: Broad families must not silently install tools that
  expose write-capable infrastructure or firewall operations.
- **Naming drift**: Without a registry, labels will diverge. Use documented
  supported family names, not free-form labels.
- **Membership churn**: If a family changes, rerunning install may install new
  tools. Treat family install as selection-time expansion and document that
  behavior.
- **Overlapping families**: Overlap is expected. Deduplication must happen
  before install/test execution.
- **Default family confusion**: The existing default install set should remain
  separate from families. `jq` and `rg` being default tools does not mean there
  is a special `default` family.
- **Version expectations**: A family should install the default version for each
  tool. Users who need a non-default version should still request
  `--shim tool@version`.
- **Unsupported local context**: Some tools need credentials, config mounts, or
  live Podman images. Family install should not mask normal tool-specific
  warnings or smoke failures.

## Open Questions

- Should `shimmy test --family <name>` in an installed profile require every
  family member to be installed, or test only installed members and report
  skipped ones?
- Should family metadata live in each `tool.conf`, or should a central
  family registry map families to tools?
- Should `admin` be a supported family, or should risky tools stay out of
  family selection until explicit warning UX exists?
- Is `mcp` useful as a top-level user family, or should MCP tools be grouped by
  domain such as `networking` and `cloud` only?
- Should future user-defined groups be called `collections` to keep them
  distinct from supported Shimmy families?

## Recommended First Increment

1. Adopt `family` as the user-facing term.
2. Use many-to-many labels, validated against a documented supported family
   list.
3. Add `install --family`, `test --family`, and available-family status output.
4. Keep uninstall, version-pinned suites, and user-defined collections out of
   the first increment.
5. Treat family installs as expansion to existing tool/default-version requests,
   with no runtime shim changes.

## Acceptance Criteria

- A supported family can be listed and inspected before install.
- A tool tool can belong to more than one family.
- `shimmy install --family networking` installs the default versions of all
  selected networking tools.
- `shimmy install --family cloud --shim jq` merges and deduplicates selected
  tools.
- `shimmy test --family development` expands to the relevant tool tests.
- Unknown family names fail with a list of available families.
- Broad families do not silently include admin-capable tools unless the family
  name makes that risk explicit.
- Existing `--shim <tool>[@<version>]` behavior remains unchanged.
