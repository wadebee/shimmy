I’ll follow your `PLAN → REVIEW → ACT` model, use the `/compare-3-branches` workflow to generate diffs for `codex`, `gpt5.1-high`, and `gemini-flash`, then analyze those diffs to produce a concrete pros/cons comparison and “lessons learned” for Shimmy agent skills.

First I’ll:
- Read the `/compare-3-branches` workflow to see exactly what commands and tmp paths it defines.
- Run the workflow’s commands (read-only `git`/diff steps) via `run_command`, honoring any `// turbo` hints.
- Inspect the generated tmp files with `read_file`.
- Then synthesize:
  - A structured pros/cons table per branch.
  - Guidance updates you can add to Shimmy agent skills or prompts.

Since you explicitly asked me to “implement” this using the workflow, I’ll treat that as plan approval and start by opening the workflow file.
The workflow file path I guessed doesn’t exist under `.windsurf/workflows`, so I’ll first list that directory to find the exact filename for your `compare-3-branches` workflow, then open it, and from there execute its steps (primarily `git`/diff commands) via `run_command`.



The diffs between `codex`, `gpt5.1-high`, and `gemini-flash` are now generated under `.windsurf/tmp/branch-diffs`. Next I’ll read the summary (`--stat`) and full diffs, extract what each branch changed (especially around shims, scripts, and docs), and then synthesize the pros/cons and “lessons learned” you asked for.

I’ll dig a bit deeper into the oc shim and test/docs diffs between the three branches so I can describe each branch’s behavior accurately, then I’ll synthesize a concise pros/cons table and concrete “lessons learned” you can feed back into Shimmy skills.

# Findings from the workflow comparison

Using your `/compare-3-branches` workflow, I inspected:

- `.windsurf/tmp/branch-diffs/codex--gpt5.1-high.*.diff`
- `.windsurf/tmp/branch-diffs/codex--gemini-flash.*.diff`
- `.windsurf/tmp/branch-diffs/gpt5.1-high--gemini-flash.*.diff`

In these diffs, `a/` = `codex`, `b/` = the other branch. So “`-`” lines are from `codex`, “`+`” lines are the alternative branch.

The comparison is all about the **oc multi-version shim** and related wiring.

---

## High‑level comparison

### 1. Scope of changes

- **codex**
  - Keeps or updates:
    - `.agents/skills/shimmy-tool-oc/SKILL.md`
    - `.agents/skills/.shimmy-skills-manifest.txt` entry for `shimmy-tool-oc`
    - `README.md` shim table entries for `oc`, `oc_4_18`, `oc_4_20`, `oc_4_22`
    - `docs/shims/oc.md` plus separate `docs/shims/oc_4_18.md`, `oc_4_20.md`, `oc_4_22.md`
    - `scripts/status-shimmy.sh` oc entries
    - `scripts/update-shimmy.sh` pull-refresh for `oc_4_18/20/22`
    - `scripts/test-shimmy.sh`:
      - `smoke_env` support in `test_shim_smoke_run`
      - Dedicated oc tests:
        - `test_oc_dispatcher_missing_version`
        - `test_oc_dispatcher_unsupported_version`
        - `test_oc_dispatcher_preview`
        - `test_oc_install_and_smoke_config`
        - `test_update_pull_refresh_includes_oc_minor_shims`
    - `shims/oc`, `shims/oc.conf`, `shims/oc_4_18/20/22`, and their `.conf` where appropriate

- **gpt5.1-high (relative to codex)**
  - **Removes**:
    - `shimmy-tool-oc` SKILL file and its manifest entry.
    - All oc shim rows from `README.md`.
    - `docs/shims/oc_4_18.md`, `oc_4_20.md`, `oc_4_22.md`.
    - oc entries in `scripts/status-shimmy.sh` and `scripts/update-shimmy.sh`.
    - `shims/oc.conf`.
    - The oc-focused tests listed above.
  - **Changes**:
    - `docs/shims/oc.md` to a “Multi‑Version Shim” rewrite.
    - `docs/templates/generic-shim/SKILL.md` and `docs/testing.md` to **remove `smoke_env` guidance**.
    - `scripts/test-shimmy.sh` to drop `smoke_env` support in `test_shim_smoke_run`.
    - `shims/oc` dispatcher logic to a simpler `case` over `4.18/4.20/4.22` (no generic `major.minor` mapping).
    - `shims/oc_4_18` / `oc_4_20` / `oc_4_22` Podman wrapper details (TTY behavior, mount vars, no explicit `--entrypoint oc`).

- **gemini-flash (relative to codex and gpt5.1-high)**
  - Inherits almost all the **scope reductions** from `gpt5.1-high`:
    - Still no `shimmy-tool-oc` SKILL or manifest entry.
    - Still removes oc from `README.md`, `status-shimmy.sh`, `update-shimmy.sh`.
    - Still removes `smoke_env` from generic docs and from `test_shim_smoke_run`.
  - Adds/changes on top:
    - Introduces `shims/oc.conf` and `shims/oc_4_18/20/22.conf` with `smoke_arg=version --client`.
    - Modifies `test_shim_smoke_run` to inject `SHIMMY_OC_VERSION=${SHIMMY_OC_VERSION:-4.20}` when running shim smoke commands.
    - Replaces `test_oc_dispatcher_version_selection` with `test_oc_shim_preview` focused on `--preview-shim` and `--client`.
    - Refines oc dispatcher script slightly (better error messaging, direct `exec "$SCRIPT_DIR/oc_4_xx"`).
    - Rewrites `docs/shims/oc.md` to a more “CLI usage” oriented doc (top-level commands, upstream README, etc.), but still less multi-version‑focused than codex.

---

## Pros / Cons by branch

### codex

- **Pros**
  - **Full-stack integration**:
    - SKILL manifest, README, docs, status, update, tests, and configs are all kept consistent for oc and its minor shims.
  - **Strong tests**:
    - Verifies dispatcher behavior (missing/unsupported version, preview, install + smoke config) and update pull behavior.
  - **Configuration semantics preserved**:
    - Uses `smoke_env` in `oc.conf` for `SHIMMY_OC_VERSION=4.20`, plus multiple `smoke_arg` lines for `--preview-shim` and `version`. This matches the generic-shim SKILL docs.
  - **Future-ready dispatcher**:
    - Maps arbitrary `major.minor` (`oc_5_1`, etc.) using `oc_${major}_${minor}` pattern and verifies a matching shim exists.
  - **No scope creep**:
    - Does not touch unrelated skills (e.g., opnsense) beyond what’s needed.

- **Cons / Risks**
  - Slightly more complex dispatcher logic than the simple `case` variants.
  - More files to keep in sync (separate docs for each `oc_4_xx`), so future maintenance requires diligence.
  - If the goal was to *remove* `smoke_env` globally, codex is the outlier; but your existing docs strongly favor codex’s approach.

### gpt5.1-high

- **Pros**
  - Makes oc doc (`docs/shims/oc.md`) more explicitly about the multi-version dispatcher.
  - Simplifies dispatcher implementation by hard-coding the supported versions.
  - Simplifies Podman shims (less state, explicit handling of optional args).

- **Cons**
  - **Breaks agent skill wiring**:
    - Deletes `shimmy-tool-oc` SKILL and its manifest entry, so agents lose dedicated oc guidance.
  - **Removes oc from product surface**:
    - Drops oc rows from `README.md`, and from `status-shimmy.sh` and `update-shimmy.sh`. That makes oc invisible to users and to `shimmy update`.
  - **Removes critical tests**:
    - Loses tests that assert dispatcher behavior and update wiring for oc.
  - **Breaks smoke config semantics**:
    - Drops `smoke_env` support in `test_shim_smoke_run` and removes `smoke_env` from docs, but does not add a robust alternative. Oc smoke depends on env, so this is a regression.
  - **Touches unrelated SKILL content**:
    - Trims opnsense MCP admin SKILL guidance without this being part of the oc plan.

### gemini-flash

- **Pros**
  - **Partial repair over gpt5.1-high**:
    - Adds oc_smoke configs (`shims/oc*.conf`) with smoke commands, and sets `SHIMMY_OC_VERSION` in `test_shim_smoke_run`, so `shimmy test` is less likely to fail for oc.
  - **Improved oc dispatcher script**:
    - Cleaner `case` + `exec` per version, better error text.
  - **User-centric docs for oc**:
    - `docs/shims/oc.md` includes upstream README references and common commands; helpful for human readers.

- **Cons**
  - Inherits **all of gpt5.1-high’s scope regressions**:
    - Still no oc SKILL manifest, no README entries, no status/update wiring.
    - Still removes `smoke_env` from generic docs.
  - **Misuses smoke_arg semantics**:
    - Uses `smoke_arg=version --client` which, given how `test_shim_smoke_run` builds commands, passes a single argument `version --client` instead of two arguments (`version` and `--client`). This contradicts the “use repeated `smoke_arg=` lines” guidance and will likely produce odd behavior.
  - Still modifies unrelated `opnsense` SKILL guidance.

---

## Why codex looks more thorough

From the diffs:

- **codex consistently followed the “update everything together” rule** that your oc SKILL already states:

  > Update runtime shims, configs, catalog/status/update wiring, docs, README, and tests together when behavior changes.

- **gpt5.1-high and gemini-flash focused on the shims & oc.md**, but:
  - Dropped SKILL and manifest entries.
  - Dropped README/`status`/`update` wiring.
  - Simplified or removed tests instead of extending them.
  - Touched unrelated guidance (opnsense, global smoke_env behavior).

So codex is “more thorough” because it treated oc as a **first-class shim** integrated into the whole Shimmy surface (skills, docs, tests, install/update), while the others treated it more as a narrow code change.

---

## Lessons learned: guidance to add to Shimmy agent skills

Based on what went wrong in `gpt5.1-high` and `gemini-flash`, here’s concrete guidance you can bake into Shimmy skills (especially the generic shim skill and `shimmy-tool-oc`):

### 1. Explicit “new/changed shim integration checklist”

In the generic Shimmy tool‑creation skill (and/or `docs/prompt-shimmy-project.md`), add a checklist like:

- **When you add or change a shim `<name>` you MUST consider:**
  - `shims/<name>` and `shims/<name>.conf`
  - If multi-version: dispatcher shim and versioned shims (`shims/oc`, `shims/oc_4_18`, etc.)
  - `docs/shims/<name>.md` (and any per-version docs if the pattern uses them)
  - Top-level shim table in `README.md`
  - `scripts/status-shimmy.sh` description in `describe_shim_image`
  - `scripts/update-shimmy.sh` pull/refresh behavior (where applicable)
  - `scripts/test-shimmy.sh`:
    - shim-specific tests
    - `test_shim_smoke_run` behavior if smoke semantics change
  - `.agents/skills/<skill>/SKILL.md` and `.agents/skills/.shimmy-skills-manifest.txt`, if this shim has a skill

Add this rule:

- **For each item above, either update it or explicitly state why no change is needed.**

### 2. Protect global invariants and minimize scope creep

Add to generic skills:

- **Do not modify unrelated skills or shims** (e.g., opnsense SKILL guidance, jq testing rules) unless:
  - The plan explicitly calls for it, **and**
  - You update all affected docs/tests consistently.

- **Do not remove existing wiring** (README entries, status/update coverage, SKILL manifest entries) for a shim unless the plan explicitly says that shim is being removed.

This would have prevented:
- `opnsense` SKILL trimming.
- oc disappearing from README/status/update while still existing as a shim.

### 3. Clarify smoke config semantics (smoke_arg vs smoke_env)

In `docs/templates/generic-shim/SKILL.md` (and skills that talk about testing):

- **Reinforce:**
  - `smoke_arg=...` is **one shell argument**.
  - Multi-argument smoke commands must use **multiple `smoke_arg=` lines**.
  - Example for oc:

    ```text
    # oc.conf
    shim_config_version=1
    shim_name=oc
    smoke_env=SHIMMY_OC_VERSION=4.20
    smoke_arg=--preview-shim
    smoke_arg=version
    ```

- **Explicitly retain `smoke_env` guidance**:
  - Keep text similar to:  
    “Use `smoke_env=KEY=value` only when a shim needs a non-secret selector or test-mode variable (like a version dispatcher selector) for a non-mutating smoke command.”

This would steer models away from `smoke_arg=version --client` and toward the correct multi-line pattern.

### 4. Keep selector env out of generic harness when possible

In `scripts/test-shimmy.sh` guidance (and skills that reference it):

- State that **selector env like `SHIMMY_OC_VERSION` should come from shim config (`smoke_env`) or the calling context, not hard-coded into the generic test harness**.
- That avoids the gemini pattern of baking oc-specific behavior into `test_shim_smoke_run`.

### 5. Preserve and extend tests, don’t silently drop them

In the `shimmy-tool-oc` SKILL (and generic testing notes), add:

- When changing dispatcher behavior:
  - **Update** oc tests (`missing version`, `unsupported version`, `preview`, `install+smoke`, `update pull coverage`) to match new behavior.
  - **Do not delete these tests** unless they are replaced with equivalent coverage.

This pushes models toward codex’s style of explicit, focused tests rather than deletions.

---

## Status

- **Plan**: Use `/compare-3-branches` to analyze `codex`, `gpt5.1-high`, and `gemini-flash`, then explain pros/cons and lessons learned.
- **Review**: Diffs show codex keeps full integration & tests; the others narrow scope and introduce regressions (especially around SKILLs, README/status/update wiring, smoke config semantics, and unrelated changes).
- **Act**: Completed the comparison and produced concrete guidance items you can add to Shimmy skills and prompts.

If you’d like, the next step could be: I draft specific text patches for `docs/prompt-shimmy-project.md` and `shimmy-tool-oc/SKILL.md` that encode this checklist and these invariants.