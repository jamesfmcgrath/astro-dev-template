# Quality Toolchain (Stage 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire ESLint (eslint-plugin-astro), Prettier (prettier-plugin-astro),
Vitest and CSpell into the template so `make lint`, `make lint-fix`,
`make format`, `make format-check`, `make test` and `make spell` actually work
on a project created from this template, while the bare template itself
(which ships no `src/`) keeps working and every target still no-ops cleanly.

**Architecture:** Config files (`eslint.config.mjs`, `.prettierrc.json`,
`vitest.config.ts`, `cspell.json`) live at the template root and survive
`scripts/init.sh` verbatim (none of them hold `{{TOKENS}}`). They reach a
created project through the existing `cp -n` scaffold-merge in
`scripts/setup.sh`, which is extended to install the toolchain's
devDependencies (mirroring the existing `TYPECHECK_DEPS` pattern) and to
write a small self-contained sample component + test into `src/components/`
once the scaffold exists, so `make test` has something real to run on every
flavour without depending on scaffold internals. The Makefile's four
src-scoped targets (`lint`, `lint-fix`, `format`, `format-check`) plus `test`
gain a one-line guard that skips cleanly, with a message, when `src/` does not
exist yet. CI's `quality` job gains `format-check` and `spell` steps and
absorbs the old `build` job so the six checks run in the documented order.

**Tech Stack:** ESLint 10 (flat config) + `eslint-plugin-astro` 3.1.0 +
`typescript-eslint` 8.70.0, Prettier 3 + `prettier-plugin-astro` 1.0.0, Vitest
5 via `astro/config`'s `getViteConfig`, CSpell 10.

**Spec:** This plan's own header text is the spec (the user's Stage 2 prompt,
reproduced in `template-docs/PROMPTS.md` under "Stage 2, quality toolchain
decision and wiring"). Two facts were verified live against the npm registry
and a throwaway sandbox install before any config was written (both detailed
in Task 1); nothing below is inferred from memory.

## Global Constraints

- No em dashes anywhere: prose, comments, commit messages, script output.
- Scripts stay executable (`100755`); shell portable across macOS (BSD) and
  Linux (GNU) per `CONVENTIONS.md`'s script contract.
- Only `{{UPPER_SNAKE}}` names are template tokens. None of the new config
  files in this plan use one (verified: they hold no client/site-specific
  values), so they are added to `test-template.sh`'s `VERBATIM_FILES` check,
  not substituted by `init.sh`.
- GitHub Actions `${{ }}` expressions must never be touched.
- Run `scripts/test-template.sh` before calling any script change done
  (Task 9). No network, no package manager in that suite.
- Do not bump `typescript` off its `^6` pin. It exists because TypeScript 7's
  native compiler drops the programmatic API `@astrojs/check` depends on. If
  a step in this plan seems to want a newer TypeScript, stop and say so
  instead of bumping it.
- Keep every existing verified combination (minimal/blog/starlight on
  static, minimal on ssr) working. Do not touch `init.sh`'s token logic.
- WCAG 2.2 AA is not optional in anything user-facing; not directly relevant
  to this plan's config-only changes, but the sample component
  (`src/components/Greeting.astro`) still gets a typed `Props` interface per
  `AGENTS.md`, since it ships as example code in every created project.

---

## Verified facts (read before Task 1)

Gathered live on 2026-09-09 against the npm registry and a throwaway sandbox
install (`npm view`, `npm pack`, and running the actual tools). Task 1 turns
this into the permanent docs note; this section is the evidence for it.

1. **`eslint-plugin-astro` 3.1.0** peer-requires `eslint >=10.0.0`. Latest
   `eslint` is `10.10.0`. Its flat-config exports are
   `configs.recommended` / `configs.base` / `configs.all` (also reachable as
   `configs['flat/recommended']` etc., same array), confirmed by unpacking the
   published tarball and reading `lib/index.mjs`. The plugin's own README
   (`node_modules/eslint-plugin-astro/README.md`) gives the canonical usage:
   `import eslintPluginAstro from "eslint-plugin-astro"` then spread
   `...eslintPluginAstro.configs.recommended`.
2. **Ordering bug found live:** spreading `typescript-eslint`'s recommended
   config *after* `eslint-plugin-astro`'s breaks `.astro` parsing.
   `typescript-eslint`'s config sets `languageOptions.parser` with no `files`
   restriction, which overwrites the `astro-eslint-parser` that
   `eslint-plugin-astro`'s own `base` config assigns to `*.astro` files (flat
   config merges same-key properties from later array entries over earlier
   ones). Confirmed with `--print-config`: parser resolved to
   `typescript-eslint/parser` for a `.astro` file, and linting it produced
   `Parsing error: Expression expected`. Spreading `typescript-eslint`'s
   config *before* `eslint-plugin-astro`'s fixes it (astro's parser wins
   last); confirmed both by a clean lint run and `--print-config` showing
   `astro-eslint-parser`.
3. **`eslint-plugin-jsx-a11y` is peer-optional** for `eslint-plugin-astro`
   (`peerDependenciesMeta` marks it optional) but its own peer range is
   `eslint: ^3 || ... || ^9`, which does not reach ESLint 10. It cannot be
   installed alongside `eslint-plugin-astro` 3.1.0 today. Not installed in
   this plan; the astro `jsx-a11y-*` configs are left unused.
4. **`typescript-eslint` 8.70.0** peer-requires `typescript >=4.8.4 <6.1.0`.
   Our pin is `typescript@^6`. The only published stable `6.x` releases are
   `6.0.0`, `6.0.2`, `6.0.3` (checked the full version list); `^6` currently
   resolves to `6.0.3`, which satisfies `<6.1.0`. No conflict today, but it is
   a real future collision if TypeScript ships `6.1.0` before
   `typescript-eslint` widens its range. Documented as a second reopen
   trigger in Task 1.
5. **`prettier-plugin-astro` 1.0.0** peer-requires `prettier ^3.5.3`; latest
   `prettier` is `3.9.6`. Confirmed live: `.prettierrc.json` with
   `"plugins": ["prettier-plugin-astro"]` and an override setting
   `parser: "astro"` for `*.astro` correctly reformats a messy `.astro` file
   and then passes `--check`.
6. **`astro/config` exports `getViteConfig`** (confirmed by unpacking
   `astro@7.3.2`'s tarball and reading `dist/config/index.d.ts`:
   `export declare function getViteConfig(userViteConfig, inlineAstroConfig?)`).
   A minimal `vitest.config.ts` using it, plus a component test using
   `experimental_AstroContainer` from `astro/container` (still
   experimental-prefixed in 7.3.2, which is Astro's own documented pattern
   for testing components with Vitest), was run live end to end with
   `vitest run` and passed.
7. **`eslint .` (no CLI glob) already lints `.astro` files** once the flat
   config declares a `files: ["*.astro", "**/*.astro"]` entry, confirmed by
   forcing `astro/semi` to error and seeing it fire on a `.astro` file under
   `eslint .`. The plugin README's "include the `.astro` extension using a
   glob pattern" warning did not reproduce with eslint-plugin-astro 3.1.0's
   flat config; no explicit glob is needed on the Makefile's `eslint .` call.
8. **Prettier, Vitest and CSpell all exit non-zero on "nothing to check"** in
   ways ESLint does not: `prettier --check` with a glob matching zero files
   exits `2`; `vitest run` with zero test files exits `1` ("No test files
   found, exiting with code 1"); `eslint .` with nothing under `src/` exits
   `0` silently. This is why `lint`, `lint-fix`, `format`, `format-check` and
   `test` all need the same explicit `src/`-existence guard, verified with a
   throwaway Makefile that the single-recipe-line pattern
   `@$(GUARD_SRC) && <command>` actually skips (prints a message, exits 0)
   when `src/` is absent and actually runs when it is present. `spell` does
   not need the guard: it already runs with `--no-must-find-files` and exits
   `0` on zero matches.

---

### Task 1: Record the toolchain decisions in CONVENTIONS.md

**Files:**
- Modify: `CONVENTIONS.md`

**Interfaces:**
- Produces: a `## Quality toolchain` section other tasks' comments point
  readers at (`eslint.config.mjs`, `scripts/setup.sh`).

- [ ] **Step 1: Add the section**

Insert a new section after `## CI guard-job inversion` and before
`## Agent resources` in `CONVENTIONS.md`:

```markdown
## Quality toolchain

Decided 2026-09-09: ESLint (`eslint-plugin-astro`) plus Prettier
(`prettier-plugin-astro`) over Biome. Biome 2.5.12 still treats Astro
parsing, formatting and linting as experimental and supports no plugins for
it (verified against the published package). **Reopen this decision when
Biome ships stable, non-experimental Astro support.**

`typescript` stays pinned to `^6` in `scripts/setup.sh` (currently resolves
to `6.0.3`). TypeScript 7's native compiler drops the programmatic API
`@astrojs/check` depends on, so an unpinned install breaks `make check`.
`typescript-eslint` 8.70.0 peer-requires `typescript >=4.8.4 <6.1.0`, which
the `^6` pin still satisfies only because TypeScript's `6.x` line has not
shipped past `6.0.x` yet. **Reopen the pin** when `@astrojs/check` supports
TypeScript 7 (track
https://github.com/withastro/roadmap/discussions/1321), **and re-check this
range** if TypeScript ships `6.1.0` before `typescript-eslint` widens its
peer range past it.

`eslint.config.mjs` spreads `typescript-eslint`'s recommended config *before*
`eslint-plugin-astro`'s, not after: `eslint-plugin-astro`'s `base` config
assigns the `astro-eslint-parser` to `*.astro` files, and `typescript-eslint`'s
config sets a parser with no `files` restriction, so if it loads second it
overwrites that assignment and breaks Astro frontmatter parsing entirely
(`Parsing error: Expression expected`, confirmed live with `--print-config`).

`eslint-plugin-jsx-a11y` is deliberately not installed. It is an optional
peer of `eslint-plugin-astro` (for the `jsx-a11y-recommended` /
`jsx-a11y-strict` configs and the `astro/jsx-a11y/*` rules) but its own peer
range caps at ESLint `^9`, while `eslint-plugin-astro` 3.1.0 requires ESLint
`>=10.0.0`. The two cannot be installed together today. **Reopen** when
`eslint-plugin-jsx-a11y` supports ESLint 10.

Node note: `eslint-plugin-astro` 3.1.0's `engines` field wants Node
`^22.22.3 || ^24.16.0 || >=26.3.0`, tighter than Astro's own `>=22.12.0`
floor that `scripts/setup.sh`'s `MIN_NODE` enforces. `pnpm install` only
warns on an engines mismatch (no `engine-strict` is set here), so this is
not a hard failure, but a project running the oldest Node this template
allows may see that warning on `pnpm install`.
```

- [ ] **Step 2: Commit**

```bash
git add CONVENTIONS.md
git commit -m "docs: record the quality toolchain decision and its reopen triggers"
```

---

### Task 2: ESLint flat config, wired to make lint / make lint-fix

**Files:**
- Create: `eslint.config.mjs`
- Modify: `Makefile:26-30` (the `lint` and `lint-fix` targets, and the
  `## == Quality ==` section header area)

**Interfaces:**
- Consumes: `typescript-eslint` and `eslint-plugin-astro`, installed by
  Task 6's `scripts/setup.sh` changes (not present yet when this task's diff
  is written, but `eslint.config.mjs` is static config text, not executed
  until a created project runs `pnpm install`).
- Produces: the `GUARD_SRC` Makefile variable, reused by Tasks 3 and 4.

- [ ] **Step 1: Write `eslint.config.mjs`**

```javascript
// ESLint flat config. typescript-eslint's config is spread before
// eslint-plugin-astro's, not after: eslint-plugin-astro's base config
// assigns astro-eslint-parser to *.astro files, and typescript-eslint's
// config sets a parser with no `files` restriction, so loading it second
// would overwrite that assignment and break Astro frontmatter parsing.
// See CONVENTIONS.md, "Quality toolchain".
import eslintPluginAstro from 'eslint-plugin-astro';
import tseslint from 'typescript-eslint';

export default [
  { ignores: ['dist/', '.astro/', 'node_modules/'] },
  ...tseslint.configs.recommended,
  ...eslintPluginAstro.configs.recommended,
];
```

- [ ] **Step 2: Add the `GUARD_SRC` variable and update the Quality section header**

In `Makefile`, the current section reads:

```makefile
## == Quality ==================================================================

check: ## Type check .astro and TypeScript (astro check)
	$(PNPM) astro check

lint: ## Lint (ESLint)
	$(PNPM) exec eslint .

lint-fix: ## Lint and apply fixes (ESLint)
	$(PNPM) exec eslint . --fix

format: ## Format (Prettier)
	$(PNPM) exec prettier --write .

format-check: ## Check formatting without writing (Prettier)
	$(PNPM) exec prettier --check .

test: ## Unit tests (Vitest)
	$(PNPM) exec vitest run

spell: ## Spell check (CSpell)
	$(PNPM) exec cspell --no-progress --no-must-find-files "**"
```

Replace it with (Tasks 3 and 4 fill in the `format`/`format-check`/`test`
bodies; this step only changes the header comment, `lint` and `lint-fix`):

```makefile
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
```

- [ ] **Step 3: Verify the guard pattern in isolation**

Run (from the repo root, this does not need `src/` to exist):

```bash
make -n lint && make -n format && make -n test
```

Expected: all three parse with no error (dry run only; Task 10 runs them for
real against a scaffolded project).

- [ ] **Step 4: Commit**

```bash
git add eslint.config.mjs Makefile
git commit -m "feat: add ESLint flat config and wire make lint / lint-fix"
```

---

### Task 3: Prettier config, wired to make format / make format-check

**Files:**
- Create: `.prettierrc.json`

**Interfaces:**
- Consumes: `FMT_PATHS` and `GUARD_SRC` from Task 2 (`format` and
  `format-check` targets already point at this file's config by convention;
  Prettier auto-discovers `.prettierrc.json`, no Makefile change needed here).

- [ ] **Step 1: Write `.prettierrc.json`**

```json
{
  "plugins": ["prettier-plugin-astro"],
  "overrides": [
    {
      "files": "*.astro",
      "options": { "parser": "astro" }
    }
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add .prettierrc.json
git commit -m "feat: add Prettier config with prettier-plugin-astro"
```

---

### Task 4: Vitest config, wired to make test

**Files:**
- Create: `vitest.config.ts`

**Interfaces:**
- Produces: the `getViteConfig` wiring Task 6's sample test
  (`src/components/Greeting.test.ts`) runs against.

- [ ] **Step 1: Write `vitest.config.ts`**

```typescript
/// <reference types="vitest/config" />
import { getViteConfig } from 'astro/config';

export default getViteConfig({
  test: {},
});
```

- [ ] **Step 2: Commit**

```bash
git add vitest.config.ts
git commit -m "feat: add Vitest config using astro/config's getViteConfig"
```

---

### Task 5: CSpell config, seeding the project words

**Files:**
- Create: `cspell.json`

**Interfaces:**
- Consumes: nothing new; `make spell` already calls
  `cspell --no-progress --no-must-find-files "**"`, and CSpell auto-discovers
  `cspell.json` at the repo root.

- [ ] **Step 1: Write `cspell.json`**

```json
{
  "version": "0.2",
  "language": "en-GB",
  "words": ["astro", "starlight", "pnpm", "corepack", "frontmatter"]
}
```

- [ ] **Step 2: Verify it is picked up**

```bash
pnpm exec cspell --no-progress --no-must-find-files "**" 2>&1 | head -20
```

Expected (once Task 6 installs `cspell` as a devDependency in a real
project): no "Unknown word" hits for `astro`, `starlight`, `pnpm`,
`corepack` or `frontmatter` anywhere those words appear in the repo's own
docs. This cannot run for real in the bare template yet (no
`node_modules`); Task 10 runs it for real.

- [ ] **Step 3: Commit**

```bash
git add cspell.json
git commit -m "feat: seed cspell project words"
```

---

### Task 6: setup.sh: install the toolchain, write the sample test

**Files:**
- Modify: `scripts/setup.sh` (the `--- Type checking ---` section and
  everything after it)

**Interfaces:**
- Consumes: package names decided in Tasks 2-5
  (`eslint`, `eslint-plugin-astro`, `typescript-eslint`, `prettier`,
  `prettier-plugin-astro`, `vitest`, `cspell`).
- Produces: `src/components/Greeting.astro` and
  `src/components/Greeting.test.ts` in a created project, which Task 10's
  live verification runs `make test` against.

- [ ] **Step 1: Extract the existing dependency-presence check into a helper**

In `scripts/setup.sh`, find the `--- Type checking ---` section. It currently
reads (abbreviated to the relevant loop):

```bash
TYPECHECK_DEPS=("@astrojs/check" "typescript@^6")
missing_dev=()
for spec in "${TYPECHECK_DEPS[@]}"; do
  dep="${spec%@^*}"
  if ! node -e '
    const fs = require("fs");
    const p = JSON.parse(fs.readFileSync("package.json", "utf8"));
    const dep = process.argv[1];
    const has = (p.dependencies && p.dependencies[dep]) || (p.devDependencies && p.devDependencies[dep]);
    process.exit(has ? 0 : 1);
  ' "$dep" 2>/dev/null; then
    missing_dev+=("$spec")
  fi
done
if [ "${#missing_dev[@]}" -gt 0 ]; then
  info "Installing type-checking dependencies: ${missing_dev[*]}"
  pnpm add -D "${missing_dev[@]}" || warn "Could not install ${missing_dev[*]}; 'make check' will prompt for them."
else
  success "Type-checking dependencies already present."
fi
```

Add a `dep_present` helper directly above this block (still inside the
`# --- Type checking ---` section, before `TYPECHECK_DEPS=(...)`):

```bash
dep_present() { # dep_present <package-name> -> 0 when already a dependency
  node -e '
    const fs = require("fs");
    const p = JSON.parse(fs.readFileSync("package.json", "utf8"));
    const dep = process.argv[1];
    const has = (p.dependencies && p.dependencies[dep]) || (p.devDependencies && p.devDependencies[dep]);
    process.exit(has ? 0 : 1);
  ' "$1" 2>/dev/null
}
```

Then simplify the existing loop to use it (replace the `if ! node -e ...`
block with a call to the new helper):

```bash
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
```

- [ ] **Step 2: Add the quality-toolchain install block**

Immediately after that block (still before `# --- Integrations ---`), add:

```bash
# --- Quality toolchain ---
# ESLint (eslint-plugin-astro) plus Prettier (prettier-plugin-astro) over
# Biome; typescript-eslint for typed linting. Decision, date and reopen
# triggers are in CONVENTIONS.md, "Quality toolchain". eslint-plugin-jsx-a11y
# is deliberately not installed: see the same section for why.
QUALITY_DEPS=(eslint eslint-plugin-astro typescript-eslint prettier prettier-plugin-astro vitest cspell)
missing_quality=()
for dep in "${QUALITY_DEPS[@]}"; do
  dep_present "$dep" || missing_quality+=("$dep")
done
if [ "${#missing_quality[@]}" -gt 0 ]; then
  info "Installing quality-toolchain dependencies: ${missing_quality[*]}"
  pnpm add -D "${missing_quality[@]}" || warn "Could not install ${missing_quality[*]}; make lint/format/test/spell will not work."
else
  success "Quality-toolchain dependencies already present."
fi
```

- [ ] **Step 3: Write the sample test after the scaffold is in place**

Find the end of the `# --- Astro scaffold ---` section, specifically the
line `success "Astro scaffold in place ($ASTRO_TEMPLATE)."` followed by the
`if [ "$SKIP_INSTALL" = "1" ]; then` block. Insert a new section between
them:

```bash
# --- Sample test ---
# A self-contained component and test that does not depend on anything the
# create-astro scaffold provides, so `make test` has something real to run
# immediately after setup, on every flavour. Copy the pattern for real
# components, or delete this one once real tests exist.
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

if [ "$SKIP_INSTALL" = "1" ]; then
```

(The last line above is the existing `if` that already follows; this step
only inserts the new block before it, it does not duplicate the `if`.)

- [ ] **Step 4: `bash -n` sanity check**

```bash
bash -n scripts/setup.sh
```

Expected: no output, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/setup.sh
git commit -m "feat: install the quality toolchain and write a sample test in setup.sh"
```

---

### Task 7: Remove the stale README and CI notes, restructure CI

**Files:**
- Modify: `README.md`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- None (docs and CI wiring only).

- [ ] **Step 1: Remove the stale README paragraph**

In `README.md`, in the `## Tasks` section, delete this paragraph (it follows
the `make clean` line of the task list, inside the fenced block's closing and
the next heading):

```markdown
`make lint`, `make format`, `make test` and `make spell` need the quality
toolchain wired up first. That is Stage 2 in the template's `PROMPTS.md` and
has not landed yet, so those four targets will not work on a project created
today.
```

Leave the rest of `README.md` unchanged.

- [ ] **Step 2: Restructure `.github/workflows/ci.yml`**

Replace the `quality` and `build` jobs (from the `# Needs live verification:`
comment through the end of the `build` job) with a single job that runs all
six checks in order:

```yaml
  # Needs live verification: this job has never actually run. It cannot run
  # on the bare template (guarded out above), and no project has been created
  # from this template and pushed yet to exercise it for real.
  quality:
    name: Type check, lint, format, spell, test, build
    needs: guard
    if: needs.guard.outputs.run == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: ${{ env.NODE_VERSION }}
      # After setup-node, so the corepack shims point at the Node just
      # installed rather than the runner's preinstalled one.
      - run: corepack enable pnpm
      - run: pnpm install --frozen-lockfile
      - name: Type check (astro check)
        run: make check
      - name: Lint (ESLint)
        run: make lint
      - name: Format check (Prettier)
        run: make format-check
      - name: Spell check (CSpell)
        run: make spell
      - name: Unit tests (Vitest)
        run: make test
      - name: Production build
        run: make build

  # Browser checks (axe-core accessibility scan plus Playwright visual
  # regression, sharing one scan-urls.json) land in Stage 3. See CONVENTIONS.md
  # for the contract they will implement.
```

(The final comment block already exists at the end of the file; this step
just confirms it survives unchanged after the `build` job above it is
removed.)

- [ ] **Step 3: YAML sanity check**

```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo OK
```

Expected: `OK`. If no `yaml` module is available locally, `scripts/test-template.sh`
(Task 9) checks this too via its own `yaml_parse` fallback.

- [ ] **Step 4: Confirm the `${{ }}` count is unchanged**

```bash
git diff .github/workflows/ci.yml | grep -c '\${{' 
```

This counts `${{` occurrences in the diff output as a sanity spot-check; the
real assertion is `scripts/test-template.sh`'s `ci_before`/`ci_after` count
comparison in Task 9's full run, which must match exactly.

- [ ] **Step 5: Commit**

```bash
git add README.md .github/workflows/ci.yml
git commit -m "docs: drop the stale Stage 2 pending notes, run quality checks in one ordered CI job"
```

---

### Task 8: Update CHANGELOG.md and the maintainer docs

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `template-docs/PROMPTS.md`
- Modify: `template-docs/memory.md`

**Interfaces:**
- None (docs only). `template-docs/` is maintainer-only and removed by
  `init.sh`; `CHANGELOG.md` is not.

- [ ] **Step 1: Add Stage 2 entries to `CHANGELOG.md`**

In the `## [Unreleased]` section, under `### Added`, add (after the existing
`.github/workflows/ci.yml` bullet and before the `template-docs/PROMPTS.md`
bullet):

```markdown
- `eslint.config.mjs`, `.prettierrc.json`, `vitest.config.ts`, `cspell.json`:
  quality toolchain config at the template root. `scripts/setup.sh` installs
  the matching devDependencies and writes a self-contained sample component
  and test (`src/components/Greeting.astro` / `.test.ts`) once the scaffold
  exists. `make lint`, `make lint-fix`, `make format`, `make format-check`
  and `make test` now work on a created project; all five no-op cleanly with
  a message on the bare template, which ships no `src/`.
```

Under `### Verified`, add:

```markdown
- `eslint-plugin-astro` 3.1.0 peer-requires ESLint `>=10.0.0`; its flat
  config must load after `typescript-eslint`'s, or `typescript-eslint`'s
  parser assignment overwrites `astro-eslint-parser` for `.astro` files.
  `eslint-plugin-jsx-a11y` cannot be installed alongside it yet (its peer
  range caps at ESLint `^9`). `typescript-eslint` 8.70.0 peer-requires
  `typescript >=4.8.4 <6.1.0`, which our `^6` pin (currently `6.0.3`)
  satisfies today. Full detail and reopen triggers in `CONVENTIONS.md`,
  "Quality toolchain".
```

Update the `### Needs live verification` list: remove the bullet
`` `make lint`, `make format`, `make test` and `make spell`, which have no
configuration behind them until Stage 2.`` and replace it with:

```markdown
- The restructured `quality` CI job (`check`, `lint`, `format-check`,
  `spell`, `test`, `build` in one job). Passed locally against a scaffolded
  minimal project on 2026-09-09 (see `template-docs/memory.md`); has not yet
  run in GitHub Actions on a created project.
```

- [ ] **Step 2: Update `template-docs/PROMPTS.md`**

Change the Stage 2 status line from:

```markdown
- **Stage 2, quality toolchain: PENDING.**
```

to:

```markdown
- **Stage 2, quality toolchain: DONE.** ESLint (`eslint-plugin-astro`) plus
  Prettier (`prettier-plugin-astro`), decided 2026-09-09 over Biome (still
  experimental for Astro). `typescript-eslint`'s parser must load before
  `eslint-plugin-astro`'s in `eslint.config.mjs`, or Astro frontmatter
  parsing breaks. Full rationale and reopen triggers in `CONVENTIONS.md`.
```

- [ ] **Step 3: Update `template-docs/memory.md`**

In the `## Facts verified without a live run (2026-09-09)` section, extend
the `eslint-plugin-astro` bullet to record the new findings:

```markdown
- `eslint-plugin-astro` 3.1.0, `typescript-eslint` 8.70.0, `prettier` 3.9.6,
  `prettier-plugin-astro` 1.0.0, `vitest` 5.0.0, `cspell` 10.3.0. Confirmed
  live in a throwaway sandbox (not just read from the registry): the flat
  config order matters (`typescript-eslint` before `eslint-plugin-astro`, or
  the astro parser gets overwritten), `eslint-plugin-jsx-a11y` cannot install
  alongside ESLint 10, and `typescript-eslint`'s `typescript <6.1.0` peer
  range still fits our `^6` pin because only `6.0.x` has shipped.
```

In the `## Open questions` section, remove the bullet:

```markdown
- Quality toolchain: flat-config ESLint plus Prettier is the assumed answer,
  but the decision and the wiring are Stage 2 and not made yet. Until then
  `make lint`, `make format`, `make test` and `make spell` have no
  configuration or devDependencies behind them, and the `quality` CI job will
  fail on a created project.
```

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md template-docs/PROMPTS.md template-docs/memory.md
git commit -m "docs: record Stage 2 completion in the changelog and maintainer docs"
```

---

### Task 9: Extend scripts/test-template.sh, run the full suite

**Files:**
- Modify: `scripts/test-template.sh:34` (the `VERBATIM_FILES` array)

**Interfaces:**
- Consumes: the four new root config files from Tasks 2-5.
- Produces: nothing new for other tasks; this is the regression proof.

- [ ] **Step 1: Add the new config files to `VERBATIM_FILES`**

In `scripts/test-template.sh`, the array currently reads:

```bash
VERBATIM_FILES=(.editorconfig .vscode/extensions.json CHANGELOG.md)
```

Change it to:

```bash
VERBATIM_FILES=(.editorconfig .vscode/extensions.json CHANGELOG.md \
  eslint.config.mjs .prettierrc.json vitest.config.ts cspell.json)
```

This reuses the existing `assert_common` loop (`for f in
"${VERBATIM_FILES[@]}"; do diff -q ...`), which already runs for every
combination in `COMBOS`, so no other change to the suite is needed: each of
the four new files gets diffed byte-for-byte between the repo root and every
post-`init.sh` output directory automatically.

- [ ] **Step 2: `bash -n` sanity check**

```bash
bash -n scripts/test-template.sh
```

Expected: no output, exit 0.

- [ ] **Step 3: Run the full regression suite and show the output**

```bash
./scripts/test-template.sh
```

Expected: every combination (`minimal/static`, `blog/static`,
`starlight/static`, `minimal/ssr`, the interactive `blog/static` run, and
flag validation) passes, including four new `VERBATIM_FILES` assertions per
combination. Compare the final `pass:`/`fail: 0` line against the prior
baseline of 257 passes recorded in `template-docs/PROMPTS.md`; the count will
be higher (new assertions), and `fail: 0` must hold. If anything fails, fix
it before moving to Task 10; do not silence a failing assertion.

- [ ] **Step 4: Commit**

```bash
git add scripts/test-template.sh
git commit -m "test: assert the new quality-toolchain config files survive init.sh verbatim"
```

---

### Task 10: Live verification against a scaffolded minimal project

**Files:** none (verification only; may update `template-docs/memory.md` with
the result).

**Interfaces:**
- Consumes: everything from Tasks 1-9, exercised together for the first
  time in a real scaffold.

- [ ] **Step 1: Stage a throwaway copy and initialise it**

```bash
TMP="$(mktemp -d)"
rsync -a --exclude='.git' --exclude='node_modules' --exclude='dist' \
  --exclude='.astro' . "$TMP"/
cd "$TMP"
./scripts/init.sh --defaults --site quality-check --flavour minimal --deploy-target static
```

Expected: exits 0, `TEMPLATE.md`, `scripts/test-template.sh` and
`template-docs/` are gone, `template.answers` is written.

- [ ] **Step 2: Run setup.sh and show its output**

```bash
./scripts/setup.sh
```

Expected: Node/pnpm checks pass, the astro scaffold is copied in, "Quality-toolchain
dependencies" are installed (watch for the `QUALITY_DEPS` install line from
Task 6), the default integration and (for `static`) no adapter are added, and
the final line is "Sample test written (src/components/Greeting.astro +
Greeting.test.ts)." Show the full terminal output; do not summarise it away
if anything warns or fails.

- [ ] **Step 3: Run every quality target and show the output**

```bash
make check
make lint
make format-check
make spell
make test
make build
```

Expected: `make check` 0 errors, `make lint` 0 errors (the sample component
is written to already satisfy the ESLint config), `make format-check` passes
(the sample component and test are written pre-formatted), `make spell`
finds no unknown words, `make test` shows 1 passed test file / 1 passed test
(`Greeting`), `make build` completes. Report the actual pass/fail counts from
each command's output, not an inferred summary.

- [ ] **Step 4: Clean up the throwaway copy**

```bash
cd -
rm -rf "$TMP"
```

State the blast radius before running this: it only deletes the `mktemp -d`
throwaway directory staged in Step 1, nothing under the repo working
directory.

- [ ] **Step 5: Record the result in `template-docs/memory.md`**

In the `## Verification status` table, this is a toolchain check, not a new
flavour/deploy-target row, so instead add a short new subsection right after
the table (before `## Bugs found by the live runs`):

```markdown
## Quality toolchain verification

Live on <actual date run>, minimal/static, Node <actual>, pnpm <actual>:
`setup.sh` installed the quality-toolchain devDependencies and wrote the
sample test. `make check`, `make lint`, `make format-check`, `make spell`,
`make test` (1 passed) and `make build` all passed. The restructured GitHub
Actions `quality` job itself has not run in CI yet; that still needs a real
push from a created project.
```

Fill in the actual date, Node version and pnpm version observed in Step 2,
not placeholders.

- [ ] **Step 6: Commit**

```bash
git add template-docs/memory.md
git commit -m "docs: record the local quality-toolchain live verification"
```

---

## Self-review notes

- **Spec coverage:** decision + date + reopen trigger (Task 1); flat-config
  and TypeScript-range verification before writing config (done up front,
  recorded as "Verified facts"); config files at template root wired to the
  four existing Makefile targets, no-op on bare template (Tasks 2-4, 6);
  `astro check` dated note (Task 1 covers both pins in one place rather than
  duplicating the TypeScript note, since it is one coherent decision);
  Vitest with `getViteConfig` and a sample test (Task 4, Task 6 Step 3);
  cspell seeded words (Task 5); CI job order with skip-with-message guards
  (Task 7, guards live in the Makefile per Task 2 rather than duplicated in
  CI); `test-template.sh` extended and run, then the new targets run against
  a scaffolded project with output shown (Tasks 9-10). No spec line was left
  without a task.
- **Placeholder scan:** no TBD/TODO, no "add appropriate handling", no
  "similar to Task N" (Task 6 Step 3's cross-reference to the existing `if
  [ "$SKIP_INSTALL"... ]` line is exact copy-paste text used as an anchor,
  not a stand-in for real content). Task 10 explicitly calls out reporting
  actual observed output, not inferred summaries, consistent with the
  project's "needs live verification" house rule.
- **Type/name consistency:** `GUARD_SRC` and `FMT_PATHS` (Task 2) are used
  identically in the `format`/`format-check`/`test` target bodies; `QUALITY_DEPS`
  and `dep_present` (Task 6) match the existing `TYPECHECK_DEPS` pattern's
  naming style; `src/components/Greeting.astro` / `Greeting.test.ts` names
  match between Task 6 (writer) and Task 10 (verification, expects "1
  passed").
