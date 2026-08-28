---
name: shimmy-tool-discover
description: Discover, compare, and select an external OCI implementation for a new Shimmy CLI tool, or determine that a local image build is required, then prepare a concise factual handoff for shimmy-create-tool.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# Shimmy Tool Discovery

Use this skill when the user wants to add a completely new CLI command to
Shimmy and needs to discover published OCI implementations before invoking
`shimmy-create-tool`.

## Goal

Research currently supported releases and external OCI implementations for one
CLI command, inspect candidates remotely, rank selectable candidates by an
explainable security-posture rubric, let the user select the release/image pair,
and produce only the factual implementation information useful to
`shimmy-create-tool`.

This skill is discovery-only. It does not create or modify a Shimmy tool,
catalog resource, profile, registry configuration, authentication state, or CLI
surface. It never pulls or runs a candidate image.

## Tool identity

- The requested CLI command is the Shimmy tool identity and carries forward as
  `tool_name`. Examples: `jq`, `terraform`, `flux`, `task`, `oc`.
- Research the authoritative upstream project, repository, documentation, and
  release lifecycle independently from the command name.
- If multiple credible projects expose the same command, stop before OCI
  research and ask the user which project they intend.
- Do not rename the tool from an upstream project, organization, package, image,
  or repository name.

## Release scope

Discover OCI implementations across the upstream project's currently supported
release set rather than selecting one release first.

Use authoritative upstream lifecycle or release documentation when available.
Include:

- the latest stable release;
- current LTS releases;
- other actively maintained release lines; and
- an explicitly requested prerelease channel.

Exclude historical or end-of-life releases unless the user asks for them. If
upstream publishes no lifecycle policy, infer the maintained set from current
release activity and label that inference clearly.

A registry tag that resembles a version is not proof of the contained tool
release. Corroborate release identity with upstream, publisher, OCI annotation,
image documentation, or equivalent credible evidence.

## Discovery sources

Discovery is open-ended and evidence-driven. Do not assume a fixed registry
universe.

For every supported release:

1. Inspect the effective Podman registry environment available to the user.
   - Treat ordered `unqualified-search-registries` entries as local preference
     evidence.
   - Treat explicit registry `prefix`, `location`, mirror, or replacement
     occurrences as additional local preference evidence.
   - Presence in Podman configuration is a local operator preference or
     reachability signal, not proof of registry security.
2. Research authoritative upstream sources:
   - official documentation;
   - source repository;
   - release documentation;
   - container/package documentation; and
   - CI/CD definitions when they identify published images.
3. Use Podman registry search where the registry supports useful search.
4. Use remote OCI inspection and tag enumeration through available
   containers/image-compatible tooling, such as Podman search and Skopeo, when
   available and permitted by the environment.
5. Research additional plausible OCI locations through web and repository
   sources. Follow evidence to vendor, hardened, community, or organization-
   specific registries even when they were not previously configured.
6. Expand from credible references to additional registry/repository candidates.
7. Stop when a complete expansion pass produces no new credible
   registry/repository candidates.

`podman search` is a candidate generator, not existence, provenance, release,
or trust proof. Do not treat an empty search result as proof that no image
exists.

## Authentication

Use existing registry authentication only when it is already available to the
Podman/containers environment.

Do not:

- ask the user to paste passwords, tokens, or other registry credentials;
- run `podman login` or an equivalent login command;
- create or modify auth files;
- create, update, or consume a new Shimmy credential-management feature; or
- expose credential material in output.

For an authentication-required candidate whose existing credentials are
unavailable:

- keep the candidate visible;
- mark OCI inspection fields that could not be verified;
- label access as `Login required`;
- find and provide the most authoritative available registry login/onboarding
  documentation;
- summarize supported IdPs, account prerequisites, or enrollment requirements
  when the registry documents them; and
- never invent or infer login procedures from unrelated registries.

Authentication friction does not reduce the candidate security-posture score.

## Remote inspection boundary

Discovery performs metadata validation only. It may:

- enumerate tags;
- resolve a tag to an immutable top-level digest;
- inspect OCI/Docker manifest-list media type;
- inspect platform descriptors;
- inspect OCI annotations/config metadata when remotely available;
- inspect entrypoint, command, user, and working-directory metadata when
  remotely available; and
- collect provenance, maintenance, hardening, and registry-process evidence.

Discovery must not:

- pull an image;
- run an image;
- create a temporary container;
- mount host paths;
- pass credentials into a candidate container; or
- claim runtime compatibility from metadata alone.

`shimmy-create-tool` owns wrapper design and runtime acceptance.

## Candidate visibility and selectability

Show every credible candidate, including upstream, vendor, hardened,
third-party, and community images. Do not suppress a candidate solely because
its publisher is not upstream.

Classify candidates as:

- **selectable**: the requested release is sufficiently corroborated, the exact
  immutable top-level manifest is remotely verified, and it contains both
  `linux/amd64` and `linux/arm64`;
- **incompatible**: credible candidate, but a confirmed Shimmy compatibility
  requirement is not satisfied, such as a missing required architecture;
- **ambiguous**: plausible candidate for which available evidence cannot
  establish one or more discovery requirements; or
- **noise**: evidence establishes that the result is unrelated to the requested
  CLI. Omit noise from the final report.

Incompatible candidates remain in the final report with concise metadata only:
registry/repository, tag, digest when known, release claim, and the incompatibility
reason.

After discovery converges, collect all ambiguous candidates into one user
prompt. Explain each ambiguity briefly and ask which candidates the user wants
retained in the final report. The user may choose any combination, including all
or none. Retained ambiguous candidates stay clearly labeled `AMBIGUOUS`.

An ambiguous or incompatible candidate is never selectable for an external OCI
handoff unless all normal selectability requirements become verified.

## Security-posture ranking

Rank selectable candidates by an explainable weighted estimate. Ranking orders
options; it does not hide technically valid alternatives and does not establish
that one image is functionally equivalent to another.

Weights:

| Factor | Weight |
| --- | ---: |
| Candidate-specific hardening/security evidence | 30% |
| Registry security program/reputation | 15% |
| Publisher/source provenance | 15% |
| Effective Podman `registries.conf` presence/order | 20% |
| Maintenance/freshness evidence | 15% |
| Independent Agent judgment | 5% |

Score the five evidence dimensions other than Podman preference on this common
0-100 scale:

| Evidence | Score |
| --- | ---: |
| Exceptional / independently documented | 100 |
| Strong | 80 |
| Moderate | 60 |
| Limited | 40 |
| Weak / concerning | 20 |
| Negative evidence | 0 |
| Unknown | 30 |

Score the Podman local-preference factor as:

| Effective Podman evidence | Factor score |
| --- | ---: |
| First `unqualified-search-registries` entry | 100 |
| Second | 90 |
| Third | 80 |
| Fourth or later | 70 |
| Explicit `prefix`, `location`, mirror, or replacement occurrence | 60 |
| Registry absent from effective Podman configuration | 0 |

Calculate:

```text
overall =
  hardening * 0.30 +
  registry_posture * 0.15 +
  provenance * 0.15 +
  podman_preference * 0.20 +
  maintenance * 0.15 +
  agent_judgment * 0.05
```

Map the weighted result to:

| Overall | Label |
| --- | --- |
| 85-100 | Strongly recommended |
| 70-84 | Recommended |
| 55-69 | Acceptable with caution |
| 40-54 | Elevated caution |
| 0-39 | High risk / weak evidence |

Report a separate `High`, `Medium`, or `Low` confidence based on the quality and
coverage of evidence supporting the evidence-based portion of the score. Do not
use confidence to hide uncertainty behind a precise number.

The 5% Agent-judgment contribution must be disclosed as subjective and briefly
explained. The other factors must cite or identify the evidence used.

### Security evidence expectations

Investigate candidate-specific and registry-level controls when evidence is
available, including examples such as:

- documented container hardening standards;
- vulnerability and malware scanning;
- SBOM production or validation;
- signed-image or provenance requirements;
- source/build traceability;
- peer or security review;
- risk acceptance processes;
- continuous rescanning/monitoring;
- rebuild cadence after dependency CVEs; and
- published security response practices.

Do not award hardening points merely because a registry has a strong brand.
Distinguish candidate-specific evidence from registry-wide processes.

## User-facing candidate report

Group selectable candidates by supported tool release when that improves
clarity. Within a release, sort by weighted security posture.

For a selectable candidate, show enough discriminator information for a user
decision without dumping raw registry metadata:

- fully qualified registry/repository;
- tag and immutable digest;
- corroborated tool release;
- recommendation and score;
- confidence;
- public/authenticated access, including `Login required` where applicable;
- required-platform verification;
- publisher/source relationship;
- important hardening and registry-process evidence;
- local Podman preference evidence;
- maintenance/freshness evidence;
- material risks or uncertainties; and
- authoritative source links.

Do not group results by digest. If identical digests are noticed, they may be
mentioned as informational evidence only.

Keep incompatible-candidate metadata concise so that it explains exclusions
without overwhelming the selectable results.

## No compatible external OCI implementation

If no selectable external candidate remains, conclude that a Shimmy local image
build is required to support all current Shimmy architectures.

Research and report:

- authoritative upstream build documentation;
- upstream source repository;
- release artifacts for `linux/amd64` and `linux/arm64` when published;
- architecture-specific build notes;
- known build dependencies;
- whether upstream directly documents an OCI/container build process;
- authoritative upstream Dockerfile/Containerfile or container-build
  documentation when it exists; and
- limitations or unknowns that `shimmy-create-tool` must resolve.

Do not create the local image in this skill.

## Selection

After the final ranked report, ask the user to select one selectable
release/image pair. Selection is explicit; never auto-select the highest-ranked
candidate.

If no external candidate is selectable, present the local-build-required
conclusion for review instead.

## Handoff to shimmy-create-tool

After the user selects a candidate, or accepts the local-build-required
conclusion, present a concise factual handoff. Do not include the complete
candidate matrix, security-scoring internals, rejected alternatives, or other
discovery-only reasoning.

Then ask whether the user wants to continue with `shimmy-create-tool`. Do not
begin repository implementation until the user explicitly agrees.

### External OCI handoff

Include only information useful to the creation skill:

```text
SHIMMY TOOL DISCOVERY HANDOFF

discovery_outcome=external-oci-selected

tool_name=
tool_description=

upstream_project_url=
upstream_repository_url=
upstream_documentation_url=
upstream_release=
upstream_release_url=

image_upstream_ref=
image_default_ref=
image_registry_access=public|authenticated
image_platform=linux/amd64
image_platform=linux/arm64

publisher_relationship=upstream|endorsed|third-party|unknown
provenance_notes=
known_risks=

container_entrypoint=
container_cmd=
container_user=
container_workdir=

required_companion_tools=
required_plugins=
credential_requirements=
network_requirements=
privilege_requirements=

source_links=
```

`image_upstream_ref` is the selected fully qualified mutable tag.
`image_default_ref` is the selected fully qualified immutable top-level digest.
Do not invent a Shimmy version-directory name or `tool_default_version`;
`shimmy-create-tool` owns Shimmy version-track design.

### Local-build-required handoff

```text
SHIMMY TOOL DISCOVERY HANDOFF

discovery_outcome=local-build-required

tool_name=
tool_description=

upstream_project_url=
upstream_repository_url=
upstream_documentation_url=
upstream_release=
upstream_release_url=

upstream_build_documentation_url=
upstream_release_artifacts_url=
upstream_documents_oci_build=yes|no|unknown
upstream_oci_build_documentation_url=
upstream_container_build_file_url=

build_dependencies=
release_artifacts_linux_amd64=
release_artifacts_linux_arm64=
architecture_build_notes=

required_companion_tools=
required_plugins=
credential_requirements=
network_requirements=
privilege_requirements=

known_risks=
source_links=
```

## Safety and scope

- Do not modify Shimmy CLI commands, catalog model, catalog resources, catalog
  configuration, profiles, redirects, or registry authentication.
- Do not add registry preference/blocking behavior. A future feature may supply
  that policy; this skill currently discovers and reports all credible options.
- Do not install, provision, start, stop, restart, rename, or adopt Podman
  machines.
- Do not pull or run candidate images.
- Do not request, print, or persist registry secrets.
- Do not claim an image is safe, secure, official, or functionally equivalent
  without evidence appropriate to that statement.
- Do not silently prefer upstream images over hardened, vendor, or community
  alternatives; apply the documented rubric and let the user decide.
- Keep source links authoritative when possible and identify inference when
  primary evidence is unavailable.
