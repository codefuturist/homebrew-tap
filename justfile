# Homebrew Tap Justfile
# Migrated from Makefile to modular just-modules system

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration

# ═══════════════════════════════════════════════════════════════════════════════
# Imports
# ═══════════════════════════════════════════════════════════════════════════════

# Core (required)
import '.just-modules/core/mod.just'

# Automation & Project Management
import '.just-modules/traits/automation-helpers.just'
import '.just-modules/traits/env.just'

# Features
mod versioning '.just-modules/traits/versioning.just'
mod gitflow '.just-modules/traits/gitflow.just'
mod hooks '.just-modules/traits/hooks.just'
mod docs '.just-modules/traits/docs.just'
mod cog '.just-modules/traits/cocogitto.just'

# Code Quality & Refactoring
import '.just-modules/traits/ast-grep.just'
import '.just-modules/traits/megalinter.just'
import '.just-modules/traits/backup.just'

# Security & Encryption
import '.just-modules/traits/encryption.just'

# AI Features
import '.just-modules/traits/ai.just'

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

project_name := 'Homebrew Tap'

# Import language modules
mod python '.just-modules/languages/python/mod.just'

# Import features
mod security '.just-modules/traits/security.just'

# ═══════════════════════════════════════════════════════════════════════════════
# Default
# ═══════════════════════════════════════════════════════════════════════════════

default:
    @just --list --list-heading $'🍺 Homebrew Tap - Available commands:\n'

# ═══════════════════════════════════════════════════════════════════════════════
# Setup
# ═══════════════════════════════════════════════════════════════════════════════

# Complete project setup
[group('setup')]
setup:
    @just _header "Project Setup"
    @just python::deps
    @just _success "Setup complete!"

# ═══════════════════════════════════════════════════════════════════════════════
# Formula Management
# ═══════════════════════════════════════════════════════════════════════════════

# List all formulas
[group('formulas')]
list:
    @just _header "Available Formulas"
    @ls -1 Formula/*.rb | xargs -n1 basename | sed 's/.rb$//'

# Audit formulas
[group('formulas')]
audit:
    @just _header "Auditing Formulas"
    @for formula in Formula/*.rb; do echo "Auditing $$(basename $$formula)..." && brew audit --strict $$formula; done
    @just _success "Audit complete"

# Update formula version
[group('formulas')]
update-formula name version:
    @just _info "Updating formula: {{name}} to version {{version}}"
    @ruby scripts/update_formula.rb {{name}} {{version}}
    @just _success "Formula updated"

# Validate formula
[group('formulas')]
validate-formula name:
    @just _info "Validating formula: {{name}}"
    @brew audit --strict Formula/{{name}}.rb
    @just _success "Formula valid"

# Test formula installation
[group('formulas')]
test-install name:
    @just _info "Testing installation: {{name}}"
    @brew install --build-from-source Formula/{{name}}.rb
    @just _success "Installation test complete"

# ═══════════════════════════════════════════════════════════════════════════════
# Version Tracking
# ═══════════════════════════════════════════════════════════════════════════════

# Check for outdated formulas
[group('version')]
check-outdated:
    @just _header "Checking for Updates"
    @python3 scripts/check_versions.py

# Bump formula version
[group('version')]
bump-version name:
    @just _info "Bumping version for: {{name}}"
    @python3 scripts/bump_version.py {{name}}
    @just _success "Version bumped"

# ═══════════════════════════════════════════════════════════════════════════════
# Testing
# ═══════════════════════════════════════════════════════════════════════════════

# Run all tests
[group('test')]
test:
    @just audit
    @just _success "All tests passed"

# Lint Ruby formulas
[group('test')]
lint:
    @just _info "Linting formulas..."
    @rubocop Formula/*.rb || true

# ═══════════════════════════════════════════════════════════════════════════════
# Maintenance
# ═══════════════════════════════════════════════════════════════════════════════

# Clean artifacts
[group('maintenance')]
clean:
    @just _info "Cleaning..."
    @rm -rf *.bottle* tmp/
    @just _success "Cleaned"

# Show project info
info:
    @just _header "{{project_name}}"
    @just _kv "Tap" "codefuturist/tap"
    @just _kv "Version" "{{_git_tag}}"
    @just _kv "Branch" "{{_git_branch}}"
    @just _kv "Formulas" "$(ls -1 Formula/*.rb | wc -l | tr -d ' ')"

# ══════════════════════════════════════════════════════════════════════════════
# Just-Modules Management
# ══════════════════════════════════════════════════════════════════════════════

# Browse and interactively add just-modules to this project
[group('modules')]
modules-browse:
    @just _header "Available just-modules"
    @echo ""
    @echo "{{ BOLD }}{{ CYAN }}Language Modules:{{ NORMAL }}"
    @ls -1 .just-modules/languages/ 2>/dev/null | sed 's/^/  • /' || echo "  (none found)"
    @echo ""
    @echo "{{ BOLD }}{{ CYAN }}Traits/Features:{{ NORMAL }}"
    @ls -1 .just-modules/traits/*.just 2>/dev/null | xargs -n1 basename | sed 's/.just$//' | sed 's/^/  • /' || echo "  (none found)"
    @echo ""
    @echo "{{ BOLD }}{{ YELLOW }}To add a module, edit your justfile and add:{{ NORMAL }}"
    @echo "  {{ GREEN }}mod <name> '.just-modules/languages/<name>/mod.just'{{ NORMAL }}  # For languages"
    @echo "  {{ GREEN }}import '.just-modules/traits/<name>.just'{{ NORMAL }}              # For traits"
    @echo ""
    @echo "{{ BOLD }}Example - Add Go support:{{ NORMAL }}"
    @echo "  Add this line to your imports section:"
    @echo "  {{ CYAN }}mod go '.just-modules/languages/go/mod.just'{{ NORMAL }}"

# Show currently imported modules
[group('modules')]
modules-list:
    @just _header "Currently Imported Modules"
    @echo ""
    @echo "{{ BOLD }}Language Modules:{{ NORMAL }}"
    @grep "^mod .* '.just-modules/languages/" justfile | sed "s/^mod /  • /" | sed "s/ '.*//" || echo "  (none)"
    @echo ""
    @echo "{{ BOLD }}Trait Imports:{{ NORMAL }}"
    @grep "^import '.just-modules/traits/" justfile | sed "s/^import '.just-modules\/traits\//  • /" | sed "s/.just'.*//" || echo "  (none)"
    @echo ""
    @echo "{{ BOLD }}Trait Modules:{{ NORMAL }}"
    @grep "^mod .* '.just-modules/traits/" justfile | sed "s/^mod /  • /" | sed "s/ '.*//" || echo "  (none)"

# Update just-modules submodule to latest version
[group('modules')]
modules-update:
    @just _header "Updating just-modules"
    @just _info "Pulling latest from remote..."
    @cd .just-modules && git pull origin main
    @just _success "just-modules updated to latest version"

# Show just-modules submodule status
[group('modules')]
modules-status:
    @just _header "just-modules Submodule Status"
    @cd .just-modules && git log -1 --format="  {{ BOLD }}Commit:{{ NORMAL }} %h - %s" && git log -1 --format="  {{ BOLD }}Date:{{ NORMAL }}   %cr"
    @cd .just-modules && echo "  {{ BOLD }}Branch:{{ NORMAL }} $(git branch --show-current || echo 'detached')"
    @echo ""
    @cd .just-modules && git fetch origin --quiet && \
        LOCAL=$(git rev-parse HEAD) && \
        REMOTE=$(git rev-parse origin/main 2>/dev/null || echo "$LOCAL") && \
        if [ "$LOCAL" = "$REMOTE" ]; then \
            echo "  {{ GREEN }}✓ Up to date{{ NORMAL }}"; \
        else \
            echo "  {{ YELLOW }}⚠ Updates available{{ NORMAL }} (run: just modules-update)"; \
        fi
