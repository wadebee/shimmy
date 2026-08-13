# Community Ansible Development Tools Shim

## Upstream

- Container usage: <https://docs.ansible.com/projects/dev-tools/container/#usage>
- Ansible Execution Environment guide: <https://docs.ansible.com/projects/ansible/latest/getting_started_ee/>
- Running Ansible with a community EE: <https://docs.ansible.com/projects/ansible/latest/getting_started_ee/run_community_ee_image.html>
- Source repository: <https://github.com/ansible/ansible-dev-tools>
- Shim image: `ghcr.io/ansible/community-ansible-dev-tools@sha256:c3b5c90efdd79dd064b9c997fe7bd6e1ee3c6894ecc8270d05257532936af209` from `versions/26.7/image.conf` (release `v26.7.2`)

## Upstream Summary

The publisher image is an Ansible Execution Environment for creating and
testing Ansible content. It bundles `ansible-core`, `ansible-builder`,
`ansible-creator`, `ansible-lint`, `ansible-navigator`, `ansible-sign`,
Molecule, pytest-ansible, tox-ansible, and related dependencies. The image can
also run Podman inside the container when given the publisher's additional
capabilities, device, namespace, and security options.

## Shimmy Usage

The image bundles a multi-command Ansible development environment rather than a
single CLI.

Running the shim without arguments starts the image's default interactive
shell. `--version` is a shim shorthand for `adt --version`, which reports
the bundled development-tool versions.

By default the current directory is mounted read-write at `/workdir`, matching
the publisher image's declared working directory and command-line usage. Use
`--mount-workdir /absolute/host/path` to mount a different host directory at
`/workdir` when you need to run from one location while exposing another.
Project files such as `ansible.cfg`, inventories, playbooks, roles, and
collections therefore remain visible to the contained tools.

### Hello World Quick Start

The repository includes the
[Ansible Hello World sample](../../samples/ansible-hello/hello.yaml) and its
local inventory under `samples/ansible-hello`. Run the following from your host shell (non-interactive mode) and  the repository root. 

Run the playbook against the mounted sample files from the shimmy container:

```sh
./commands/run-tool.sh community-ansible-dev-tools --mount-workdir /home/beewa/repos/GitHub/wadebee/shimmy/samples/ansible-hello ansible-playbook -i inventory.ini hello.yaml
```

If you need to invoke the shim from outside the playbook directory, override the
mounted host path explicitly:

```sh
community-ansible-dev-tools \
  --mount-workdir /absolute/path/to/samples/ansible-hello \
  ansible-playbook -i inventory.ini hello.yaml
```

The play prints `Hello world from Ansible!` and should finish with
`failed=0`. It uses Ansible's local connection, so it does not require an SSH
server or credentials.

Validate the playbook syntax without running its tasks:

```sh
community-ansible-dev-tools ansible-playbook \
  -i inventory.ini \
  hello.yaml \
  --syntax-check
```

Lint the playbook for Ansible content and style issues:

```sh
community-ansible-dev-tools ansible-lint hello.yaml
```

Environment:

- `--mount-workdir /absolute/host/path` - override the default `$PWD` host mount for `/workdir`.
- `SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_IMAGE` - override the container image.
- `SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_IMAGE_PULL=always` - force pulling the configured image.
- `SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AGENT=1` - mount and forward the host's existing `SSH_AUTH_SOCK` for remote-target authentication.
- `SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_GIT_CONFIG=1` - mount `$HOME/.gitconfig` read-only at `/root/.gitconfig`.
- `SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN=1` - enable the publisher-documented container-in-container options.

Credential mounts are disabled by default. The SSH-agent opt-in requires an
existing `SSH_AUTH_SOCK`; it does not mount private-key files. The git-config
opt-in is read-only because Git configuration can contain credential helpers
or other sensitive host-specific settings.

Nested Podman is disabled by default. Its opt-in adds `SYS_ADMIN` and
`SYS_RESOURCE`, exposes `/dev/fuse`, uses the host user namespace, and disables
AppArmor, SELinux labeling, and seccomp confinement as documented upstream.
Use it only for workflows such as Molecule or `ansible-builder` that actually
need a container engine inside the development container. Shimmy omits the
publisher example's fixed container name so independent invocations can run
concurrently.

The container uses Podman's normal bridged network, which allows Ansible to
reach remote managed nodes subject to host and Podman network policy.

Runtime platform:

- Linux or macOS on `amd64` -> `linux/amd64`
- Linux or macOS on `arm64` -> `linux/arm64`

## Other Quick-Start Prompts

- Home labber: "Run my inventory syntax check with `community-ansible-dev-tools ansible-inventory -i inventory --graph`."
- Software developer: "Use `community-ansible-dev-tools ansible-lint .` and explain each actionable failure."
- Platform engineer: "With SSH-agent forwarding enabled, run this playbook in check mode against the staging inventory."

I’ll inspect the existing guide and related references, then I’ll give you the exact documentation additions I recommend, including a human-readable command table you can paste into the guide.

### Interactive shell behavior

Running `community-ansible-dev-tools` with no arguments starts the container's
default interactive `zsh` shell in `/workdir`. This is expected behavior for
the upstream development environment image rather than a prompt for special
Shimmy input.

```sh
community-ansible-dev-tools
```

Inside that shell, use `adt` to inspect the top-level tool suite and its
available commands:

```sh
adt --help
adt --version
```

Use `adt --help` to see the top-level command groups exposed by the Ansible
development environment. Use `adt --version` to confirm the bundled tool
versions.

After discovering a command, either run it directly inside the interactive
shell:

```sh
ansible-lint .
ansible-playbook -i inventory.ini hello.yaml
ansible-navigator --version
```

or invoke it from the host shell through the shim:

```sh
community-ansible-dev-tools ansible-lint .
community-ansible-dev-tools ansible-playbook -i inventory.ini hello.yaml
community-ansible-dev-tools ansible-navigator --version
```

Exit the interactive shell with:

```sh
exit
```

## Non-Interactive / Automation Usage

Run a bundled command by placing it after the shim name:

```sh
community-ansible-dev-tools --version
community-ansible-dev-tools ansible-lint .
community-ansible-dev-tools ansible-playbook -i inventory site.yml
community-ansible-dev-tools ansible-navigator --version
```

### Top-level Command Reference

For the latest and most authoritative command syntax and workflow details, consult the upstream
Ansible development-tools and execution-environment documentation linked above.

The following commands are commonly used from the interactive shell
or through the shim.

| Command | Purpose | Common examples |
| --- | --- | --- |
| `adt` | Top-level Ansible development tools entrypoint for inspecting the bundled tool suite and reporting version information. | `adt --help`<br>`adt --version` |
| `ansible` | General Ansible command-line entrypoint for ad hoc automation and shared subcommands. | `ansible --version`<br>`ansible localhost -m ping` |
| `ansible-playbook` | Run playbooks against inventories and managed nodes. | `ansible-playbook -i inventory.ini hello.yaml`<br>`ansible-playbook -i inventory site.yml --check` |
| `ansible-lint` | Lint playbooks, roles, and collections for correctness and style issues. | `ansible-lint .`<br>`ansible-lint hello.yaml` |
| `ansible-navigator` | TUI-oriented interface for running and inspecting Ansible workflows, inventories, and execution environments. | `ansible-navigator --version`<br>`ansible-navigator inventory -i inventory.ini --graph` |
| `ansible-builder` | Build Ansible execution environment container images from `execution-environment.yml`. | `ansible-builder build`<br>`ansible-builder build -t my-ee:dev` |
| `ansible-creator` | Scaffold new Ansible content such as collections and related project structure. | `ansible-creator --help`<br>`ansible-creator init collection my_namespace.my_collection` |
| `ansible-sign` | Sign and verify Ansible content artifacts where signing workflows are in use. | `ansible-sign --help`<br>`ansible-sign verify --help` |
| `molecule` | Test Ansible roles and collections across scenario-based lifecycle steps. | `molecule --help`<br>`molecule test` |
| `pytest` | Run Python-based tests, including tests used by Ansible content projects. | `pytest`<br>`pytest tests/` |
| `tox` | Run multi-environment test automation for projects that define tox environments. | `tox`<br>`tox -e py` |
