# dotfiles-claude

Personal [Claude Code](https://docs.anthropic.com/en/docs/claude-code) configuration: settings, hooks, skills, and agents.

Supports **Windows** (Git Bash + Windows Terminal) and **Linux / macOS**.

---

## Install

### Windows

Prerequisites: [Git for Windows](https://git-scm.com/download/win) (provides `bash`), [`jq`](https://jqlang.github.io/jq/), [`uv`](https://docs.astral.sh/uv/).

```powershell
git clone git@github.com:anthosq/dotfiles-claude.git
cd dotfiles-claude
powershell -ExecutionPolicy Bypass -File setup-windows.ps1
```

The script checks prerequisites, creates a full timestamped backup of your existing `~/.claude` to `~/.claude-backups/<timestamp>/`, copies all configuration, and runs verification checks. Restart Claude Code after setup.

**Restore:**

```powershell
# Restore latest backup (interactive)
powershell -ExecutionPolicy Bypass -File restore-windows.ps1

# Restore a specific backup
powershell -ExecutionPolicy Bypass -File restore-windows.ps1 -BackupName 20260522-013330
```

### Linux / macOS

Prerequisites: `bash`, `jq`, `uv`.

```bash
curl -fsSL https://raw.githubusercontent.com/anthosq/dotfiles-claude/main/setup.sh | bash
```

Idempotent — re-run anytime to pull updates.

---

## Production Workflow (SOP)

### Starting a task

Open a Claude Code session in your project directory. The `inject-git-status` and `inject-time` hooks automatically provide current branch state and timestamp as context on every message.

For **long-running or compute-intensive tasks** (builds, scrapes, training runs, large refactors), load the babysit skill first:

```
/babysit
```

Then describe your task. Babysit wraps the work in a supervised background runner with memory/CPU caps and stall detection.

### Letting hint hooks guide you

Hooks detect patterns and suggest the right tool automatically:

- Mention a URL → hint to load `/read-url` or `/jina-ai`
- Ask about Claude Code features → `claude-code-guide` agent spawned
- Task involves surveying many files → hint to fork a subagent
- Long task detected → hint to load `/babysit`

You can also load skills explicitly at any time:

```
/jina-ai            # web search, academic papers
/context7           # fetch live library docs before coding
/review             # code review after a big change
/memory-add         # save a durable fact or lesson
```

### Mid-task: memory and recall

The `recall-reminder` hook periodically nudges Claude to check long-term memory pages before starting each task. If a task surfaces a durable fact, correction, or lesson:

```
remember: always use robocopy instead of Copy-Item for directory sync on Windows
```

Claude will invoke `/memory-add` to append it to staging memory.

### Code review and audit

After a significant set of edits, trigger a review:

```
/review
```

This runs a focused agent checking for bugs, AI slop patterns, and documentation issues, then proposes fixes interactively.

The **audit stop hook** fires automatically when Claude finishes a session that involved multiple file edits. It runs a headless `claude-opus-4-6` instance that reviews all changed files and reports back if it finds issues — no manual trigger needed.

View audit history:

```bash
~/.claude/hooks/audit-edits.py stats
```

### Parallel and multi-session work

Use the `claude-dm` skill to coordinate multiple Claude Code sessions (e.g. one session per subproject, or a supervisor orchestrating workers):

```
/claude-dm
```

### Wrapping up

Before ending a long session, confirm the audit hook ran (it fires on `Stop` automatically). If the session involved architectural decisions or resolved a tricky bug:

```
remember: <the lesson>
```

---

## What's Included

### settings.json

- **`permissions.defaultMode: "bypassPermissions"`** — no confirmation modals; safety enforced by hooks
- **`autoScrollEnabled: true`** — output auto-scrolls as it streams
- Audit hook env vars (`AUDIT_BACKEND`, `AUDIT_CLAUDE_MODEL`)

### hooks/ — 40 hooks

Hooks fire across `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`, and `PostCompact`.

**Safety guardrails** (`no-*.sh`) — soft blocks with explicit bypass escape hatches:

| Hook | Blocks |
|---|---|
| `no-dangerous-ops` | mkfs, dd, partition edits, writes to `/dev` `/sys` `/boot` |
| `no-destructive-git` | `git push --force`, `git clean -f`, branch delete |
| `no-git-amend` | `git commit --amend` |
| `no-heredoc` | heredoc writes (use the Write tool instead) |
| `no-head-read` | `head`/`tail` on files (use the Read tool) |
| `no-head-tail-pipe` | piped `head`/`tail` truncation |
| `no-devnull-redirect` | `2>/dev/null` suppression |
| `no-sed-print` | `sed` as a file writer |
| `no-pip-npm` | `pip install` / `npm install` (use `uv`/`pnpm`) |
| `no-background-ampersand` | bare `&` background jobs |
| `no-cat-write` | `cat >` file writes |
| `no-multi-question` | asking user multiple questions at once |
| `no-schedule-wakeup-deadzone` | ScheduleWakeup during waking hours |
| `no-worktree-team` | unsafe worktree/team operations |

All gates are soft reminders. `# BYPASS_*_CHECK` markers let Claude override one specific gate when legitimately needed — they prevent accidents, not intentional actions.

**Context injectors** (run on every prompt):
- `inject-time.sh` — current datetime
- `inject-git-status.sh` — working-tree status
- `inject-system-load.sh` — CPU/memory load

**Hint hooks** (pattern-triggered skill suggestions):
- `hint-skill-babysit`, `hint-skill-jina-ai`, `hint-skill-read-url`
- `hint-agent-claude-code-guide`, `hint-fork-on-bloat`

**Other hooks:**
- `recall-reminder` / `recall-reminder-reset` — periodic memory recall nudges
- `prefer-uv-run`, `python-unbuffered` — enforce Python toolchain conventions
- `audit-edits.py` — stop hook that reviews edits for correctness and AI slop
- `cache-keepalive-hint`, `compact-bump`, `explore-model-sonnet`, and more

### skills/ — 52 skill packs

| Skill | Purpose |
|---|---|
| `babysit` | Supervised long-running background tasks with resource caps |
| `jina-ai` | Web search, academic papers, PDF extraction, embeddings |
| `read-url` | Extract clean markdown from any web page |
| `context7` | Fetch up-to-date library docs before writing code |
| `chrome-cdp` | Headful browser automation via user's real Chrome session |
| `agent-browser` | Headless browser for UI testing and screenshots |
| `canvas-design` | Generate PNG/PDF visual design artifacts |
| `evolink-image` | AI image generation and editing |
| `frontend-design` | Build distinctive web UI, avoiding AI slop aesthetics |
| `claude-dm` | Peer-to-peer messaging between Claude Code sessions |
| `tmux` | Interactive TUI/REPL sessions in tmux panes |
| `memory-add` | Append durable facts or lessons to long-term memory |
| `review` | Code review for bugs, AI slop, and documentation |
| `pdf` | Read, extract, merge, annotate PDF files |
| `docx` / `pptx` | Create and edit Word / PowerPoint documents |
| `openscad` | Generate and render 3D models |
| `shader-dev` | GLSL shaders — ray marching, SDF, particles |
| `zhihu-post` | Chinese technical blog posts for 知乎 |
| `better-translate` | Natural-voice English→Chinese translation |
| `skill-creator` | Create, edit, and benchmark new skills |
| `grep-app` | Code search across public GitHub repos |
| `repo-cache` | Clone and browse remote git repos locally |
| `fresh-arch` | Architecture design from first principles |

Full list: `ls ~/.claude/skills/`

### agents/ — 5 specialized agents

| Agent | Role |
|---|---|
| `audit-fresh-eye` | Independent code/doc audit from a clean perspective |
| `web-researcher` | Deep web research with Jina AI and WebSearch |
| `claude-code-guide` | Answers questions about Claude Code features and API |
| `code-review` | Focused code quality review |
| `doc-review` | Documentation correctness and clarity review |

### CLAUDE.md

Global rules injected into every session: preferred CLI tools (`rg`, `fd`, `eza`, `uv`, `pnpm`, `just`), coding discipline (smoke-test first, investigate before concluding, no band-aids), output style (one claim, ≤40 words), degree-of-automation levels (low / medium / high), and long-term memory conventions.

---

## Audit Hook

A `Stop` hook fires automatically after sessions involving file edits, reviewing all changes for correctness and AI slop patterns.

The reviewer is a headless `claude` instance running **claude-opus-4-6**. When it flags issues, it reports back to the main session.

Configure in `settings.json`:

```json
"AUDIT_BACKEND": "claude",     // none | claude
"AUDIT_CLAUDE_MODEL": "claude-opus-4-6"
```

---

## Defaults Worth Knowing

**`bypassPermissions`** — Claude acts without per-tool confirmation modals. The safety layer is the hook gates above. Prompts without genuine judgment behind them are just attention tax; the gates catch the accidents that matter.

To restore standard prompts: set `"defaultMode": "default"` in `settings.json`.

**Memory system** — `memory/` holds long-term memory pages, a staging buffer, and pitfall entries. Claude reads relevant pages before each task and appends via `/memory-add`. See `memory/BUILD.md` for maintenance.

**Windows compatibility** — All hooks run in Git Bash (MSYS2). PCRE patterns fall back to a `perl`-based shim (`hooks/lib/pcre-compat.sh`) when `grep -P` is unavailable. `audit-edits.py` uses a cross-platform lock and temp-dir strategy.
