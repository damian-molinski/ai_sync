bin := "ai_sync"
entry := "bin/ai_sync.dart"
install_dir := home_dir() / "bin"

# List available recipes
default:
    @just --list

# Compile a native binary to ./ai_sync
build:
    dart compile exe {{ entry }} -o {{ bin }}

# Build and copy binary to ~/bin/ (ensure ~/bin is on your PATH)
install: build
    mkdir -p {{ install_dir }}
    cp {{ bin }} {{ install_dir }}/{{ bin }}
    @echo "Installed to {{ install_dir }}/{{ bin }}"

# Run all tests
test:
    dart test

# Run static analysis
analyze:
    dart analyze

# Format all Dart files (page width from analysis_options.yaml)
format:
    dart format .

# Apply automated fixes
fix:
    dart fix --apply

# Remove compiled binary
clean:
    rm -f {{ bin }}

# ── Examples ──────────────────────────────────────────────────────────────────

# Sync everything — all types, all providers (zero-config)
example-all:
    dart run {{ entry }} ./example/shared-ai

# Sync everything to global provider dirs
example-all-global:
    dart run {{ entry }} ~/shared-ai --global

# Sync only rules for Claude and Copilot
example-rules:
    dart run {{ entry }} ./example/shared-ai --providers claude,copilot --type rules

# Sync only context for Claude
example-context:
    dart run {{ entry }} ./example/shared-ai --providers claude --type context

# Sync skills for all providers (global)
example-skills-global:
    dart run {{ entry }} ~/shared-ai --type skills --global

# Sync agents for Claude and Gemini
example-agents:
    dart run {{ entry }} ./example/shared-ai --providers claude,gemini --type agents
