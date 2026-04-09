Run housekeeping cleanup across all Claude Code projects and the home directory.

Check and report on each area, then ask before making changes:

1. **Scratch files**: List stale task directories in `~/.claude/projects/-home-jp/scratch/`. Delete old ones, keep HANDOFF.md if resuming.
2. **Memories**: Check `memory/MEMORY.md` for entries that duplicate CLAUDE.md or reference deleted features. Flag for removal.
3. **Worktrees**: For each project with `.claude/worktrees/`, run `git worktree list` and `git worktree prune` if stale entries exist.
4. **Git branches**: For each git project, list branches merged into main/master with `git branch --merged`. Flag for cleanup.
5. **settings.local.json bloat**: For each project, count allow rules. Flag any over 50 rules and identify obvious stale patterns (dead PIDs, one-shot commands, worktree agent refs).
6. **Stale files**: Check for `.playwright-mcp/` directories, orphaned `__pycache__/`, `.pid` files for dead processes.
7. **.claudeignore**: Verify entries reference existing files. Flag projects missing .claudeignore that have build output or large binaries.

Present a summary table, then ask which items to clean up. Use Davis narrator voice for status updates.
