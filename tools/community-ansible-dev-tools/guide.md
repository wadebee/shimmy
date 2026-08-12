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

Run a bundled command by placing it after the shim name:

```sh
community-ansible-dev-tools --version
community-ansible-dev-tools ansible-lint .
community-ansible-dev-tools ansible-playbook -i inventory site.yml
community-ansible-dev-tools ansible-navigator --version
```

Running the shim without arguments starts the image's default interactive
`zsh` shell. `--version` is a shim shorthand for `adt --version`, which reports
the bundled development-tool versions.

The current directory is mounted read-write at `/workdir`, matching the
publisher image's declared working directory and command-line usage. Project
files such as `ansible.cfg`, inventories, playbooks, roles, and collections
therefore remain visible to the contained tools.

Environment:

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

## Quick-Start Prompts

- Home labber: "Run my inventory syntax check with `community-ansible-dev-tools ansible-inventory -i inventory --graph`."
- Software developer: "Use `community-ansible-dev-tools ansible-lint .` and explain each actionable failure."
- Platform engineer: "With SSH-agent forwarding enabled, run this playbook in check mode against the staging inventory."
