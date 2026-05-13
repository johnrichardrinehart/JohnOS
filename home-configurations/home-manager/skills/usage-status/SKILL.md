---
name: usage-status
description: Show weekly Codex usage pace and catch-up ETAs via codex-weekly-pace.
---

# Usage Status

Use this skill when the user asks about Codex weekly usage pace, over/under status, or catch-up ETAs.

Run:

```bash
if [ -n "${ARGUMENTS:-}" ]; then
  codex-weekly-pace ${ARGUMENTS}
else
  codex-weekly-pace
fi
```

Examples:

- `$usage-status`
- `$usage-status --watch`
- `$usage-status --interval 15`
