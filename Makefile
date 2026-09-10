##
## {{SITE_LABEL}} - dev tasks
## Usage: make <target>
##

.PHONY: help dev build preview check lint lint-fix format format-check \
        test spell add clean guard-integration

SITE_NAME = {{SITE_NAME}}
FLAVOUR = {{FLAVOUR}}
DEPLOY_TARGET = {{DEPLOY_TARGET}}
ADAPTER = {{ADAPTER}}

# Every target runs through pnpm so the workspace's pinned versions are used
# rather than whatever happens to be on PATH.
PNPM = pnpm

## == Development ==============================================================

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make \033[36m<target>\033[0m\n\nTargets:\n"} \
	/^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

dev: ## Start the Astro dev server
	$(PNPM) astro dev

build: ## Production build
	$(PNPM) astro build

preview: ## Serve the production build locally
	$(PNPM) astro preview

## == Quality ==================================================================

# The bare template ships no src/, and a project before its first
# setup.sh run has none either. Every target below that only makes sense
# once there is app code uses this guard to skip cleanly instead of letting
# the underlying tool exit non-zero on nothing to check. Root-level config
# files this template ships (astro.config.mjs, eslint.config.mjs,
# vitest.config.ts) are covered by Prettier alongside src/; ESLint and
# Vitest find them on their own once src/ exists.
GUARD_SRC = [ -d src ] || { echo "No src/ yet; skipping $@."; exit 0; }
FMT_PATHS = src astro.config.mjs eslint.config.mjs vitest.config.ts

check: ## Type check .astro and TypeScript (astro check)
	$(PNPM) astro check

lint: ## Lint (ESLint)
	@$(GUARD_SRC) && $(PNPM) exec eslint .

lint-fix: ## Lint and apply fixes (ESLint)
	@$(GUARD_SRC) && $(PNPM) exec eslint . --fix

format: ## Format (Prettier)
	@$(GUARD_SRC) && $(PNPM) exec prettier --write $(FMT_PATHS)

format-check: ## Check formatting without writing (Prettier)
	@$(GUARD_SRC) && $(PNPM) exec prettier --check $(FMT_PATHS)

test: ## Unit tests (Vitest)
	@$(GUARD_SRC) && $(PNPM) exec vitest run

spell: ## Spell check (CSpell)
	$(PNPM) exec cspell --no-progress --no-must-find-files "**"

## == Project ==================================================================

# Use the short name for an official adapter (node, cloudflare, vercel,
# netlify). The scoped package name installs the package without writing the
# adapter into astro.config.
add: guard-integration ## Add an Astro integration or adapter: make add I=<name>
	$(PNPM) astro add $(I) --yes

guard-integration:
	@test -n "$(I)" || { \
	  echo "I is not set. Usage: make add I=<integration>"; \
	  echo "For example: make add I=@astrojs/mdx   or   make add I=react"; \
	  exit 1; \
	}

clean: ## Remove build output and caches (keeps node_modules)
	rm -rf dist .astro
	@echo "Removed dist/ and .astro/. To drop dependencies too: rm -rf node_modules"
