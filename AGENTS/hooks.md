```javascript
/**
 * =================================================
 * @file hooks.md - claude hook events documentation
 * =================================================
 * @description
 * - hooks are commands, prompts, agents, or http calls
 * - the ai *harness* runs hooks *deterministically*
 * - hooks receive json on stdin and can return json on stdout
 * - entries include rarity, uses, and examples
 * - rarity: common, situational, rare
 * - `update-config` skill contains full schema
 * - full docs at https://code.claude.com/docs/en/hooks
 * @see AGENTS.md, /AGENTS/hooks/, .claude/settings.json
 */
```

# Claude Hook Events Documentation

## Currently Implemented Hooks

### `"SessionStart": [],`
- rarity: common
- trigger: session begins, resumes, or continues after `/clear` (works on unarchive)
- runs: before you've typed anything
- use: proactively seed state rather than scrambling to backfill it later
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/sessionstart.sh" }]
```

### `"Stop": [],`
- rarity: common
- trigger: the agent tries to end its turn
- use: delegate via `decision: "block"` + `reason`
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/stop.sh", "timeout": 10 }]
```

### `"TaskCompleted": [],`
- rarity: common
- trigger: a task is marked done
- use: delegate via `decision: "block"` + `reason`
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/taskcompleted.sh" }]
```

### `"TaskCreated": [],`
- rarity: rare
- trigger: a `TaskCreate` call registers a new task in-session
- use: `additionalContext`, not `decision:"block"` — confirmed live that blocking this event prevents the creation itself, unlike `TaskCompleted`
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/taskcreated.sh" }]
```

### `"PostToolUse": [],`
- rarity: common
- trigger: after a tool succeeds; filter with `matcher` (tool name or `Tool1|Tool2`)
- use: the standard "run a formatter after every edit" hook — `eslint --fix`, not `prettier`, since prettier was installed but never configured (see `AGENTS/logs/2026-07-17.md`)
```json
"matcher": "Write|Edit", "hooks": [{ "type": "command", "command": "AGENTS/hooks/posttooluse.sh", "timeout": 30 }]
```

## Unused Hooks

### Session lifecycle 

#### `"SessionEnd": [],`
- rarity: situational
- trigger: session actually terminates — after the final turn, right before process exit; 
- matchers: `prompt_input_exit`, `clear`, `logout`, `bypass_permissions_disabled`, `resume`, `other` 
- runs: with no live turn, ever — stdout goes to system logs, not back to the model
- use: killing a lingering `dev`/`preview` server, removing an orphaned `EnterWorktree` worktree. 
- not: for writing summaries/logs — there's no reasoning available (see `AGENTS/logs/2026-07-15.md`)
```json
"matcher": "prompt_input_exit", "hooks": [{ "type": "command", "command": "AGENTS/hooks/sessionend.sh" }]
```

#### `"Setup": [],`
- rarity: rare
- trigger: first-run/provisioning, not a per-session event
- use: verify required tooling (`jq`, `gh`) is on `PATH` before anything else runs
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/setup.sh" }]
```

### Turns

#### `"UserPromptSubmit": [],`
- rarity: common
- trigger: every prompt you submit, before the model sees it
- use: inject `additionalContext` (e.g. current git branch) or block the prompt outright
- tried and abandoned here: capturing prompts for `AGENTS/prompts.md` — can't block-and-retry, so it silently missed 3 real prompts; capture moved to `Stop` instead (see `AGENTS/logs/2026-07-17.md`)
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/userpromptsubmit.sh" }]
```

#### `"UserPromptExpansion": [],`
- rarity: rare
- trigger: a typed shortcut (slash command or `@trigger`) expands into full prompt text
- use: audit which trigger actually fired
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/userpromptexpansion.sh" }]
```

#### `"StopFailure": [],`
- rarity: rare
- trigger: a turn ends due to an api error (rate limit, overload, auth, billing, etc.) — NOT a broken `stop.sh`, confirmed via real docs (see `AGENTS/logs/2026-07-17.md`)
- runs: display-only, no live turn — `decision`/`reason`/`additionalContext`/`systemMessage` are all ignored, exit code doesn't matter
- use: side effects only — log the `error_type` to a file for later review
- not: for detecting a broken enforcement hook — no event covers that; the harness's own "Ran N hooks" UI indicator is the closest native signal
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/stopfailure.sh" }]
```

#### `"Notification": [],`
- rarity: situational
- trigger: os-level notification events (e.g. a permission prompt is waiting on you)
- use: custom alerting if you step away mid-session
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/notification.sh" }]
```

#### `"MessageDisplay": [],`
- rarity: rare
- trigger: an assistant message is about to render in the ui
- use: observational logging, not something you block on — least documented of the turn events
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/messagedisplay.sh" }]
```

### Tools

#### `"PermissionRequest": [],`
- rarity: situational
- trigger: before the permission prompt shows, per tool call
- use: pre-decide `allow`/`deny`/`ask` via `permissionDecision`, skipping the prompt for cases you trust
```json
"matcher": "Bash", "hooks": [{ "type": "command", "command": "AGENTS/hooks/permissionrequest.sh" }]
```

#### `"PermissionDenied": [],`
- rarity: rare
- trigger: a permission request was denied, by you or a rule
- use: notice when your `permissions.deny` rules fire more than expected
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/permissiondenied.sh" }]
```

#### `"PreToolUse": [],`
- rarity: common
- trigger: before any tool executes; filter with `matcher` (tool name or `Tool1|Tool2`)
- use: block via `permissionDecision: "deny"`, or rewrite the call via `updatedInput`
```json
"matcher": "Bash", "hooks": [{ "type": "command", "command": "AGENTS/hooks/pretooluse.sh" }]
```

#### `"PostToolUseFailure": [],`
- rarity: situational
- trigger: a tool call errors instead of succeeding
- use: capture failure context you'd otherwise have to scroll back for
```json
"matcher": "Bash", "hooks": [{ "type": "command", "command": "AGENTS/hooks/posttoolusefailure.sh" }]
```

#### `"PostToolBatch": [],`
- rarity: rare
- trigger: a batch of parallel tool calls finishes, rather than per-call
- use: avoid running an expensive check (e.g. a full lint) once per file in a multi-edit batch
```json
"matcher": "Edit", "hooks": [{ "type": "command", "command": "AGENTS/hooks/posttoolbatch.sh" }]
```

### Subagents

#### `"SubagentStart": [],`
- rarity: situational
- trigger: a `Task`-spawned subagent begins
- use: log which agent type ran and why, independent of the main session's log
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/subagentstart.sh" }]
```

#### `"SubagentStop": [],`
- rarity: situational
- trigger: a subagent finishes — the subagent-scoped analog of `Stop`
- use: enforce the same "leave a note before you're done" pattern per-subagent
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/subagentstop.sh" }]
```

### Context

#### `"PreCompact": [],`
- rarity: situational
- trigger: before context gets summarized (`matcher`: `"manual"` or `"auto"`)
- use: last guaranteed look at full context before it's condensed
```json
"matcher": "auto", "hooks": [{ "type": "command", "command": "AGENTS/hooks/precompact.sh" }]
```

#### `"PostCompact": [],`
- rarity: situational
- trigger: after compaction completes; receives the generated summary
- use: auto-append the summary to today's log so compaction isn't invisible in your history
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/postcompact.sh" }]
```

### Elicitation & multi-agent (only relevant if you use MCP servers or teammates)

#### `"Elicitation": [],`
- rarity: rare
- trigger: a connected mcp server asks the user for input mid-call
- use: only relevant if you're actively using mcp servers that elicit
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/elicitation.sh" }]
```

#### `"ElicitationResult": [],`
- rarity: rare
- trigger: you respond to an elicitation request
- use: pairs with `Elicitation` for an audit trail
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/elicitationresult.sh" }]
```

#### `"TeammateIdle": [],`
- rarity: rare
- trigger: a spawned teammate (multi-agent feature) goes idle waiting on you
- use: push a notification so a background teammate doesn't stall unnoticed
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/teammateidle.sh" }]
```

### Environment

#### `"ConfigChange": [],`
- rarity: situational
- trigger: `settings.json`/config changes are detected and applied
- use: lightweight audit trail of who changed what, when
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/configchange.sh" }]
```

#### `"WorktreeCreate": [],`
- rarity: rare
- trigger: a new git worktree is created (`--worktree`, `EnterWorktree`, or agent isolation)
- use: only relevant once you start using worktrees for parallel agent work
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/worktreecreate.sh" }]
```

#### `"WorktreeRemove": [],`
- rarity: rare
- trigger: a worktree is torn down
- use: pairs with `WorktreeCreate` for cleanup
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/worktreeremove.sh" }]
```

#### `"InstructionsLoaded": [],`
- rarity: situational
- trigger: `AGENTS.md`/`CLAUDE.md`-style instruction files are loaded into context
- use: debug "why isn't my `AGENTS.md` rule being followed" — confirms the file was actually read
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/instructionsloaded.sh" }]
```

#### `"CwdChanged": [],`
- rarity: rare
- trigger: the working directory changes mid-session
- use: re-validate you're still inside the expected project root
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/cwdchanged.sh" }]
```

#### `"FileChanged": [],`
- rarity: situational
- trigger: a watched file changes on disk outside of Claude's own `Write`/`Edit`
- use: catch drift between what Claude thinks a file says and what's actually on disk
```json
"hooks": [{ "type": "command", "command": "AGENTS/hooks/filechanged.sh" }]
```
