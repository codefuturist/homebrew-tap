# Makefile for Homebrew Tap Management

.PHONY: help
help:
	@echo "Homebrew Tap Management Commands:"
	@echo "  make audit           - Audit all formulas"
	@echo "  make test            - Test formula installation"
	@echo "  make update          - Update all formulas to latest versions"
	@echo "  make update-packr    - Update Packr formula specifically"
	@echo "  make install-local   - Install formulas locally for testing"
	@echo "  make clean           - Clean up test installations"
	@echo "  make validate        - Validate all formulas and workflows"

.PHONY: audit
audit:
	@echo "Auditing formulas..."
	@for formula in Formula/*.rb; do \
		echo "Auditing $$(basename $$formula .rb)..."; \
		brew audit --strict --online $$formula || true; \
	done

.PHONY: test
test:
	@echo "Testing formula installation..."
	@export HOMEBREW_GITHUB_API_TOKEN=$$(gh auth token 2>/dev/null) && \
	brew install --build-from-source Formula/packr.rb

.PHONY: update
update:
	@echo "Updating all formulas..."
	@ruby scripts/update-formula.rb --verbose

.PHONY: update-packr
update-packr:
	@echo "Updating Packr formula..."
	@ruby scripts/update-formula.rb --formula packr --verbose

.PHONY: install-local
install-local:
	@echo "Installing formulas locally..."
	@export HOMEBREW_GITHUB_API_TOKEN=$$(gh auth token 2>/dev/null) && \
	brew tap-new local/test 2>/dev/null || true && \
	cp Formula/*.rb $$(brew --repository)/Library/Taps/local/homebrew-test/Formula/ && \
	brew install local/test/packr

.PHONY: clean
clean:
	@echo "Cleaning up..."
	@brew uninstall packr 2>/dev/null || true
	@brew untap local/test 2>/dev/null || true
	@rm -f *.tar.gz *.sha256

.PHONY: validate
validate:
	@echo "Validating tap..."
	@echo "Checking formula syntax..."
	@for formula in Formula/*.rb; do \
		ruby -c $$formula || exit 1; \
	done
	@echo "Checking workflow syntax..."
	@for workflow in .github/workflows/*.yml; do \
		echo "Validating $$workflow..."; \
		python3 -c "import yaml; yaml.safe_load(open('$$workflow'))" || exit 1; \
	done
	@echo "✅ All validations passed!"

.PHONY: publish
publish:
	@echo "Publishing changes..."
	@git add -A
	@git commit -m "Update formulas and workflows" || echo "No changes to commit"
	@git push

.PHONY: trigger-update
trigger-update:
	@echo "Triggering formula update workflow..."
	@gh workflow run scheduled-update.yml

.PHONY: watch-runs
watch-runs:
	@echo "Watching GitHub Actions runs..."
	@gh run list --limit 5
	@gh run watch $$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')

.PHONY: setup-secrets
setup-secrets:
	@echo "Setting up repository secrets..."
	@echo "Enter your GitHub Personal Access Token with 'repo' scope:"
	@read -s token && gh secret set HOMEBREW_TAP_TOKEN -b "$$token"
	@echo "✅ Secret configured!"

.PHONY: info
info:
	@echo "Tap Information:"
	@echo "  Repository: $$(git remote get-url origin)"
	@echo "  Formulas: $$(ls -1 Formula/*.rb 2>/dev/null | wc -l)"
	@echo "  Workflows: $$(ls -1 .github/workflows/*.yml 2>/dev/null | wc -l)"
	@echo ""
	@echo "Formula Versions:"
	@for formula in Formula/*.rb; do \
		name=$$(basename $$formula .rb); \
		version=$$(grep 'version "' $$formula | sed 's/.*version "\(.*\)".*/\1/'); \
		echo "  $$name: $$version"; \
	done

# ==============================================================================
# Git hooks helpers (pre-commit)
# ==============================================================================
# =============================================================================
# Git hooks helpers (pre-commit)
# =============================================================================
# DEVELOPER-FRIENDLY: hooks run on STAGED FILES ONLY by default (fast!)
# For full repo checks (CI, releases): use hooks-run-all
#
# Quick reference:
#   make hooks-install    - Install hooks (one-time setup)
#   make hooks-run        - Run on staged files only (fast, for dev)
#   make hooks-run-all    - Run on ALL files (slower, for CI/release)
#   make hooks-run-hook HOOK=ruff  - Run specific hook on staged files
# =============================================================================

PRE_COMMIT ?= pre-commit
PRE_COMMIT_CONFIG ?= .pre-commit-config.yaml

.PHONY: hooks-install hooks-uninstall hooks-status hooks-run hooks-run-all hooks-run-hook hooks-run-hook-all hooks-autoupdate hooks-clean

hooks-install: ## Install git hooks (runs on staged files by default)
	@echo "$(GREEN)Installing git hooks...$(RESET)"
	@$(PRE_COMMIT) --version >/dev/null 2>&1 || { echo "$(YELLOW)pre-commit not available; skipping.$(RESET)"; exit 0; }
	@if [ ! -f "$(PRE_COMMIT_CONFIG)" ]; then \
		echo "$(YELLOW)No pre-commit config found at $(PRE_COMMIT_CONFIG).$(RESET)"; \
		echo "$(YELLOW)Tip: set PRE_COMMIT_CONFIG to one of:$(RESET)"; \
		find . -name .pre-commit-config.yaml -print 2>/dev/null | head -n 20 | sed 's|^\./|  - |'; \
		exit 0; \
	else \
		$(PRE_COMMIT) install -c $(PRE_COMMIT_CONFIG) --install-hooks; \
		$(PRE_COMMIT) install -c $(PRE_COMMIT_CONFIG) --hook-type commit-msg --install-hooks; \
		echo ""; \
		echo "$(GREEN)✓ Hooks installed! They will run on STAGED files only (fast).$(RESET)"; \
		echo "$(YELLOW)  Tip: Use 'make hooks-run-all' for full repo check.$(RESET)"; \
	fi

hooks-uninstall: ## Uninstall git hooks
	@echo "$(GREEN)Uninstalling git hooks...$(RESET)"
	@$(PRE_COMMIT) --version >/dev/null 2>&1 || { echo "$(YELLOW)pre-commit not available; skipping.$(RESET)"; exit 0; }
	@$(PRE_COMMIT) uninstall -t pre-commit || true
	@$(PRE_COMMIT) uninstall -t commit-msg || true

hooks-status: ## Show git hook status and configuration
	@echo "$(GREEN)Git hooks status$(RESET)"
	@echo ""
	@echo "$(YELLOW)Configuration:$(RESET)"
	@echo "  Config file: $(PRE_COMMIT_CONFIG)"
	@echo "  core.hooksPath: $$(git config --get core.hooksPath || echo '(default .git/hooks)')"
	@echo ""
	@echo "$(YELLOW)Installed hooks in .git/hooks:$(RESET)"
	@ls -1 .git/hooks 2>/dev/null | grep -v '\.sample$$' | sed 's/^/  ✓ /' || echo "  (none)"
	@echo ""
	@echo "$(YELLOW)Available commands:$(RESET)"
	@echo "  make hooks-run       - Run on staged files (fast, default)"
	@echo "  make hooks-run-all   - Run on ALL files (slower)"
	@echo "  make hooks-run-hook HOOK=<name>  - Run specific hook"

hooks-run: ## Run hooks on STAGED files only (fast, recommended for dev)
	@echo "$(GREEN)Running hooks on staged files...$(RESET)"
	@$(PRE_COMMIT) --version >/dev/null 2>&1 || { echo "$(YELLOW)pre-commit not available; skipping.$(RESET)"; exit 0; }
	@if [ ! -f "$(PRE_COMMIT_CONFIG)" ]; then \
		echo "$(YELLOW)No pre-commit config found at $(PRE_COMMIT_CONFIG); skipping.$(RESET)"; \
		exit 0; \
	else \
		$(PRE_COMMIT) run -c $(PRE_COMMIT_CONFIG) || { \
			echo ""; \
			echo "$(YELLOW)Tip: Some issues can be auto-fixed. Check the output above.$(RESET)"; \
			exit 1; \
		}; \
	fi

hooks-run-all: ## Run hooks on ALL files (slower, for CI or full repo check)
	@echo "$(GREEN)Running hooks on ALL files (this may take a while)...$(RESET)"
	@$(PRE_COMMIT) --version >/dev/null 2>&1 || { echo "$(YELLOW)pre-commit not available; skipping.$(RESET)"; exit 0; }
	@if [ ! -f "$(PRE_COMMIT_CONFIG)" ]; then \
		echo "$(YELLOW)No pre-commit config found at $(PRE_COMMIT_CONFIG); skipping.$(RESET)"; \
		exit 0; \
	else \
		$(PRE_COMMIT) run -c $(PRE_COMMIT_CONFIG) --all-files --show-diff-on-failure; \
	fi

hooks-run-hook: ## Run a specific hook (usage: make hooks-run-hook HOOK=ruff)
ifndef HOOK
	@echo "$(RED)Error: HOOK is required$(RESET)"
	@echo "Usage: make hooks-run-hook HOOK=<hook-id>"
	@echo ""
	@echo "Available hooks (from $(PRE_COMMIT_CONFIG)):"
	@$(PRE_COMMIT) run -c $(PRE_COMMIT_CONFIG) --list-hooks 2>/dev/null | sed 's/^/  /' || echo "  (run 'make hooks-install' first)"
	@exit 1
else
	@echo "$(GREEN)Running hook '$(HOOK)' on staged files...$(RESET)"
	@$(PRE_COMMIT) run -c $(PRE_COMMIT_CONFIG) $(HOOK) || exit 1
endif

hooks-run-hook-all: ## Run a specific hook on ALL files (usage: make hooks-run-hook-all HOOK=ruff)
ifndef HOOK
	@echo "$(RED)Error: HOOK is required$(RESET)"
	@echo "Usage: make hooks-run-hook-all HOOK=<hook-id>"
	@exit 1
else
	@echo "$(GREEN)Running hook '$(HOOK)' on ALL files...$(RESET)"
	@$(PRE_COMMIT) run -c $(PRE_COMMIT_CONFIG) $(HOOK) --all-files || exit 1
endif

hooks-autoupdate: ## Update pre-commit hook versions
	@echo "$(GREEN)Updating pre-commit hooks...$(RESET)"
	@$(PRE_COMMIT) --version >/dev/null 2>&1 || { echo "$(YELLOW)pre-commit not available; skipping.$(RESET)"; exit 0; }
	@if [ ! -f "$(PRE_COMMIT_CONFIG)" ]; then \
		echo "$(YELLOW)No pre-commit config found at $(PRE_COMMIT_CONFIG); skipping.$(RESET)"; \
		exit 0; \
	else \
		$(PRE_COMMIT) autoupdate -c $(PRE_COMMIT_CONFIG); \
	fi

hooks-clean: ## Clean pre-commit cache (useful if hooks are misbehaving)
	@echo "$(GREEN)Cleaning pre-commit cache...$(RESET)"
	@$(PRE_COMMIT) clean 2>/dev/null || true
	@$(PRE_COMMIT) gc 2>/dev/null || true
	@echo "$(GREEN)✓ Cache cleaned. Run 'make hooks-install' to reinstall.$(RESET)"
