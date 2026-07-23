#!/bin/bash
# ==============================================
# @file pretooluse.sh - pretooluse hook script
# ==============================================
# @description
# - runs before a Bash tool call executes, can block it
# - inspects the FULL command string, not just its prefix, so it
#   catches destructive git flags that prefix deny-rules miss
# - blocks force pushes and force branch deletes wherever the flag sits
# - silent (exit 0) for everything else, never blocks non-git commands
# @see AGENTS.md, .claude/settings.local.json

CMD=$(jq -r '.tool_input.command // .toolInput.command // empty')

# nothing to inspect
[ -z "$CMD" ] && exit 0

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# force push: `git push` present AND a -f / --force[...] flag token anywhere
if printf '%s' "$CMD" | grep -Eq '(^|[[:space:]])git[[:space:]]+push([[:space:]]|$)'; then
  if printf '%s' "$CMD" | grep -Eq '(^|[[:space:]])(-f|--force[^[:space:]]*)([[:space:]]|$)'; then
    deny "blocked by pretooluse hook: force push detected. run it yourself if you really mean to."
  fi
fi

# force branch delete: `git branch` present AND -D, or --delete together with --force
if printf '%s' "$CMD" | grep -Eq '(^|[[:space:]])git[[:space:]]+branch([[:space:]]|$)'; then
  if printf '%s' "$CMD" | grep -Eq '(^|[[:space:]])-D([[:space:]]|$)'; then
    deny "blocked by pretooluse hook: force branch delete (-D) detected. run it yourself if you really mean to."
  fi
  if printf '%s' "$CMD" | grep -Eq '(^|[[:space:]])--delete([[:space:]]|$)' \
     && printf '%s' "$CMD" | grep -Eq '(^|[[:space:]])(-f|--force)([[:space:]]|$)'; then
    deny "blocked by pretooluse hook: force branch delete (--delete --force) detected. run it yourself if you really mean to."
  fi
fi

exit 0
