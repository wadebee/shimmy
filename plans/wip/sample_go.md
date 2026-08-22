Updated Command Behavior
**Status:** not started

host config init should be hierarchical and ergonomic.

A fully qualified first run:

host config init --system payments --stage prod --slot blue
should create all missing configs:

~/.config/host/config-user.yaml
.config/host/config-enterprise.example.yaml
.config/host/config-sys-payments.yaml
.config/host/config-sys-payments-stg-prod.yaml
.config/host/config-sys-payments-stg-prod-slot-blue.yaml
It should alert the caller, for example:

Created user config: ~/.config/host/config-user.yaml
Created enterprise example: .config/host/config-enterprise.example.yaml
Created system config: .config/host/config-sys-payments.yaml
Created stage config: .config/host/config-sys-payments-stg-prod.yaml
Created slot config: .config/host/config-sys-payments-stg-prod-slot-blue.yaml
If parents already exist, subsequent runs should explicitly say the new child is adopting those defaults:

Using existing system defaults: .config/host/config-sys-payments.yaml
Using existing stage defaults: .config/host/config-sys-payments-stg-prod.yaml
Created slot config: .config/host/config-sys-payments-stg-prod-slot-green.yaml
If the target file already exists:

Config already exists: .config/host/config-sys-payments-stg-prod-slot-blue.yaml
I would not overwrite existing files unless a future --force flag is added.

Render Scope

Approved: host config render can be fully implemented now using the planned YAML discovery and merge implementation.

Command:

host config render --system payments --stage prod --slot blue
It should render the effective, fully self-contained slot bundle after applying:

enterprise
user
system
stage
slot
enterprise again
If enterprise config is missing, skip it silently or with a low-noise notice depending on existing CLI style. Since it is optional, I’d avoid warning on every render.

Final Current Plan

Read AGENTS.md, CONTRIBUTING.md, and current host CLI/sample implementation before modifying files.
Inspect existing JSON config usage across code, samples, docs, and tests.
Remove JSON config support.
Add YAML config support.
Implement slug validation:
system: max 24
stage: max 12
slot: max 12
lowercase letters, numbers, hyphens
no leading/trailing hyphen
Implement host config init:
--system <system>
optional --stage <stage>
optional --slot <slot>
--slot requires --stage
first fully qualified run creates all missing parents
subsequent runs announce when existing parent defaults are adopted
never overwrite existing files
Generate YAML files:
~/.config/host/config-user.yaml
.config/host/config-enterprise.example.yaml
.config/host/config-sys-{system}.yaml
.config/host/config-sys-{system}-stg-{stage}.yaml
.config/host/config-sys-{system}-stg-{stage}-slot-{slot}.yaml
Add enterprise install instructions after example generation:
sudo mkdir -p /etc/host
sudo cp .config/host/config-enterprise.example.yaml /etc/host/config-enterprise.yaml
Implement host config render fully:
requires --system, --stage, and --slot
discovers config files
merges YAML into effective slot bundle
reapplies enterprise as immutable final overlay
prints effective YAML
Implement merge semantics:
maps merge recursively
scalars replace
lists replace
null removes inherited values, including whole blocks
enterprise cannot be removed or overridden
Add metadata.labels to generated defaults for query/readiness:
system labels
stage labels
slot labels
Update docs with:
system/stage/slot tuple model
governance-as-code bundle concept
naming convention
slug constraints
init behavior
render behavior
enterprise install instructions
Add/update tests for:
init generation for system/stage/slot
first fully qualified init creating parents
parent adoption notices
no overwrite behavior
slug validation
YAML parsing
config discovery
render output
recursive map merge
scalar replacement
list replacement
null block removal
enterprise immutability
JSON config removal/rejection
Run relevant tests and summarize files changed, behavior, and verification.
