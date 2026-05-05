# Host CLI Sample

`host` is a sample Go CLI that demonstrates how a project-specific tool can
compose Shimmy shims into auditable hosting workflows.

The current sample focuses on configuration as code. Cloud actions such as
`host login` and `host whoami` still print stubbed command plans.

## Tuple Model

Host configuration is keyed by a deterministic `system/stage/slot` tuple:

- `system` is the logical grouping, such as an app, platform, service, or tenant.
- `stage` is lifecycle intent, such as `dev`, `stage`, or `prod`.
- `slot` is the concrete instance identity, such as `1`, `blue`, `green`, or `canary`.

Each fully qualified tuple represents a self-contained configuration bundle that
can be cloned, promoted, versioned, rendered, and audited independently.

## File Naming

Repository config lives under `.config/host`:

```text
.config/host/config-sys-{system}.yaml
.config/host/config-sys-{system}-stg-{stage}.yaml
.config/host/config-sys-{system}-stg-{stage}-slot-{slot}.yaml
```

Global user defaults live at:

```text
~/.config/host/config-user.yaml
```

Enterprise policy is optional and lives at:

```text
/etc/host/config-enterprise.yaml
```

`host config init` does not write `/etc/host` directly. It writes a repo-local
template at `.config/host/config-enterprise.example.yaml` and prints install
instructions.

Tuple Segment constraints:

- `system`: max 24 characters
- `stage`: max 12 characters
- `slot`: max 12 characters
- lowercase letters, numbers, and hyphens only
- no leading or trailing hyphen

## Configuration Hierarchy

Effective slot config is rendered in this order:

1. enterprise policy from `/etc/host/config-enterprise.yaml`, if present
2. user defaults from `~/.config/host/config-user.yaml`, if present
3. system defaults
4. stage defaults
5. slot config
6. enterprise policy again as the immutable final overlay

Merge behavior:

- maps merge recursively
- scalars replace inherited values
- lists replace inherited values
- `null` removes inherited values, including whole blocks
- enterprise values cannot be overridden or removed by lower-level config

## Getting Started

Run these commands from the sample directory:

```sh
cd samples/host
go run . config init --system aws --stage dev --slot 1
```

A fully qualified first run creates missing parent configs and reports each
file it created. Later runs announce when new child config adopts existing
parent defaults.

Render the effective bundle:

```sh
../../shims/go run . config render --system aws --stage dev --slot 1
```

Commands that require a subcommand or tuple parameters print usage when those
inputs are missing:

```sh
go run . config
go run . config render --system aws
```

Install the enterprise policy template only when you want machine-wide
governance policy:

```sh
sudo mkdir -p /etc/host
sudo cp .config/host/config-enterprise.example.yaml /etc/host/config-enterprise.yaml
```

The generated enterprise template is commented out by default, so copying it
without uncommenting policy blocks does not enforce anything.

## Stubbed Cloud Commands

The cloud commands require a fully qualified tuple:

```sh
../../shims/go run . whoami --system aws --stage dev --slot 1
../../shims/go run . login --system aws --stage dev --slot 1
```

The commands use the rendered bundle, then print stubbed Shimmy-backed AWS
command plans. They do not make live AWS calls.

## Testing

Run the sample unit tests through Shimmy's Go shim:

```sh
cd samples/host
../../shims/go test ./...
```
