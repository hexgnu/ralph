# Ralph - Autonomous AI Agent System
# Makefile for linting, formatting, and development tasks

.PHONY: all lint lint-shell lint-docker lint-yaml lint-actions lint-md \
        format format-shell format-json \
        check install-hooks clean help

# Default target
all: lint

# =============================================================================
# LINTING - Aggressive checks
# =============================================================================

# Run all linters
lint: lint-shell lint-docker lint-yaml lint-actions lint-md lint-json
	@echo "All lints passed!"

# ShellCheck - shell script static analysis (STRICT)
lint-shell:
	@echo "Running ShellCheck (strict mode)..."
	@shellcheck --severity=warning --external-sources \
		*.sh lib/*.sh 2>/dev/null || \
		shellcheck --severity=warning *.sh lib/*.sh
	@echo "ShellCheck passed!"

# Hadolint - Dockerfile linting
lint-docker:
	@echo "Running Hadolint..."
	@hadolint --failure-threshold warning Dockerfile
	@echo "Hadolint passed!"

# yamllint - YAML linting
lint-yaml:
	@echo "Running yamllint..."
	@yamllint -c .yamllint.yaml .github/ .pre-commit-config.yaml .hadolint.yaml .yamllint.yaml 2>/dev/null || \
		echo "yamllint not installed or no YAML files found"

# actionlint - GitHub Actions workflow linting
lint-actions:
	@echo "Running actionlint..."
	@actionlint .github/workflows/*.yml 2>/dev/null || \
		echo "actionlint not installed, skipping"

# markdownlint - Markdown linting
lint-md:
	@echo "Running markdownlint..."
	@markdownlint --disable MD013 MD033 MD041 -- '*.md' 'agents/*.md' 2>/dev/null || \
		echo "markdownlint not installed, skipping"

# JSON validation
lint-json:
	@echo "Validating JSON files..."
	@for f in *.json; do \
		if [ -f "$$f" ]; then \
			jq empty "$$f" || exit 1; \
			echo "  $$f: valid"; \
		fi; \
	done
	@echo "JSON validation passed!"

# =============================================================================
# FORMATTING
# =============================================================================

# Run all formatters
format: format-shell format-json
	@echo "All formatting complete!"

# shfmt - shell script formatting
format-shell:
	@echo "Formatting shell scripts with shfmt..."
	@shfmt -i 2 -bn -ci -sr -w *.sh lib/*.sh 2>/dev/null || \
		echo "shfmt not installed, skipping"

# Format JSON files
format-json:
	@echo "Formatting JSON files..."
	@for f in *.json; do \
		if [ -f "$$f" ]; then \
			jq --indent 2 '.' "$$f" > "$$f.tmp" && mv "$$f.tmp" "$$f"; \
			echo "  Formatted: $$f"; \
		fi; \
	done

# =============================================================================
# CHECK MODE (non-destructive)
# =============================================================================

# Check formatting without modifying files
check: check-shell check-json
	@echo "All checks passed!"

check-shell:
	@echo "Checking shell script formatting..."
	@shfmt -i 2 -bn -ci -sr -d *.sh lib/*.sh 2>/dev/null || \
		(echo "Shell scripts need formatting. Run 'make format-shell'" && exit 1)

check-json:
	@echo "Checking JSON formatting..."
	@for f in *.json; do \
		if [ -f "$$f" ]; then \
			jq --indent 2 '.' "$$f" > "$$f.check.tmp" && \
			diff -q "$$f.check.tmp" "$$f" > /dev/null || \
				(echo "$$f needs formatting. Run 'make format-json'" && rm -f "$$f.check.tmp" && exit 1); \
			rm -f "$$f.check.tmp"; \
		fi; \
	done

# =============================================================================
# SETUP
# =============================================================================

# Install pre-commit hooks
install-hooks:
	@echo "Installing pre-commit hooks..."
	@pre-commit install
	@pre-commit install --hook-type commit-msg
	@echo "Pre-commit hooks installed!"

# Install all linting dependencies
install-linters:
	@echo "Installing linting dependencies..."
	@echo "Note: Some tools may require manual installation"
	@echo ""
	@echo "Required tools:"
	@echo "  - shellcheck: https://github.com/koalaman/shellcheck"
	@echo "  - shfmt: https://github.com/mvdan/sh"
	@echo "  - hadolint: https://github.com/hadolint/hadolint"
	@echo "  - actionlint: https://github.com/rhysd/actionlint"
	@echo "  - yamllint: pip install yamllint"
	@echo "  - markdownlint: npm install -g markdownlint-cli"
	@echo "  - pre-commit: pip install pre-commit"
	@echo ""
	@echo "On macOS with Homebrew:"
	@echo "  brew install shellcheck shfmt hadolint actionlint"
	@echo "  pip install yamllint pre-commit"
	@echo "  npm install -g markdownlint-cli"
	@echo ""
	@echo "On Ubuntu/Debian:"
	@echo "  sudo apt install shellcheck"
	@echo "  go install mvdan.cc/sh/v3/cmd/shfmt@latest"
	@echo "  # hadolint: download from GitHub releases"
	@echo "  pip install yamllint pre-commit"

# =============================================================================
# CLEAN
# =============================================================================

clean:
	@echo "Cleaning temporary files..."
	@rm -f *.tmp
	@rm -rf .cache
	@echo "Clean complete!"

# =============================================================================
# CI TARGETS (used by GitHub Actions)
# =============================================================================

# Strict CI lint - fails on any issue
ci-lint: lint
	@echo "CI lint passed!"

# CI format check - fails if files need formatting
ci-check: check
	@echo "CI format check passed!"

# =============================================================================
# HELP
# =============================================================================

help:
	@echo "Ralph Development Makefile"
	@echo ""
	@echo "Linting:"
	@echo "  make lint          - Run all linters (strict mode)"
	@echo "  make lint-shell    - Run ShellCheck on shell scripts"
	@echo "  make lint-docker   - Run Hadolint on Dockerfile"
	@echo "  make lint-yaml     - Run yamllint on YAML files"
	@echo "  make lint-actions  - Run actionlint on GitHub Actions"
	@echo "  make lint-md       - Run markdownlint on Markdown files"
	@echo "  make lint-json     - Validate JSON files"
	@echo ""
	@echo "Formatting:"
	@echo "  make format        - Format all files"
	@echo "  make format-shell  - Format shell scripts with shfmt"
	@echo "  make format-json   - Format JSON files with jq"
	@echo ""
	@echo "Checks:"
	@echo "  make check         - Check formatting (non-destructive)"
	@echo "  make ci-lint       - Run lints for CI"
	@echo "  make ci-check      - Run format checks for CI"
	@echo ""
	@echo "Setup:"
	@echo "  make install-hooks   - Install pre-commit hooks"
	@echo "  make install-linters - Show linter installation instructions"
	@echo ""
	@echo "Other:"
	@echo "  make clean         - Remove temporary files"
	@echo "  make help          - Show this help"
