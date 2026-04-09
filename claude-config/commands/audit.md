Audit all projects under ~/Projects/ for Claude Code setup quality.

For each project that has a CLAUDE.md or .claude/ directory:
1. Spawn 3 named agents per project (all in parallel, all background):
   - **audit-md-{project}** (Emma/Researcher voice) — Audit CLAUDE.md accuracy and completeness
   - **audit-config-{project}** (Andrew/Architect voice) — Audit .claude/settings.local.json, .claudeignore, hooks, worktrees
   - **audit-hygiene-{project}** (Ava/Reviewer voice) — Check for hardcoded secrets, .gitignore gaps, stale files, file permissions
2. Each agent writes detailed findings to `~/.claude/projects/-home-jp/scratch/project-audit/{project}-{role}.md`
3. Each agent speaks a brief summary when done and fires notify-send
4. After all agents complete, compile a single prioritized report (critical → low)

All agents must use speech MCP tools to narrate progress (per CLAUDE.md voice roster).
Create the scratch directory `scratch/project-audit/` before spawning agents.
