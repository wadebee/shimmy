# Samples

This directory contains sample projects that demonstrate ways to compose Shimmy
shims into higher-level workflows.

## Ansible Hello World

[`samples/ansible-hello`](ansible-hello/hello.yaml) contains a minimal local
inventory and playbook for running, validating, and linting Ansible content
with the
[`community-ansible-dev-tools` shim](../tools/community-ansible-dev-tools/guide.md#hello-world-quick-start).

## Host CLI

`samples/host` is a Go-based CLI sample for working with cloud hosting
providers through Shimmy-backed CLIs.
