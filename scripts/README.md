# scripts/

This directory is for executable repo-level entrypoints.

If a file lives here, a contributor should be able to reasonably assume it is meant to be run directly by a human, CI job, or another automation step.

## Put A File In `scripts/` When

- It is an executable command for working on Shimmy itself.
- It performs a repo lifecycle action such as install, update, status, or test.
- It is part of the control surface a contributor is expected to run directly.

## Do Not Put A File In `scripts/` When

- It is only sourced by another shell script.
- It exists only to hold shared functions, variables, or rendering helpers.
- It is installed as part of the runtime support used by shims.

## Use These Folders Instead

- `lib/repo/`: Shared shell libraries sourced by `shimmy` or files in `scripts/`.
- `lib/shims/`: Shared helper libraries sourced by installed shims at runtime.
- `shims/`: User-facing tool wrappers such as `aws`, `task`, or `terraform`.

## Quick Rule

If you run it, it probably belongs in `scripts/`.

If you `source` it, it probably belongs in `lib/repo/` or `lib/shims/`.
