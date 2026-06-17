# Prompt
I have two code branches in this repo (codex and gemini-flash). They represent the output from two different llm models both of which were tasked with the exact same prompt and with access to the same Shimmy Agent skills.  Here is the prompt "Implement plan @oc_multi_version_shim.md. Use iterative batch processing if needed to manage your context window. Stop and prompt user if questions surface during the implementation that materially affect the quality of the output."

Compare the 2 implementations and provide a pros/cons of each. At firest glance The codex implementation appears more thorough, it covers additional file updates like a README.md and *sh scripts updates that gemini-flash did not. Help me understand why? Is there additional guidance content that can be added to Shimmy agent skills or "Lessons learned" so that differing models can provide more through updates when creating new Shimmy shims

# Response
I compared `main..codex` and `main..gemini-flash` read-only. I did not run the test suites.

**Bottom Line**
The `codex` branch is materially more complete. It treats `oc` as a full Shimmy-supported feature, while `gemini-flash` mostly implements the runtime wrappers.

`codex`: 21 files changed, 581 insertions.  
`gemini-flash`: 12 files changed, 292 insertions.

**Codex Pros**
- Adds the dispatcher and versioned shims: `oc`, `oc_4_18`, `oc_4_20`, `oc_4_22`.
- Updates catalog support in `lib/repo/shimmy-catalog.sh`.
- Updates `README.md`, including the included-shims table.
- Adds `docs/shims/oc.md` plus small per-version docs.
- Adds `scripts/status-shimmy.sh` image descriptions, so `shimmy status` does not show `unknown`.
- Adds `scripts/update-shimmy.sh` pull refresh cases for `oc_4_*`, which matters because the plan uses floating minor tags.
- Adds a new `.agents/skills/shimmy-tool-oc/SKILL.md`.
- Adds tests for missing/unsupported `SHIMMY_OC_VERSION`, dispatcher preview, install smoke config, status output, and update pull wiring.
- Introduces `smoke_env=...` support for shim test configs, which is the right generic solution for selector-driven dispatchers.

**Codex Cons / Gaps**
- If the plan literally requires image pulling during `shimmy install`, codex does not implement that. It only wires `shimmy update --pull`.
- It adds `-i` by default for the `oc_4_*` shims, whereas existing AWS/Terraform-style interactive CLIs usually only add `-it` when attached to a terminal. This may be fine, but it should be deliberate.
- It mounts `~/.config/oc` in addition to `~/.kube`; useful, but worth confirming as intentional.
- It still does not appear to handle custom `KUBECONFIG` paths.

**Gemini-Flash Pros**
- Implements the core files: dispatcher, three versioned shims, `.conf` files, catalog entry, docs page, and preview tests.
- The implementation is smaller and closer to the literal minimum.
- Runtime wrappers follow familiar existing shim shape reasonably well.

**Gemini-Flash Cons**
- No `README.md` update, so the shims are not discoverable in the included-shims table.
- No `scripts/status-shimmy.sh` update, so status output would show `unknown` for installed `oc` shims.
- No `scripts/update-shimmy.sh` pull handling, so floating `:4.18`, `:4.20`, `:4.22` tags will not refresh through `shimmy update --pull`.
- No `shimmy-tool-oc` skill, despite the Shimmy creation skill requiring one for new/materially changed shims.
- Test config is likely wrong: `smoke_arg=version --client` is treated as one argv item, not two. The repo convention requires repeated lines.
- It hardcodes `SHIMMY_OC_VERSION=4.20` globally in the test runner instead of adding a data-driven per-shim config mechanism.
- It deletes unrelated learning guidance from `shimmy-tool-opnsense-mcp-admin/SKILL.md`, which looks accidental.
- Dispatcher is hardcoded to only the three 4.x versions, so adding `5.1` requires editing the dispatcher.

**Why Codex Was More Thorough**
The current Shimmy guidance already says new shims should update runtime shims, configs, catalog, tests, README, status/update wiring, and a matching tool skill together. Codex followed that broader “feature integration” interpretation. Gemini appears to have optimized for the direct implementation sections of the plan and stopped after the core shim behavior plus minimal tests/docs.

There is also conflicting/stale guidance: `docs/prompt-shimmy-project.md` still says `scripts/install-shimmy.sh` enumerates shim names explicitly, but the current repo uses `lib/repo/shimmy-catalog.sh`. That kind of mismatch can cause weaker models to miss lifecycle surfaces or update the wrong area.

**Guidance To Add**
I would add a “new shim definition of done” checklist to `shimmy-create-tool`:

- Runtime wrapper exists and is executable.
- `.conf` exists; each `smoke_arg=` is exactly one argv item.
- Selector/env-driven shims use `smoke_env=KEY=value`; never hardcode shim-specific env defaults in the generic test runner.
- `lib/repo/shimmy-catalog.sh` includes the shim.
- `scripts/status-shimmy.sh` describes the image or dispatcher.
- `scripts/update-shimmy.sh` handles `--pull` for remote images or `--build` for local images.
- `README.md` included-shims table is updated and sorted.
- `docs/shims/<tool>.md` exists; versioned/alias shims have docs or clear references.
- `.agents/skills/shimmy-tool-<tool>/SKILL.md` exists and is installed into the repo skills manifest.
- Tests cover direct preview, installed smoke config, status output, and update pull/build behavior.
- Before finalizing, run `rg` for the new shim name across `README.md`, `docs/`, `shims/`, `scripts/`, `lib/repo/`, and `.agents/skills/`.

I’d also add a specific lesson:

`smoke_arg=` lines are not shell-split. Use repeated `smoke_arg=` entries for multi-argument commands, and use `smoke_env=KEY=value` for non-secret selector variables like `SHIMMY_OC_VERSION=4.20`.