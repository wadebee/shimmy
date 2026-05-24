Revised Plan

Inventory current managed shims and existing agent skills, excluding tessl.
Target shims: aws, go, jq, netcat, nmap, opnsense-mcp-server, rg, task, terraform, textual.

Realign tool skill naming to the new convention:

.agents/skills/aws -> .agents/skills/shimmy-tool-aws
.agents/skills/jq -> .agents/skills/shimmy-tool-jq
.agents/skills/rg -> .agents/skills/shimmy-tool-rg
.agents/skills/terraform -> .agents/skills/shimmy-tool-terraform
existing .agents/skills/shimmy-tool-opnsense-mcp remains the shortened canonical name for opnsense-mcp-server.
Create new canonical tool skills for shims without one:

shimmy-tool-go
shimmy-tool-netcat
shimmy-tool-nmap
shimmy-tool-task
shimmy-tool-textual
Refactor all tool skill contents into a uniform structure based on shimmy-tool-opnsense-mcp/SKILL.md, while preserving tool-specific requirements such as mounts, env forwarding, stdin/TTY mode, secrets, image overrides, safety constraints, and validation commands.

Add or normalize ## Learning Guidance in every canonical tool skill, focused on capturing lessons from future work on that tool. Reusable cross-tool lessons should be promoted back into shimmy-create.

Update .agents/skills/shimmy-create/SKILL.md so future shim creation requires:

creating a matching .agents/skills/shimmy-tool-{toolname}/SKILL.md
using shortened canonical names where appropriate
deriving behavior from shim, docs, tests, installer, and README
recording tool-specific lessons under the new tool skill’s Learning Guidance
recording reusable shim-design lessons under shimmy-create’s Learning Guidance
Check whether packaged plugin copies under plugins/shimmy/skills/ need matching renames or content sync for jq/rg and update them if they are intended to mirror repo-local skills.

Verify with non-mutating checks:

expected skill directories exist
no stale canonical tool skills remain under old names unless intentionally retained
all canonical tool skills have valid frontmatter and Learning Guidance
references to tessl are not introduced into new tool skill guidance
shimmy-create points future agents at the new naming convention.
Execution Approach

I’ll do this in passes: first inventory and rename/refactor existing skills, then create missing skills, then wire shimmy-create, then verify and tighten consistency. If context gets tight, I’ll pause after a clean pass with a concise status and continue from the verified state.

Reply proceed or implement to approve this revised plan.