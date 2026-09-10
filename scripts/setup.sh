#!/usr/bin/env bash
# {{SITE_LABEL}} - one-command dev environment spin-up.
# Run from the repo root: ./scripts/setup.sh
# Idempotent: re-running is safe and never clobbers a template file.
# Starts no server; use "make dev" for that.
# Flags:
#   --skip-install   scaffold and agent resources only, no pnpm install and no
#                    integration installs
set -euo pipefail

BOLD="\033[1m"; GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; RESET="\033[0m"
info()    { echo -e "${BOLD}> $*${RESET}"; }
success() { echo -e "${GREEN}OK $*${RESET}"; }
warn()    { echo -e "${YELLOW}!! $*${RESET}"; }
error()   { echo -e "${RED}xx $*${RESET}" >&2; exit 1; }

SITE_NAME="{{SITE_NAME}}"
SKILL_FORK="{{SKILL_FORK}}"
FLAVOUR="{{FLAVOUR}}"
DEPLOY_TARGET="{{DEPLOY_TARGET}}"
ASTRO_TEMPLATE="{{ASTRO_TEMPLATE}}"
# Swap for @astrojs/cloudflare or @astrojs/vercel to deploy elsewhere. Empty
# means a fully static build with no adapter.
ADAPTER="{{ADAPTER}}"

# Astro 7 requires Node 22.12.0 or higher (verified against the astro package's
# engines field). Keep this in step with .github/workflows/ci.yml.
MIN_NODE="22.12.0"

# Integrations every project gets. Sitemap is the minimum; add to this list
# rather than running "astro add" by hand, so a fresh clone reproduces.
DEFAULT_INTEGRATIONS=(sitemap)

SKIP_INSTALL=0
for a in "$@"; do
  case "$a" in
    --skip-install) SKIP_INSTALL=1 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) error "Unknown option: $a" ;;
  esac
done

echo ""; echo -e "${BOLD}=== {{SITE_LABEL}} setup ===${RESET}"; echo ""

# --- Node ---
info "Checking Node..."
command -v node >/dev/null 2>&1 || error "Node not found. Install Node $MIN_NODE or higher, then re-run."

NODE_RAW="$(node --version)"          # for example v22.16.0
NODE_VER="${NODE_RAW#v}"
NODE_VER="${NODE_VER%%-*}"            # drop any prerelease suffix

version_lt() { # version_lt <a> <b> -> 0 when a < b, numeric per component
  local a="$1" b="$2" i ai bi
  local -a A B
  IFS='.' read -r -a A <<< "$a"
  IFS='.' read -r -a B <<< "$b"
  for i in 0 1 2; do
    ai="${A[i]:-0}"; bi="${B[i]:-0}"
    # Strip anything non-numeric so a malformed component compares as 0
    # rather than aborting the arithmetic.
    ai="${ai//[!0-9]/}"; bi="${bi//[!0-9]/}"
    ai="${ai:-0}"; bi="${bi:-0}"
    if [ "$ai" -lt "$bi" ]; then return 0; fi
    if [ "$ai" -gt "$bi" ]; then return 1; fi
  done
  return 1
}

if version_lt "$NODE_VER" "$MIN_NODE"; then
  error "Node $NODE_VER is too old. Astro needs $MIN_NODE or higher. Install a newer Node (nvm: 'nvm install --lts'), then re-run."
fi

NODE_MAJOR="${NODE_VER%%.*}"
if [ $((NODE_MAJOR % 2)) -eq 1 ]; then
  warn "Node $NODE_VER is an odd-numbered major, which never becomes LTS. Astro supports it, but prefer an even major for anything you ship."
fi
success "Node $NODE_VER (minimum $MIN_NODE)."

# --- pnpm ---
info "Enabling pnpm via corepack..."
if command -v corepack >/dev/null 2>&1; then
  # corepack enable writes shims next to the Node binary, which can fail on a
  # system-managed install. A pnpm already on PATH is just as good.
  corepack enable pnpm >/dev/null 2>&1 || warn "corepack enable failed (often a permissions issue on a system Node); falling back to any pnpm already on PATH."
else
  warn "corepack not found; falling back to any pnpm already on PATH."
fi
command -v pnpm >/dev/null 2>&1 || error "pnpm not found and corepack could not provide it. Install pnpm (https://pnpm.io/installation), then re-run."
PNPM_VERSION="$(pnpm --version)"
PNPM_MAJOR="${PNPM_VERSION%%.*}"
PNPM_MAJOR="${PNPM_MAJOR//[!0-9]/}"
PNPM_MAJOR="${PNPM_MAJOR:-0}"
success "pnpm $PNPM_VERSION."

# --- Agent resources (skills) ---
info "Installing Claude Code / Cursor skills via agr..."
# Skills are a convenience, not a prerequisite for a working project, so any
# agr failure (most commonly: not run inside a git repository) warns and
# carries on instead of aborting the whole spin-up under set -euo pipefail.
agr_failed() {
  warn "agr could not install the skills; continuing without them."
  warn "agr must run inside a git repository. If this project is not one yet:"
  warn "  git init && git add -A && git commit -m 'Initial commit'"
  warn "Then re-run: agr sync"
}
if command -v agr >/dev/null 2>&1; then
  if agr sync; then
    success "Skills installed (agr sync). Commit the generated agr.lock."
  else
    agr_failed
  fi
else
  warn "agr not found, skipping skills."
  warn "Install uv (https://docs.astral.sh/uv/), then: uv tool install agr && agr sync"
fi

# --- Astro scaffold ---
# The scaffold is generated into a temp directory and copied across with
# cp -n, so a template file always wins over the upstream starter's version of
# the same path. Re-running after the scaffold exists is a no-op.
if [ -f package.json ]; then
  success "Astro project already scaffolded (package.json present); leaving it alone."
else
  info "Scaffolding Astro ($ASTRO_TEMPLATE) into a temp directory..."
  SCAFFOLD_TMP="$(mktemp -d "${TMPDIR:-/tmp}/astro-scaffold.XXXXXX")"
  cleanup_scaffold() { rm -rf "$SCAFFOLD_TMP"; }
  trap cleanup_scaffold EXIT

  # --no-install and --no-git because this repo already has git and pnpm
  # install runs below against the merged tree. --yes and --skip-houston keep
  # it non-interactive. Flags verified against create-astro 5.2.4.
  pnpm dlx create-astro@latest "$SCAFFOLD_TMP/app" \
    --template "$ASTRO_TEMPLATE" \
    --no-install --no-git --no-ai --skip-houston --yes \
    || error "create-astro failed. Re-run, or scaffold by hand with: pnpm create astro@latest -- --template $ASTRO_TEMPLATE"

  [ -f "$SCAFFOLD_TMP/app/package.json" ] || error "create-astro produced no package.json in $SCAFFOLD_TMP/app."

  info "Copying the scaffold in (existing files are never overwritten)..."
  # Copied entry by entry rather than with "cp -Rn", because BSD cp exits 1
  # when -n skips an existing file while GNU cp exits 0, so cp's exit status
  # cannot tell a real failure from a deliberate skip. Verified on macOS 15
  # (BSD cp) during the first live run. This loop is portable, and it reports
  # which template files won.
  copied=0; kept=0
  while IFS= read -r rel; do
    rel="${rel#./}"
    [ -n "$rel" ] || continue
    if [ -e "$rel" ] || [ -L "$rel" ]; then
      kept=$((kept + 1))
      echo "  kept (template wins): $rel"
      continue
    fi
    dir="$(dirname "$rel")"
    [ "$dir" = "." ] || mkdir -p "$dir" || error "Could not create $dir."
    cp -R "$SCAFFOLD_TMP/app/$rel" "$rel" || error "Could not copy $rel from the scaffold."
    copied=$((copied + 1))
  done < <(cd "$SCAFFOLD_TMP/app" && find . \( -type f -o -type l \) -print)

  [ -f package.json ] || error "The scaffold copy produced no package.json."
  success "Copied $copied files from the scaffold, kept $kept template files."

  # The starter's package name is the temp directory name; make it the site.
  if command -v node >/dev/null 2>&1; then
    node -e '
      const fs = require("fs");
      const p = JSON.parse(fs.readFileSync("package.json", "utf8"));
      p.name = process.argv[1];
      fs.writeFileSync("package.json", JSON.stringify(p, null, 2) + "\n");
    ' "$SITE_NAME" && success "package.json name set to $SITE_NAME."
  fi

  cleanup_scaffold
  trap - EXIT
  success "Astro scaffold in place ($ASTRO_TEMPLATE)."

  # --- Sample test ---
  # A self-contained component and test that does not depend on anything the
  # create-astro scaffold provides, so `make test` has something real to run
  # immediately after setup, on every flavour. Copy the pattern for real
  # components, or delete this one once real tests exist: it is written only
  # here, while the scaffold is being generated, so a later re-run of setup.sh
  # never brings a deleted sample back.
  if [ -f src/components/Greeting.test.ts ]; then
    info "Sample test already present (src/components/Greeting.test.ts); leaving it alone."
  else
    mkdir -p src/components
    cat > src/components/Greeting.astro <<'ASTRO'
---
interface Props {
  name: string;
}
const { name } = Astro.props;
---

<p>Hello, {name}!</p>
ASTRO
    cat > src/components/Greeting.test.ts <<'TS'
import { experimental_AstroContainer as AstroContainer } from 'astro/container';
import { describe, expect, test } from 'vitest';
import Greeting from './Greeting.astro';

describe('Greeting', () => {
  test('renders the given name', async () => {
    const container = await AstroContainer.create();
    const result = await container.renderToString(Greeting, {
      props: { name: 'Astro' },
    });
    expect(result).toContain('Hello, Astro!');
  });
});
TS
    success "Sample test written (src/components/Greeting.astro + Greeting.test.ts)."
  fi
fi

if [ "$SKIP_INSTALL" = "1" ]; then
  echo ""
  warn "--skip-install: stopping before pnpm install and the integration installs."
  warn "Finish later with: pnpm install && ./scripts/setup.sh"
  exit 0
fi

# --- Dependency build approvals ---
# pnpm 10 and later refuse to run a dependency's install scripts until the
# package is allowlisted, and pnpm 12 makes that a hard install failure
# (ERR_PNPM_IGNORED_BUILDS) rather than a warning. Astro needs esbuild built,
# and the image pipeline needs sharp, so both are allowed explicitly rather
# than turning on dangerouslyAllowAllBuilds. Verified against pnpm 12.3.4.
#
# The setting moved: pnpm 11 removed onlyBuiltDependencies in favour of
# allowBuilds. Both live in pnpm-workspace.yaml, which doubles as the settings
# file for a single-package project.
if [ -f pnpm-workspace.yaml ]; then
  info "pnpm-workspace.yaml already present; leaving its build settings alone."
elif [ "$PNPM_MAJOR" -ge 11 ]; then
  cat > pnpm-workspace.yaml <<'YAML'
# Dependency install scripts this project allows to run. pnpm refuses to run
# any that are not listed. Add a package here rather than enabling
# dangerouslyAllowAllBuilds. Syntax is pnpm 11 and later.
allowBuilds:
  esbuild: true
  sharp: true
YAML
  success "Wrote pnpm-workspace.yaml (allowBuilds, pnpm $PNPM_MAJOR)."
elif [ "$PNPM_MAJOR" -ge 10 ]; then
  cat > pnpm-workspace.yaml <<'YAML'
# Dependency install scripts this project allows to run. pnpm refuses to run
# any that are not listed. Syntax is pnpm 10; pnpm 11 renamed this to
# allowBuilds, as a map of package name to boolean.
onlyBuiltDependencies:
  - esbuild
  - sharp
YAML
  success "Wrote pnpm-workspace.yaml (onlyBuiltDependencies, pnpm $PNPM_MAJOR)."
else
  info "pnpm $PNPM_VERSION runs dependency install scripts without an allowlist; nothing to configure."
fi

# --- Dependencies ---
info "Installing dependencies (pnpm install)..."
if ! pnpm install; then
  warn "pnpm install failed."
  warn "If it reported ERR_PNPM_IGNORED_BUILDS, add the named packages to"
  warn "pnpm-workspace.yaml (allowBuilds on pnpm 11 and later,"
  warn "onlyBuiltDependencies on pnpm 10), or run: pnpm approve-builds"
  error "Fix the above, then re-run ./scripts/setup.sh."
fi
success "Dependencies installed."

# --- Type checking ---
# "astro check" is not self-contained: without @astrojs/check and typescript it
# stops and prompts to install them, which would hang CI. make check is a
# first-class target here, so the dependencies are installed up front. Only
# added when missing, so a re-run does not bump the versions a project pinned.
#
# typescript is pinned to ^6 deliberately. @astrojs/check 0.9.10 peer-requires
# "^5.0.0 || ^6.0.0", and TypeScript 7's native compiler does not expose the
# programmatic API the checker is built on, so an unpinned "pnpm add -D
# typescript" installs 7.x and every "make check" fails. Observed live on
# 2026-09-09 with typescript 7.0.2. Track
# https://github.com/withastro/roadmap/discussions/1321 and drop the pin when
# astro check supports TypeScript 7.
dep_present() { # dep_present <package-name> -> 0 when already a dependency
  node -e '
    const fs = require("fs");
    const p = JSON.parse(fs.readFileSync("package.json", "utf8"));
    const dep = process.argv[1];
    const has = (p.dependencies && p.dependencies[dep]) || (p.devDependencies && p.devDependencies[dep]);
    process.exit(has ? 0 : 1);
  ' "$1" 2>/dev/null
}

TYPECHECK_DEPS=("@astrojs/check" "typescript@^6")
missing_dev=()
for spec in "${TYPECHECK_DEPS[@]}"; do
  dep="${spec%@^*}"
  dep_present "$dep" || missing_dev+=("$spec")
done
if [ "${#missing_dev[@]}" -gt 0 ]; then
  info "Installing type-checking dependencies: ${missing_dev[*]}"
  pnpm add -D "${missing_dev[@]}" || warn "Could not install ${missing_dev[*]}; 'make check' will prompt for them."
else
  success "Type-checking dependencies already present."
fi

# --- Quality toolchain ---
# ESLint (eslint-plugin-astro) plus Prettier (prettier-plugin-astro) over
# Biome; typescript-eslint for typed linting. Decision, date and reopen
# triggers are in CONVENTIONS.md, "Quality toolchain". eslint-plugin-jsx-a11y
# is deliberately not installed: see the same section for why.
#
# @eslint/js is listed explicitly because eslint.config.mjs imports it for the
# core rule set, and pnpm's isolated node_modules does not expose a transitive
# dependency of eslint to the project. typescript-eslint is pinned to ^8 for
# the same reason typescript is pinned to ^6 above: its flat-config ordering
# behaviour and its typescript peer range are verified against 8.70.0.
QUALITY_DEPS=("@eslint/js" eslint eslint-plugin-astro "typescript-eslint@^8" prettier prettier-plugin-astro vitest cspell)
missing_quality=()
for spec in "${QUALITY_DEPS[@]}"; do
  dep="${spec%@^*}"
  dep_present "$dep" || missing_quality+=("$spec")
done
if [ "${#missing_quality[@]}" -gt 0 ]; then
  info "Installing quality-toolchain dependencies: ${missing_quality[*]}"
  pnpm add -D "${missing_quality[@]}" || warn "Could not install ${missing_quality[*]}; make lint/format/test/spell will not work."
else
  success "Quality-toolchain dependencies already present."
fi

# --- Integrations ---
# astro add is idempotent: an integration already in astro.config is left as is.
for integration in "${DEFAULT_INTEGRATIONS[@]}"; do
  info "Adding integration: $integration"
  pnpm astro add "$integration" --yes || warn "astro add $integration failed; add it later with: make add I=$integration"
done

if [ -n "$ADAPTER" ]; then
  # "astro add" registers an official adapter in astro.config only when it is
  # given the short name. Handed the scoped package name it installs the
  # package and writes nothing into the config, leaving an inert dependency and
  # a build that silently stays fully static. Observed live on 2026-09-09 with
  # @astrojs/node 11.1.5. So strip the @astrojs/ scope; anything else is passed
  # through unchanged.
  ADAPTER_ARG="$ADAPTER"
  case "$ADAPTER" in
    @astrojs/*) ADAPTER_ARG="${ADAPTER#@astrojs/}" ;;
  esac
  info "Adding adapter: $ADAPTER (deploy target: $DEPLOY_TARGET)"
  pnpm astro add "$ADAPTER_ARG" --yes || warn "astro add $ADAPTER_ARG failed; add it later with: make add I=$ADAPTER_ARG"
else
  info "Deploy target is static; no adapter to add."
fi

# --- Normalize formatting ---
# create-astro's scaffold and "astro add" do not honour this project's
# Prettier config: astro.config.mjs comes back double-quoted, without a
# trailing comma or a final newline, and the scaffold's own src/ files (for
# example src/pages/index.astro) do not match it either. Left alone, "make
# format-check" fails on a project straight out of setup.sh. Run once
# Prettier is installed, after every step above that writes or rewrites
# files. Paths match the Makefile's FMT_PATHS; keep the two in step.
if dep_present prettier; then
  info "Formatting the scaffold to match this project's Prettier config..."
  pnpm exec prettier --write src astro.config.mjs eslint.config.mjs vitest.config.ts \
    || warn "Prettier formatting pass failed; run 'make format' by hand."
else
  warn "Prettier not installed; skipping the formatting pass. Run 'make format' by hand."
fi

echo ""
success "Setup complete for {{SITE_LABEL}} ({{CLIENT}})."
info "Next:"
echo "  make dev      start the dev server"
echo "  make check    astro check (type checking)"
echo "  make help     every target"
echo ""
warn "Commit the generated pnpm-lock.yaml, pnpm-workspace.yaml and agr.lock."
warn "Set 'site' in astro.config.mjs to your production URL. Without it the"
warn "sitemap integration skips generation and emits no sitemap."
