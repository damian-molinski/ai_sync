# ai_sync

A Dart CLI that reads AI agent configuration from a canonical source directory and generates provider-specific files for **GitHub Copilot**, **Google Gemini CLI**, **Google Antigravity**, and **Anthropic Claude Code**.

Compile once to a native binary, place on PATH, and call from any repository.

---

## Installation

```bash
just build    # compiles ./ai_sync
just install  # builds and copies to ~/bin/
```

Requires Dart SDK ≥ 3.11 and [`just`](https://github.com/casey/just).

---

## Source directory layout

Pass `<source>` as the first argument, pointing to any directory that follows this structure:

```
<source>/
├── CONTEXT.md              # Shared instructions for all providers (plain markdown)
├── rules/
│   └── *.md                # Rule files with YAML frontmatter
├── agents/
│   └── *.md                # Agent definition files with YAML frontmatter
└── skills/
    └── {skill-name}/
        ├── SKILL.md
        └── ...             # Any additional files
```

Missing subdirectories are skipped with a warning — only `CONTEXT.md` is required for `instructions`.

---

## Usage

```
ai_sync <source> [--providers <list>] [--type <list>] [--global] [--mode <mode>] [--log <level>]

Arguments:
  <source>              Path to canonical source directory (required)

Options:
  -p, --providers       Comma-separated providers to sync (default: all)
                        Available: copilot, claude, gemini, antigravity
  -t, --type            Comma-separated sync types (default: all)
                        Available: context, rules, skills, agents
  -g, --global          Write to provider global config dirs (~/) instead of workspace
  -m, --mode            Sync mode (default: soft)
                        soft: never deletes existing output (safe default)
                        hard: removes stale output when source resource is deleted;
                              also removes now-empty output directories
  -l, --log             Minimum log level (default: info)
                        Available: all, finest, finer, fine, config, info, warning, severe, off
  -h, --help            Show usage
```

### Workspace sync (default)

Outputs land in the repository where you run the command.

```bash
# Sync everything — all types, all providers (zero-config)
ai_sync ./shared-ai

# Narrow to specific providers
ai_sync ./shared-ai --providers claude,copilot

# Narrow to specific types
ai_sync ./shared-ai --type rules,context

# Combine both
ai_sync ./shared-ai --providers claude --type rules

# Hard mode — delete stale outputs for resources removed from source
ai_sync ./shared-ai --mode hard

# Verbose output — show per-file details
ai_sync ./shared-ai --log fine

# Quiet — only warnings and errors
ai_sync ./shared-ai --log warning
```

### Global sync (`--global`)

Outputs land in the provider's user-level config directories (`~/.claude/`, `~/.gemini/`, etc.).

```bash
# Sync everything to global provider dirs
ai_sync ~/shared-ai --global

# Sync only rules globally for Claude
ai_sync ~/shared-ai --providers claude --type rules --global

# Sync only context globally for all providers
ai_sync ~/shared-ai --type context --global

# Hard mode — remove stale global outputs
ai_sync ~/shared-ai --global --mode hard
```

---

## Output paths

### `context` — CONTEXT.md symlinks

| Mode      | Symlink path                      | Provider              |
| --------- | --------------------------------- | --------------------- |
| Workspace | `GEMINI.md`                       | Gemini                |
| Workspace | `.github/copilot-instructions.md` | Copilot               |
| Workspace | `.claude/CLAUDE.md`               | Claude                |
| Global    | `~/.gemini/GEMINI.md`             | Gemini + Antigravity  |
| Global    | `~/.claude/CLAUDE.md`             | Claude                |

All symlink targets are absolute paths to `<source>/CONTEXT.md`.

### `rules`

| Provider     | Workspace                           | Global               |
| ------------ | ----------------------------------- | -------------------- |
| Copilot      | `.github/instructions/*.instructions.md` | —               |
| Antigravity  | `.agents/rules/*.md`                | —                    |
| Claude       | `.claude/rules/*.md`                | `~/.claude/rules/`   |
| Gemini       | *(not supported)*                   | —                    |

### `skills` — directory symlinks

| Provider     | Workspace              | Global                          |
| ------------ | ---------------------- | ------------------------------- |
| Copilot      | `.github/skills/`      | `~/.copilot/skills/`            |
| Claude       | `.claude/skills/`      | `~/.claude/skills/`             |
| Gemini       | `.gemini/skills/`      | `~/.gemini/skills/`             |
| Antigravity  | `.agents/skills/`      | `~/.gemini/antigravity/skills/` |

Each `{skill-name}` entry is a single directory symlink pointing to `<source>/skills/{skill-name}`. New files added to the source skill directory are reflected immediately without re-running `ai_sync`.

### `agents`

| Provider     | Workspace              | Global               |
| ------------ | ---------------------- | -------------------- |
| Copilot      | `.github/agents/*.md`  | —                    |
| Claude       | `.claude/agents/*.md`  | `~/.claude/agents/`  |
| Gemini       | `.gemini/agents/*.md`  | `~/.gemini/agents/`  |
| Antigravity  | *(not supported)*      | —                    |

---

## Canonical file formats

### Rule file

```yaml
---
description: "Brief description (informational only)"
paths:
  - "**/database/tables/*.dart"
  - "**/database/daos/*.dart"
---

# Rule Title

Rule body content...
```

- `paths: []` or missing `paths` → **always-on** (applies to all files)

### Agent file

```yaml
---
description: "What this agent does"
name: "Agent Name"
tools: [read, search, web, dart-sdk-mcp-server/pub_dev_search]
agents:
  [
    "Sub Agent One",
    "Sub Agent Two",
  ]
user-invocable: true
---

Agent system prompt here...
```

**Canonical tool mapping:**

| Canonical  | Claude Code        |
| ---------- | ------------------ |
| `read`     | `Read`             |
| `search`   | `Grep`, `Glob`     |
| `web`      | `WebFetch`         |
| `agent`    | `Agent`            |
| `vscode/*` | *(dropped)*        |
| anything else | pass through    |

The `agents` list is merged into Claude's `tools` field as `Agent(name)` entries. Copilot output preserves the original YAML array formatting byte-for-byte.

---

## Development

```bash
just analyze   # dart analyze
just test      # dart test
just build     # compile binary
just install   # build + copy to ~/bin/
just clean     # remove binary
just           # list all recipes
```

---

## CI & Releases

GitHub Actions is configured with two workflows:

- `CI` runs on every push to `main` and every pull request targeting `main`.
- `Release` runs when pushing a version tag matching `v*` (for example, `v1.0.0`).

Both workflows use a locked Dart SDK version: `3.11.0`.

### CI workflow process

The CI workflow executes:

1. `dart pub get`
2. `dart analyze --fatal-infos`
3. `dart test`
4. `dart compile exe bin/ai_sync.dart -o ai_sync`

This ensures each PR is validated for analysis, correctness, and buildability.

### Release workflow process

When a `v*` tag is pushed, the release workflow:

1. Builds a native binary named `ai_sync` for each target platform (`linux-x64` and `macos-arm64`)
2. Packages each binary as a platform archive: `ai_sync-linux-x64.tar.gz` and `ai_sync-macos-arm64.tar.gz`
3. Creates a GitHub Release and attaches those `.tar.gz` assets

To create a release:

```bash
git tag v1.0.0
git push --tags
```
