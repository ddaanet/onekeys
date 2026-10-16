## Remaining

- Check the gitlore hooks dir is no longer stale after the restart (`git config gitlore.hooksDir`, then a read-only `resolve.sh` check); the v0.3.5 release output still printed `gitlore skipped: hooks dir is stale`.
- Compact memory/MEMORY.md (~25.6KB) and memory/ddaanet/MEMORY.md (~24.5KB) below Claude Code's 24.4KB load cap with /gitlore:index-audit, as a retirement/relocation pass per the index-compaction-triggers fact.