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
