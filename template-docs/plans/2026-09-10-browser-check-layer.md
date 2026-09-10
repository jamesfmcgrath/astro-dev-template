# Browser Check Layer (Stage 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the browser-checks contract `CONVENTIONS.md` already
declares: axe-core accessibility scanning and Playwright `toHaveScreenshot`
visual regression, sharing one `scan-urls.json`, wired into `make a11y`,
`make vrt`, `make vrt-update` and a new `browser` CI job.

**Architecture:** `scan-urls.json` lives at the repo root and is rewritten by
`scripts/init.sh` from `FLAVOUR` (not templated with `{{TOKENS}}`, just
regenerated). `scripts/a11y-scan.mjs` is adapted from
`localgov-drupal-dev-template`'s script of the same name (read from a real
checkout, not from memory): axe-core via `@axe-core/playwright`, same
`scan-urls.json` / `--base-url=` contract, default base URL swapped for
Astro's own (`http://localhost:4321`). `playwright.config.mjs` and
`tests/vrt/vrt.spec.mjs` are net new, patterned on the same reference
project's separately net-new Playwright VRT setup. `scripts/browser-check.sh`
is a fourth committed script (build, serve with `astro preview`, wait, run
one check, always tear down) that `make a11y` / `make vrt` / `make vrt-update`
call; the `browser` CI job inlines the same build-serve sequence itself,
because it runs both checks against one server and needs CI-specific
baseline/artifact branching a shared script would not simplify.
`scripts/setup.sh` installs the two new devDependencies and the Playwright
Chromium browser the same way it already installs the quality toolchain.

**Tech Stack:** `@axe-core/playwright` 4.13.0, `@playwright/test` 1.63.0,
Astro's own `astro preview` (port 4321 default, `@astrojs/node` supports it
through its `previewEntrypoint`).

**Spec:** The user's Stage 3 prompt, reproduced in `template-docs/PROMPTS.md`
under "Stage 3, browser checks", and the "Browser checks" section this plan
rewrites in `CONVENTIONS.md`. Every fact below was verified against a live
checkout or the npm registry before being written into this plan; nothing is
inferred from memory.

## Global Constraints

- No em dashes anywhere: prose, comments, commit messages, script output.
- `scripts/browser-check.sh` (new) is committed `100755`, `#!/usr/bin/env
  bash`, and holds to the bash 3.2 / BSD-userland floor in `CONVENTIONS.md`'s
  script contract (no `sed -i` without an explicit backup suffix, no `tr`
  ranges, no GNU-only flags, no bash 4+ syntax), same as `init.sh` and
  `setup.sh`, because it runs on a developer's Mac as well as in CI. The
  `browser` CI job's own `run:` steps do **not** need this floor: they only
  ever execute on `ubuntu-latest`, exactly like the existing `quality` job's
  steps already do.
- Only `{{UPPER_SNAKE}}` names are template tokens. None of the new files in
  this plan use one (verified below), so they go into `test-template.sh`'s
  `VERBATIM_FILES` check, not `init.sh` substitution. `scan-urls.json` is the
  one exception: its content is set by `init.sh` from `FLAVOUR`, not
  substituted, so it gets its own assertion instead.
- GitHub Actions `${{ }}` expressions must never be touched. The new `browser`
  job's own expressions (`${{ env.NODE_VERSION }}`, `${{
  steps.vrt.outputs.baselines_generated == 'true' }}`, etc.) follow the exact
  spacing style already used elsewhere in `.github/workflows/ci.yml`.
- Run `scripts/test-template.sh` before calling any script change done. No
  network, no package manager in that suite; `node --check` and `bash -n` are
  syntax-only and fit its no-network rule.
- WCAG target: 2.2 AA, per `AGENTS.md`, "Accessibility", and the House rules
  in `CONVENTIONS.md`.
- Anything not actually executed is labelled "needs live verification" and
  says exactly what was and was not observed (Task 10, and the `browser` CI
  job's own comment).

---

## Verified facts (read before Task 1)

1. **`scripts/a11y-scan.mjs` reference content**, read from a live checkout of
   `github.com/jamesfmcgrath/localgov-drupal-dev-template` (not from
   description): a standalone Node ESM script, `chromium.launch()` once,
   reads `scan-urls.json` from the repo root, walks each path with
   `page.goto(..., { waitUntil: 'load' })`, runs `new AxeBuilder({ page
   }).withTags(WCAG_TAGS).analyze()` where `WCAG_TAGS = ['wcag2a', 'wcag2aa',
   'wcag21aa', 'wcag22aa']`, reports violations to stdout/stderr, and sets
   `process.exitCode = 1` on any load failure or violation. Default base URL
   is `http://127.0.0.1:8888` (the Drupal reference's PHP/drush server); the
   only functional change this plan makes is that default, to Astro's own.
   `.claude/commands/a11y-check.md` in the same checkout is the command file
   Task 8 ports.
2. **Astro server defaults**, read from `withastro/astro`'s source
   (`packages/astro/src/core/config/schemas/defaults.ts`): `server.port`
   defaults to `4321`, `server.host` defaults to `false` (binds to
   `localhost`). `packages/astro/src/cli/preview/index.ts` confirms `astro
   preview` accepts `--port` (`Defaults to 4321`) and `--host`, the same flags
   as `astro dev`. `packages/integrations/node/src/index.ts` registers
   `previewEntrypoint: '@astrojs/node/preview.js'`, confirming `astro preview`
   works for an SSR build with the `node` adapter too, not just a static one.
3. **Real default page paths per flavour**, read from live checkouts of
   `withastro/astro`'s `examples/blog` and `withastro/starlight`'s
   `examples/basics` (the exact upstream sources `create-astro` resolves
   `blog` and `starlight` to, per `TEMPLATE.md`'s `ASTRO_TEMPLATE` mapping):
   - `blog`: posts are Markdown files under `src/content/blog/`, routed by
     `src/pages/blog/[...slug].astro`'s `getStaticPaths` using
     `post.id` (the glob loader's id is the file's path relative to
     `src/content/blog` minus extension). `first-post.md` exists in the
     example content, giving a real, stable path: `/blog/first-post/`. This
     matches `template-docs/memory.md`'s already-recorded live build count
     (blog/static: `make build` produced 8 pages: `/`, `/about`, `/blog/`,
     and the 5 example posts).
   - `starlight`: `src/content/docs/index.mdx` is the site root (`/`).
     `astro.config.mjs`'s sidebar references `guides/example` via
     `src/content/docs/guides/example.md`, giving `/guides/example/`. Matches
     the already-recorded live build count (starlight/static: 4 pages: index,
     `guides/example`, `reference/example`, 404).
4. **Vitest would otherwise run the new Playwright spec.** Read from
   `vitest-dev/vitest`'s source (`packages/vitest/src/defaults.ts`):
   `defaultInclude = ['**/*.{test,spec}.?(c|m)[jt]s?(x)']` matches
   `tests/vrt/vrt.spec.mjs`, and `defaultExclude` is only `['**/node_modules/**',
   '**/.git/**']`, nothing else. Without an explicit exclude, `make test`
   (`vitest run`) would try to execute the Playwright spec with its own
   runner and fail, since `@playwright/test`'s `test`/`expect` are not
   Vitest's. `vitest/config` re-exports `configDefaults` (confirmed in
   `packages/vitest/src/public/config.ts`), so `vitest.config.ts` can extend
   the real default exclude list rather than hardcoding a guess at it. Task 4
   fixes this.
5. **`eslint .` has no config-level ignore for Playwright's own output
   directories.** `playwright-report/`, `test-results/` and `blob-report/`
   are gitignored but ESLint's flat config in this repo does not read
   `.gitignore` (confirmed by the existing config explicitly listing
   `dist/**`, `.astro/**`, `node_modules/**`, which are also gitignored, as
   its own `ignores` array rather than relying on git). Once `make vrt` runs
   locally, `playwright-report/` and `test-results/` exist on disk and `make
   lint` would otherwise try to lint whatever they contain. Task 4 adds them
   to the same `ignores` array.
6. **Package versions**, read live from the npm registry (`registry.npmjs.org`):
   `@axe-core/playwright` 4.13.0 (peer `playwright-core >= 1.0.0`, bundles
   `axe-core ~4.13.0`), `@playwright/test` 1.63.0 (`engines.node >=20`, well
   under this template's `MIN_NODE=22.12.0`). Neither needs a version pin:
   no peer range collides with anything else this template installs.
7. **GitHub Actions action versions**, read live via `gh release list`:
   `actions/upload-artifact` latest is `v7.0.1` (major `v7`), matching the
   major already used for `actions/checkout@v7` and `actions/setup-node@v7`
   elsewhere in `ci.yml`.

---

### Task 1: Rewrite the "Browser checks" contract in CONVENTIONS.md

**Files:**
- Modify: `CONVENTIONS.md:160-170`

**Interfaces:**
- Produces: the section every later task's comments point back to.

- [ ] **Step 1: Replace the section**

Replace the current "Browser checks" section (`CONVENTIONS.md:160-170`, from
`## Browser checks` up to but not including `## House rules`) with:

```markdown
## Browser checks

Accessibility (axe-core via Playwright, `scripts/a11y-scan.mjs`) and visual
regression (`@playwright/test`'s `toHaveScreenshot`, `tests/vrt/vrt.spec.mjs`)
share one `scan-urls.json` at the repo root. `scripts/init.sh` sets its
content from `FLAVOUR`: `["/"]` for `minimal`, plus one real content page from
the flavour's own create-astro / starlight example content for `blog`
(`/blog/first-post/`) and `starlight` (`/guides/example/`), so a path a
flavour does not serve is never a false failure. Edit the list by hand as real
content replaces the example pages.

Both checks run against a production build served with `astro preview`:
`astro build` for a static project, the same command for an SSR one, since
the adapter is already registered in `astro.config.mjs` by `setup.sh` and
`@astrojs/node` supports `astro preview` through its own preview entrypoint.
`make a11y` and `make vrt` build and serve locally through
`scripts/browser-check.sh`, a fourth committed script alongside
`init.sh`/`setup.sh`/`test-template.sh`: an ordinary dev-task helper, not part
of the tokeniser lifecycle those three define, but held to the same
portability floor below. The `browser` CI job does the same build-serve
sequence inline instead of calling that script, so it can run the
accessibility scan and the visual regression test against one server rather
than building and serving twice.

Visual regression baselines are generated and compared on Linux only, because
font rendering makes cross-OS baselines flaky, so only
`tests/vrt/__screenshots__/linux/` is authoritative and committed;
`tests/vrt/__screenshots__/darwin/` and `.../win32/` are gitignored, and
`make vrt` / `make vrt-update` on a Mac are advisory only. In CI, a missing
`linux/` baseline is not a failure: the job generates it with
`--update-snapshots` and uploads it as a build artifact to review and commit;
once a baseline exists, a genuine diff fails the job and the Playwright HTML
report uploads as an artifact.

`scripts/a11y-scan.mjs` is adapted from `localgov-drupal-dev-template`'s
script of the same name (read from a checkout, not reimplemented from
description): the same WCAG tag set (`wcag2a`, `wcag2aa`, `wcag21aa`,
`wcag22aa`, i.e. WCAG 2.2 AA and everything it supersedes) and the same
`scan-urls.json` / `--base-url=` contract, with the default base URL changed
from the Drupal reference's PHP dev server to Astro's own default
(`http://localhost:4321`). The visual regression half
(`playwright.config.mjs`, `tests/vrt/vrt.spec.mjs`) is net new here, patterned
on the same reference project's own, separately net-new, Playwright VRT
setup: full-page screenshots, animations disabled, `maxDiffPixelRatio: 0.01`.

WCAG target: 2.2 AA, per the House rules below and `AGENTS.md`.
```

- [ ] **Step 2: Commit**

```bash
git add CONVENTIONS.md
git commit -m "docs: record the browser-checks implementation in CONVENTIONS.md"
```

---

### Task 2: scan-urls.json, set per flavour by init.sh

**Files:**
- Create: `scan-urls.json`
- Modify: `scripts/init.sh:200-204` (insert between the `ADAPTER` case and
  the "Record the resolved answers" comment)
- Modify: `scripts/test-template.sh` (new assertion, called from `run_combo`)

**Interfaces:**
- Produces: `scan-urls.json` at the repo root, read by `scripts/a11y-scan.mjs`
  (Task 3) and `tests/vrt/vrt.spec.mjs` (Task 4).

- [ ] **Step 1: Ship the bare-template default**

```bash
cat > scan-urls.json <<'JSON'
[
  "/"
]
JSON
```

- [ ] **Step 2: Set it from FLAVOUR in init.sh**

In `scripts/init.sh`, insert immediately after line 202 (`*) ADAPTER=""
;;` / `esac`, i.e. right before the `# Record the resolved answers` comment
at line 204):

```bash

# scan-urls.json: the shared page list axe-core and the Playwright visual
# regression test both read (see CONVENTIONS.md, "Browser checks"). Set from
# FLAVOUR so the default list matches pages the flavour actually builds: the
# front page always, plus one real content page for blog and starlight, taken
# from the create-astro / starlight example content each flavour scaffolds.
# Edit the file later as real content replaces the example pages.
case "$FLAVOUR" in
  blog)      SCAN_URLS='[
  "/",
  "/blog/first-post/"
]' ;;
  starlight) SCAN_URLS='[
  "/",
  "/guides/example/"
]' ;;
  *)         SCAN_URLS='[
  "/"
]' ;;
esac
printf '%s\n' "$SCAN_URLS" > scan-urls.json
```

- [ ] **Step 3: Add the JSON-validity check to `assert_common`**

In `scripts/test-template.sh`, in `assert_common` (after the existing
`cspell.json` check block, before the `yaml_parse` check), add:

```bash
  if json_parse "$dir/scan-urls.json"; then
    pass "$label: scan-urls.json is valid JSON"
  else
    fail "$label: scan-urls.json is not valid JSON"
  fi
```

- [ ] **Step 4: Add a per-flavour content assertion**

In `scripts/test-template.sh`, add a new function near `assert_substitutions`:

```bash
# scan-urls.json's content depends only on FLAVOUR, set directly by init.sh
# rather than substituted, so it gets its own comparison instead of living in
# assert_substitutions.
assert_scan_urls() { # assert_scan_urls <dir> <label> <flavour>
  local dir="$1" label="$2" flavour="$3" expected
  case "$flavour" in
    blog)      expected='["/", "/blog/first-post/"]' ;;
    starlight) expected='["/", "/guides/example/"]' ;;
    *)         expected='["/"]' ;;
  esac
  if python3 -c "
import json, sys
expected = json.loads(sys.argv[1])
actual = json.load(open(sys.argv[2]))
sys.exit(0 if actual == expected else 1)
" "$expected" "$dir/scan-urls.json" 2>/dev/null; then
    pass "$label: scan-urls.json matches $flavour defaults"
  else
    fail "$label: scan-urls.json does not match $flavour defaults (got: $(cat "$dir/scan-urls.json" 2>/dev/null | tr '\n' ' '))"
  fi
}
```

Then call it from `run_combo`, right after the existing
`assert_substitutions` call:

```bash
  assert_scan_urls "$tmp_dir" "$label" "$flavour"
```

- [ ] **Step 5: Run the suite**

```bash
./scripts/test-template.sh
```

Expected: every combo's new `scan-urls.json` assertions pass (4 combos plus
the interactive blog/static run, 6 new checks total: 1 JSON-validity + 1
content-match per combo, minus the JSON-validity one already folded into
`assert_common`'s per-combo run).

- [ ] **Step 6: Commit**

```bash
git add scan-urls.json scripts/init.sh scripts/test-template.sh
git commit -m "feat: add scan-urls.json, set per flavour by init.sh"
```

---

### Task 3: scripts/a11y-scan.mjs, adapted from the Drupal reference

**Files:**
- Create: `scripts/a11y-scan.mjs`
- Modify: `scripts/test-template.sh` (VERBATIM_FILES entry, one-time
  `node --check` / executable-bit block)

**Interfaces:**
- Consumes: `scan-urls.json` (Task 2).
- Produces: `node scripts/a11y-scan.mjs [--base-url=URL]`, exit 0 (no
  violations, no load failures) or 1 otherwise. Task 6
  (`scripts/browser-check.sh`) and Task 7 (the `browser` CI job) both invoke
  it with this exact contract.

- [ ] **Step 1: Write the script**

```javascript
#!/usr/bin/env node
import { chromium } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'];

function parseArgs(argv) {
  let baseUrl = 'http://localhost:4321';
  for (const arg of argv) {
    if (arg.startsWith('--base-url=')) {
      baseUrl = arg.slice('--base-url='.length);
    }
  }
  return { baseUrl };
}

function loadUrls() {
  const configPath = path.join(__dirname, '..', 'scan-urls.json');
  const raw = readFileSync(configPath, 'utf8');
  const paths = JSON.parse(raw);
  if (!Array.isArray(paths) || paths.length === 0) {
    throw new Error(`${configPath} must contain a non-empty JSON array of paths`);
  }
  return paths;
}

function reportViolations(url, violations) {
  for (const violation of violations) {
    const sample = violation.nodes[0]?.target?.join(' ') ?? '(no selector)';
    console.log(
      `[VIOLATION] ${url} - ${violation.id} (${violation.impact}) ` +
      `tags=${violation.tags.join(',')} count=${violation.nodes.length} sample="${sample}"`
    );
  }
}

async function main() {
  const { baseUrl } = parseArgs(process.argv.slice(2));
  const paths = loadUrls();

  const browser = await chromium.launch();
  let totalViolations = 0;
  let loadFailures = 0;

  try {
    const context = await browser.newContext();
    const page = await context.newPage();
    for (const urlPath of paths) {
      const url = new URL(urlPath, baseUrl).toString();
      const response = await page.goto(url, { waitUntil: 'load' });
      if (!response || response.status() >= 400) {
        const status = response ? response.status() : 'no response';
        console.error(`[LOAD FAILURE] ${url} - HTTP status ${status}`);
        loadFailures += 1;
        continue;
      }
      const results = await new AxeBuilder({ page }).withTags(WCAG_TAGS).analyze();
      reportViolations(url, results.violations);
      totalViolations += results.violations.length;
    }
  } finally {
    await browser.close();
  }

  if (loadFailures > 0) {
    console.error(`\n${loadFailures} page(s) failed to load across ${paths.length} page(s).`);
    process.exitCode = 1;
  }

  if (totalViolations > 0) {
    console.error(`\n${totalViolations} accessibility violation(s) found across ${paths.length} page(s).`);
    process.exitCode = 1;
  } else if (loadFailures === 0) {
    console.log(`\nNo accessibility violations found across ${paths.length} page(s) (${WCAG_TAGS.join(', ')}).`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
```

- [ ] **Step 2: Make it executable**

```bash
chmod 755 scripts/a11y-scan.mjs
```

- [ ] **Step 3: Add it to VERBATIM_FILES**

In `scripts/test-template.sh`, add `scripts/a11y-scan.mjs` to the
`VERBATIM_FILES` array (it holds no `{{TOKENS}}`, so it must survive
`init.sh` byte for byte, same as `eslint.config.mjs`):

```bash
VERBATIM_FILES=(.editorconfig .vscode/extensions.json CHANGELOG.md \
  eslint.config.mjs .prettierrc.json vitest.config.ts cspell.json \
  scripts/a11y-scan.mjs)
```

- [ ] **Step 4: Add a one-time `node --check` block**

These files are token-free and identical across every combo, so check them
once against the repo's own committed copies rather than once per combo. Add
a new section in `scripts/test-template.sh`, after the "bare template still
holds its tokens" guard near the top and before the `COMBOS` loop:

```bash
echo ""
echo -e "${BOLD}== browser-check scripts: syntax ==${RESET}"
NODE_CHECK_FILES=(scripts/a11y-scan.mjs)
for f in "${NODE_CHECK_FILES[@]}"; do
  if command -v node >/dev/null 2>&1 && node --check "$f" 2>/dev/null; then
    pass "node --check $f"
  elif ! command -v node >/dev/null 2>&1; then
    echo "  no node available, skipping node --check $f" >&2
  else
    fail "node --check $f"
  fi
done
```

(Task 4 and Task 6 each add one more entry to `NODE_CHECK_FILES` and a
parallel `bash -n` block; this step establishes the pattern.)

- [ ] **Step 5: Run the suite**

```bash
./scripts/test-template.sh
```

Expected: `node --check scripts/a11y-scan.mjs` passes, and
`scripts/a11y-scan.mjs survives init.sh verbatim` passes for every combo.

- [ ] **Step 6: Commit**

```bash
git add scripts/a11y-scan.mjs scripts/test-template.sh
git commit -m "feat: add scripts/a11y-scan.mjs, adapted from localgov-drupal-dev-template"
```

---

### Task 4: Playwright VRT (playwright.config.mjs, tests/vrt/vrt.spec.mjs), fix the Vitest and ESLint collisions

**Files:**
- Create: `playwright.config.mjs`
- Create: `tests/vrt/vrt.spec.mjs`
- Modify: `vitest.config.ts` (exclude `tests/vrt/**`, see Verified fact 4)
- Modify: `eslint.config.mjs:13` (ignore Playwright's own output dirs, see
  Verified fact 5)
- Modify: `scripts/test-template.sh` (VERBATIM_FILES, `node --check`)

**Interfaces:**
- Consumes: `scan-urls.json` (Task 2).
- Produces: `npx playwright test tests/vrt [--update-snapshots]`, reading
  `VRT_BASE_URL` (default `http://localhost:4321`). Task 6 and Task 7 both
  invoke it with this exact contract.

- [ ] **Step 1: Write `playwright.config.mjs`**

```javascript
import { defineConfig, devices } from '@playwright/test';

// Scoped to tests/vrt only, so a bare `npx playwright test` does not pick up
// anything else the project might add later under tests/.
export default defineConfig({
  testDir: './tests/vrt',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: [['html', { outputFolder: 'playwright-report', open: 'never' }], ['list']],
  // Baselines are OS-suffixed by directory rather than filename, so the
  // Linux ones (authoritative, committed) and the macOS ones (advisory,
  // gitignored) never collide. See CONVENTIONS.md, "Browser checks", for the
  // baseline policy.
  snapshotPathTemplate: '{testDir}/__screenshots__/{platform}/{testFileName}/{arg}{ext}',
  use: {
    viewport: { width: 1280, height: 720 },
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
```

- [ ] **Step 2: Write `tests/vrt/vrt.spec.mjs`**

```javascript
import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BASE_URL = process.env.VRT_BASE_URL || 'http://localhost:4321';

function loadPaths() {
  const configPath = path.join(__dirname, '..', '..', 'scan-urls.json');
  const raw = readFileSync(configPath, 'utf8');
  const paths = JSON.parse(raw);
  if (!Array.isArray(paths) || paths.length === 0) {
    throw new Error(`${configPath} must contain a non-empty JSON array of paths`);
  }
  return paths;
}

function snapshotName(urlPath) {
  if (urlPath === '/') {
    return 'front-page.png';
  }
  return `${urlPath.replace(/^\/+|\/+$/g, '').replace(/\/+/g, '-')}.png`;
}

for (const urlPath of loadPaths()) {
  test(`visual regression: ${urlPath}`, async ({ page }) => {
    await page.goto(new URL(urlPath, BASE_URL).toString(), { waitUntil: 'load' });
    await expect(page).toHaveScreenshot(snapshotName(urlPath), {
      fullPage: true,
      animations: 'disabled',
      maxDiffPixelRatio: 0.01,
    });
  });
}
```

`snapshotName` strips both leading and trailing slashes before turning inner
slashes into dashes (the Drupal reference only strips leading slashes,
because its own paths like `/node/5` never had a trailing one; this
template's default paths, e.g. `/blog/first-post/`, do, so the reference
regex would produce a trailing `-` before `.png`).

- [ ] **Step 3: Fix the Vitest / Playwright spec collision**

Replace `vitest.config.ts` in full:

```typescript
/// <reference types="vitest/config" />
import { getViteConfig } from 'astro/config';
import { configDefaults } from 'vitest/config';

export default getViteConfig({
  test: {
    // tests/vrt holds Playwright specs (visual regression). Vitest's default
    // include pattern (**/*.spec.mjs among others) would otherwise pick them
    // up and try to run them with its own runner, which does not understand
    // @playwright/test's test()/expect(). Verified against Vitest's
    // published defaults (packages/vitest/src/defaults.ts): defaultExclude
    // is only node_modules and .git, so this needs to be explicit.
    exclude: [...configDefaults.exclude, 'tests/vrt/**'],
  },
});
```

- [ ] **Step 4: Fix the ESLint ignore list**

In `eslint.config.mjs:13`, replace:

```javascript
  { ignores: ['dist/**', '.astro/**', 'node_modules/**'] },
```

with:

```javascript
  {
    ignores: [
      'dist/**',
      '.astro/**',
      'node_modules/**',
      // Playwright's own output, not this project's code; generated by
      // "make vrt" / "make a11y" and never committed (see .gitignore).
      'playwright-report/**',
      'test-results/**',
      'blob-report/**',
    ],
  },
```

- [ ] **Step 5: Make the spec executable-neutral, add both files to VERBATIM_FILES**

`playwright.config.mjs` and `tests/vrt/vrt.spec.mjs` are run through `node`
via `playwright test`, not executed directly, so they do not need the
executable bit. Add both to `VERBATIM_FILES` in `scripts/test-template.sh`:

```bash
VERBATIM_FILES=(.editorconfig .vscode/extensions.json CHANGELOG.md \
  eslint.config.mjs .prettierrc.json vitest.config.ts cspell.json \
  scripts/a11y-scan.mjs playwright.config.mjs tests/vrt/vrt.spec.mjs)
```

- [ ] **Step 6: Extend the `node --check` block**

In `scripts/test-template.sh`, extend the array Task 3 added:

```bash
NODE_CHECK_FILES=(scripts/a11y-scan.mjs playwright.config.mjs tests/vrt/vrt.spec.mjs)
```

(`vitest.config.ts` is TypeScript, not plain JS; `node --check` cannot parse
it, and `astro check`/the quality-toolchain `make check` already type-checks
it once a project exists, so it is deliberately left out of this array.)

- [ ] **Step 7: Run the suite**

```bash
./scripts/test-template.sh
```

Expected: both new files pass `node --check` and survive every combo
verbatim.

- [ ] **Step 8: Commit**

```bash
git add playwright.config.mjs tests/vrt/vrt.spec.mjs vitest.config.ts \
  eslint.config.mjs scripts/test-template.sh
git commit -m "feat: add Playwright visual regression (playwright.config.mjs, tests/vrt/vrt.spec.mjs)"
```

---

### Task 5: setup.sh installs the browser-check toolchain; keep Makefile/setup.sh format paths in step

**Files:**
- Modify: `scripts/setup.sh:321-334` (insert a `BROWSER_DEPS` block after the
  existing `QUALITY_DEPS` block, before `# --- Integrations ---` at line 335)
- Modify: `scripts/setup.sh:369` (extend the "Normalize formatting" prettier
  command)
- Modify: `Makefile:45` (extend `FMT_PATHS` to match)

**Interfaces:**
- Consumes: `dep_present()`, already defined above `TYPECHECK_DEPS` in
  `setup.sh` (unchanged).
- Produces: `@axe-core/playwright` and `@playwright/test` as devDependencies,
  and an installed Playwright Chromium browser, both present by the time
  `scripts/browser-check.sh` (Task 6) or the `browser` CI job (Task 7) first
  runs.

- [ ] **Step 1: Add the browser-check dependency install**

In `scripts/setup.sh`, insert immediately after the `QUALITY_DEPS` block ends
(after line 333, `fi`, and before line 335's `# --- Integrations ---`):

```bash

# --- Browser checks ---
# axe-core (via @axe-core/playwright) for accessibility, @playwright/test for
# both that and the visual regression spec. Contract is in CONVENTIONS.md,
# "Browser checks". Neither package needs a version pin: verified live
# against the npm registry, no peer range collides with anything else this
# template installs.
BROWSER_DEPS=("@axe-core/playwright" "@playwright/test")
missing_browser=()
for spec in "${BROWSER_DEPS[@]}"; do
  dep="${spec%@^*}"
  dep_present "$dep" || missing_browser+=("$spec")
done
if [ "${#missing_browser[@]}" -gt 0 ]; then
  info "Installing browser-check dependencies: ${missing_browser[*]}"
  pnpm add -D "${missing_browser[@]}" || warn "Could not install ${missing_browser[*]}; make a11y/vrt will not work."
else
  success "Browser-check dependencies already present."
fi

info "Installing the Playwright Chromium browser..."
pnpm exec playwright install chromium \
  || warn "Playwright browser install failed; run 'pnpm exec playwright install chromium' by hand before make a11y/make vrt."
```

- [ ] **Step 2: Extend the "Normalize formatting" pass**

In `scripts/setup.sh:369`, replace:

```bash
  pnpm exec prettier --write src astro.config.mjs eslint.config.mjs vitest.config.ts \
    || warn "Prettier formatting pass failed; run 'make format' by hand."
```

with:

```bash
  pnpm exec prettier --write src astro.config.mjs eslint.config.mjs vitest.config.ts \
    playwright.config.mjs scripts/a11y-scan.mjs tests \
    || warn "Prettier formatting pass failed; run 'make format' by hand."
```

- [ ] **Step 3: Keep Makefile's FMT_PATHS in step**

In `Makefile:45`, replace:

```makefile
FMT_PATHS = src astro.config.mjs eslint.config.mjs vitest.config.ts
```

with:

```makefile
FMT_PATHS = src astro.config.mjs eslint.config.mjs vitest.config.ts playwright.config.mjs scripts/a11y-scan.mjs tests
```

- [ ] **Step 4: Verify syntax**

```bash
bash -n scripts/setup.sh
make -n format
./scripts/test-template.sh
```

Expected: `bash -n` clean, `make -n format` parses, and the regression suite
still passes (`setup.sh`'s `ASTRO_TEMPLATE`/`ADAPTER`/`SITE_NAME`
substitution assertions are unaffected, since this task only adds lines
around them).

- [ ] **Step 5: Commit**

```bash
git add scripts/setup.sh Makefile
git commit -m "feat: setup.sh installs the browser-check toolchain and Chromium"
```

---

### Task 6: scripts/browser-check.sh, make a11y / make vrt / make vrt-update

**Files:**
- Create: `scripts/browser-check.sh`
- Modify: `Makefile:6-11` (`.PHONY`), `Makefile:83` area (new `## ==
  Browser checks ==` section after `clean`)
- Modify: `scripts/test-template.sh` (VERBATIM_FILES, `bash -n` +
  executable-bit block, `make -n` target list)

**Interfaces:**
- Consumes: `scripts/a11y-scan.mjs` (Task 3), `playwright.config.mjs` /
  `tests/vrt/vrt.spec.mjs` (Task 4).
- Produces: `./scripts/browser-check.sh <a11y|vrt> [extra playwright args]`,
  exit code mirrors the underlying check's.

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Build the production site, serve it with "astro preview", run the
# requested browser check against it, then always stop the server.
# Usage: ./scripts/browser-check.sh <a11y|vrt> [extra playwright args]
# Called by "make a11y", "make vrt" and "make vrt-update". Mirrors what the
# "browser" CI job does against the same build; CI inlines its own steps
# instead of calling this script, because it runs both checks against one
# server and needs CI-only baseline/artifact handling this script does not.
# Portable across macOS (BSD) and Linux (GNU); see CONVENTIONS.md's script
# contract.
set -euo pipefail

BOLD="\033[1m"; GREEN="\033[32m"; RED="\033[31m"; RESET="\033[0m"
info() { echo -e "${BOLD}> $*${RESET}"; }
ok()   { echo -e "${GREEN}OK $*${RESET}"; }
die()  { echo -e "${RED}xx $*${RESET}" >&2; exit 1; }

CHECK="${1:-}"
case "$CHECK" in
  a11y|vrt) ;;
  *) die "Usage: $0 <a11y|vrt> [extra playwright args]" ;;
esac
shift

BASE_URL="http://localhost:4321"
LOG_FILE="$(mktemp "${TMPDIR:-/tmp}/astro-preview-log.XXXXXX")"
SERVER_PID=""

cleanup() {
  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
  rm -f "$LOG_FILE"
}
trap cleanup EXIT

info "Building the production site (astro build)..."
pnpm astro build

info "Starting the preview server ($BASE_URL)..."
pnpm astro preview --port 4321 >"$LOG_FILE" 2>&1 &
SERVER_PID=$!

ready=false
i=1
while [ "$i" -le 30 ]; do
  if curl -sSf "$BASE_URL/" >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 2
  i=$((i + 1))
done

if [ "$ready" != "true" ]; then
  echo "astro preview did not respond on $BASE_URL." >&2
  cat "$LOG_FILE" >&2
  exit 1
fi
ok "Preview server ready."

case "$CHECK" in
  a11y)
    info "Running the accessibility scan (axe-core)..."
    node scripts/a11y-scan.mjs --base-url="$BASE_URL"
    ;;
  vrt)
    info "Running the visual regression test..."
    VRT_BASE_URL="$BASE_URL" pnpm exec playwright test tests/vrt "$@"
    ;;
esac
```

- [ ] **Step 2: Make it executable**

```bash
chmod 755 scripts/browser-check.sh
```

- [ ] **Step 3: Add the Makefile targets**

In `Makefile:6-11`, add `a11y vrt vrt-update` to `.PHONY`:

```makefile
.PHONY: help dev build preview check lint lint-fix format format-check \
        test spell add clean guard-integration a11y vrt vrt-update
```

After the `clean` target (`Makefile:83-85`), add a new section:

```makefile

## == Browser checks ===========================================================

a11y: ## Accessibility scan (axe-core via Playwright); builds and serves the production build first
	@$(GUARD_SRC) && ./scripts/browser-check.sh a11y

vrt: ## Visual regression test (Playwright); Linux baselines are authoritative, macOS runs are advisory
	@$(GUARD_SRC) && ./scripts/browser-check.sh vrt

vrt-update: ## Regenerate VRT baselines; only commit baselines generated on Linux/CI
	@$(GUARD_SRC) && ./scripts/browser-check.sh vrt --update-snapshots
```

- [ ] **Step 4: Add to VERBATIM_FILES, extend the syntax-check block**

In `scripts/test-template.sh`:

```bash
VERBATIM_FILES=(.editorconfig .vscode/extensions.json CHANGELOG.md \
  eslint.config.mjs .prettierrc.json vitest.config.ts cspell.json \
  scripts/a11y-scan.mjs playwright.config.mjs tests/vrt/vrt.spec.mjs \
  scripts/browser-check.sh)
```

Extend the syntax-check section Task 3 added, right after the
`NODE_CHECK_FILES` loop:

```bash
if bash -n scripts/browser-check.sh; then
  pass "bash -n scripts/browser-check.sh"
else
  fail "bash -n scripts/browser-check.sh"
fi
if [ -x scripts/browser-check.sh ]; then
  pass "scripts/browser-check.sh is executable"
else
  fail "scripts/browser-check.sh is not executable"
fi
```

- [ ] **Step 5: Add the new targets to the per-combo `make -n` loop**

In `assert_common`, extend the target list:

```bash
  for target in help dev build preview check lint lint-fix format format-check test spell clean a11y vrt vrt-update; do
```

- [ ] **Step 6: Run the suite**

```bash
./scripts/test-template.sh
```

Expected: `bash -n scripts/browser-check.sh` and the executable-bit check
pass; `make -n a11y`, `make -n vrt` and `make -n vrt-update` parse for every
combo; `scripts/browser-check.sh survives init.sh verbatim` passes.

- [ ] **Step 7: Commit**

```bash
git add scripts/browser-check.sh Makefile scripts/test-template.sh
git commit -m "feat: add scripts/browser-check.sh, make a11y / make vrt / make vrt-update"
```

---

### Task 7: The browser CI job

**Files:**
- Modify: `.github/workflows/ci.yml` (replace the trailing "Browser checks
  ... land in Stage 3" comment at the end of the file with a real `browser`
  job)

**Interfaces:**
- Consumes: `scripts/a11y-scan.mjs` (Task 3), `tests/vrt` (Task 4). Does not
  call `scripts/browser-check.sh` (Task 6); see the Architecture note above
  for why.

- [ ] **Step 1: Replace the trailing comment with the job**

The current end of `.github/workflows/ci.yml` reads:

```yaml
  # Browser checks (axe-core accessibility scan plus Playwright visual
  # regression, sharing one scan-urls.json) land in Stage 3. See CONVENTIONS.md
  # for the contract they will implement.
```

Replace it with:

```yaml
  # Accessibility (axe-core) and visual regression (Playwright) checks,
  # sharing scan-urls.json. Guarded the same as quality: runs only once a
  # project has been scaffolded (package.json present). Inlines its own
  # build-serve sequence rather than calling scripts/browser-check.sh, so
  # both checks below run against one server instead of building and
  # serving twice; see CONVENTIONS.md, "Browser checks".
  #
  # Needs live verification: this job has never actually run in GitHub
  # Actions. It cannot run on the bare template (guarded out below) and no
  # project created from this template has pushed yet to exercise it for
  # real. The build-serve-scan sequence and the "generate baseline, do not
  # fail" first-run path were verified locally against a throwaway scaffold
  # instead; see template-docs/memory.md, "Browser checks verification".
  browser:
    name: Browser checks (accessibility + visual regression)
    needs: guard
    if: needs.guard.outputs.run == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      - uses: actions/setup-node@v7
        with:
          node-version: ${{ env.NODE_VERSION }}

      - run: corepack enable pnpm
      - run: pnpm install --frozen-lockfile

      - name: Install Playwright browsers
        run: pnpm exec playwright install --with-deps chromium

      - name: Production build
        run: pnpm astro build

      - name: Serve the production build
        run: |
          pnpm astro preview --port 4321 >/tmp/astro-preview.log 2>&1 &
          echo $! > /tmp/astro-preview.pid

          ready=false
          for i in $(seq 1 30); do
            if curl -sSf http://localhost:4321/ >/dev/null 2>&1; then
              ready=true
              break
            fi
            sleep 2
          done

          if [ "$ready" = false ]; then
            echo "astro preview did not respond on http://localhost:4321." >&2
            cat /tmp/astro-preview.log
            exit 1
          fi

      - name: Accessibility scan (axe-core via Playwright)
        run: node scripts/a11y-scan.mjs --base-url=http://localhost:4321

      - name: Visual regression test (Playwright)
        id: vrt
        env:
          VRT_BASE_URL: http://localhost:4321
        run: |
          if [ -d tests/vrt/__screenshots__/linux ] && find tests/vrt/__screenshots__/linux -name '*.png' -print -quit | grep -q .; then
            echo "Committed Linux baselines found; comparing against them."
            pnpm exec playwright test tests/vrt
          else
            echo "No committed Linux baselines yet; generating them instead of failing this run."
            pnpm exec playwright test tests/vrt --update-snapshots
            echo "baselines_generated=true" >> "$GITHUB_OUTPUT"
          fi

      - name: Upload generated VRT baselines
        if: steps.vrt.outputs.baselines_generated == 'true'
        uses: actions/upload-artifact@v7
        with:
          name: vrt-baselines-linux
          path: tests/vrt/__screenshots__/linux/
          if-no-files-found: error

      - name: Upload Playwright report
        if: failure()
        uses: actions/upload-artifact@v7
        with:
          name: playwright-report
          path: playwright-report/
          if-no-files-found: ignore

      - name: Show preview server log
        if: failure()
        run: cat /tmp/astro-preview.log 2>/dev/null || true

      - name: Stop the preview server
        if: always()
        run: kill "$(cat /tmp/astro-preview.pid)" 2>/dev/null || true
```

- [ ] **Step 2: Validate YAML and the ${{ }} invariant**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo OK
./scripts/test-template.sh
```

Expected: YAML parses, and the `${{ }} expressions unchanged across init.sh`
assertion still passes for every combo (this task adds new `${{ }}`
expressions to `ci.yml`, but `assert_no_leftover_tokens` and the GA-expression
diff both compare the file's own before/after state per combo, not a fixed
count, so new expressions do not break the suite as long as `init.sh` leaves
them untouched, which it does: `ci.yml` holds no `{{UPPER_SNAKE}}` tokens).

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "feat: add the browser CI job (accessibility + visual regression)"
```

---

### Task 8: Port .claude/commands/a11y-check.md to Astro wording

**Files:**
- Create: `.claude/commands/a11y-check.md`

**Interfaces:**
- None; this is a Claude Code command file, not invoked by any script in
  this plan.

- [ ] **Step 1: Write the ported command file**

Source: `.claude/commands/a11y-check.md` in the
`localgov-drupal-dev-template` checkout used for Task 3 (read directly, not
reimplemented from memory). Drupal/DDEV-specific wording (`{{DDEV_URL}}`,
`{{MODULE_AFFECTS}}`, `{{THEME_LAYER}}` tokens; Twig; the drupal-expert /
drupal-localgov skills and drupal-reviewer agent, none of which exist in this
project) is replaced with this project's own equivalents: `make a11y` /
`make dev` instead of a DDEV URL token, component markup instead of Twig, and
direct references to `AGENTS.md`'s own sections instead of skills or agents
that do not exist here (`astro-expert` is Stage 5 and not built yet, per
`AGENTS.md`'s "Agent Resources" section; do not reference it). No new
`{{TOKEN}}` is introduced: nothing in this file needs a per-project value.

```markdown
---
name: a11y-check
description: Accessibility audit of site pages against WCAG 2.2 AA
arguments: "[url-or-path ...]"
---

# Accessibility Check

Audit one or more pages of this project for accessibility. If paths are given
as arguments, test those. Otherwise test a representative set of page types
(at minimum: the front page, one listing or index page if the flavour has
one, one content/detail page, and one page with a form if any exist).

WCAG target: 2.2 AA (see `AGENTS.md`, "Accessibility"). Before fixing anything
found here, read the relevant sections of `AGENTS.md` (Components, Zero
JavaScript by Default, Accessibility, Front-end Standards) so fixes follow
this project's conventions rather than working around them.

## Step 1: Automated scan (axe-core)

Run `make a11y`: it builds the production site, serves it with
`astro preview`, and runs `scripts/a11y-scan.mjs` (axe-core via Playwright)
against every path in `scan-urls.json`, reporting each violation's rule id,
impact, WCAG tags and a sample selector.

For a page not yet in `scan-urls.json`, or to iterate faster than a full
build: if browser tools (Claude in Chrome) are available, navigate to the
page (`make dev` first) and inject axe from the CDN:

```js
const s = document.createElement('script');
s.src = 'https://cdnjs.cloudflare.com/ajax/libs/axe-core/4.10.2/axe.min.js';
document.head.appendChild(s);
// wait for load, then:
const results = await axe.run(document, { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'] } });
console.log(JSON.stringify(results.violations.map(v => ({ id: v.id, impact: v.impact, wcag: v.tags, count: v.nodes.length, sample: v.nodes[0]?.target }))));
```

## Step 2: Keyboard pass

For each page, verify by driving the browser or by inspecting the relevant
component markup and CSS:

1. Skip link present and functional.
2. Tab reaches every interactive element in a logical order; no positive
   `tabindex`.
3. Focus always visible; `:focus-visible` styles exist; no `outline: none`
   without a replacement.
4. Menus, accordions, modals: Escape closes, no focus trap, focus returns to
   the trigger.

## Step 3: Zoom, reflow, and motion

1. Content reflows at 320 px viewport width with no horizontal scroll and no
   loss of content (WCAG 1.4.10).
2. Page remains usable at 200% zoom.
3. Animations and transitions are gated behind `prefers-reduced-motion`.

## Step 4: Quick content checks

1. One `h1` per page; heading levels do not skip.
2. Images have appropriate `alt` (empty for decorative), and use `<Image />`
   from `astro:assets` where the source is local.
3. Form fields have programmatically associated labels; errors are announced.
4. Touch targets at least 24x24 CSS px (WCAG 2.2, 2.5.8).
5. Text contrast at least 4.5:1 (3:1 for large text and UI components);
   nothing conveyed by color alone.

## Step 5: Report

Group findings by WCAG success criterion with severity (critical / serious /
moderate / minor), the axe rule id, affected selector, and the likely source
component. Distinguish issues fixable in this project's own components from
issues in a starter-template or third-party integration that should be
reported upstream.

## Fix rules

- Fix in the correct layer: markup in the `.astro` component, styling in its
  own scoped `<style>` block, following the Front-end Standards in
  `AGENTS.md`.
- Where the affected markup lives in a single component, fix it there (its
  template, its `<style>` block), not in a global override.
- Prefer native HTML semantics over ARIA. ARIA is a last resort.
- After fixes: re-run `make a11y` (or `make dev` and spot check) on the
  affected pages.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/a11y-check.md
git commit -m "docs: port the a11y-check command file to Astro wording"
```

---

### Task 9: cspell, README, and the maintainer status docs

**Files:**
- Modify: `cspell.json`
- Modify: `README.md:54-71` (Tasks list), add a new `## Browser checks`
  section after `## Tasks` and before `## Changing the deploy target`
  (`README.md:72`)
- Modify: `template-docs/PROMPTS.md` (Stage 3 status)
- Modify: `template-docs/memory.md` (nothing yet to record live; Task 10
  fills this in)

**Interfaces:** None; docs only.

- [ ] **Step 1: Update cspell.json**

Replace `cspell.json` in full:

```json
{
  "version": "0.2",
  "language": "en-GB",
  "words": [
    "astro",
    "starlight",
    "pnpm",
    "corepack",
    "frontmatter",
    "worktrees",
    "destructures",
    "WCAG",
    "reflow",
    "flexbox",
    "localgov",
    "vitest",
    "vercel",
    "astrojs",
    "esbuild",
    "color",
    "jamesfmcgrath",
    "mktemp",
    "playwright",
    "chromium"
  ],
  "ignorePaths": [
    "pnpm-lock.yaml",
    "template.answers",
    "dist/**",
    ".astro/**",
    "node_modules/**",
    "playwright-report/**",
    "test-results/**",
    "blob-report/**"
  ]
}
```

- [ ] **Step 2: Update the README Tasks list**

In `README.md`, in the fenced block under `## Tasks` (`README.md:54-71`),
after `make clean       Remove dist/ and .astro/`, add:

```
make a11y          Accessibility scan (axe-core via Playwright)
make vrt           Visual regression test (Playwright)
make vrt-update    Regenerate VRT baselines (Linux/CI only; see below)
```

- [ ] **Step 3: Add a "Browser checks" README section**

Insert a new section after `## Tasks` (`README.md:71`, the closing of the
fenced block) and before `## Changing the deploy target` (`README.md:72`):

```markdown
## Browser checks

`make a11y` and `make vrt` each build the production site, serve it with
`astro preview`, and run one check against it through
`scripts/browser-check.sh`: `scripts/a11y-scan.mjs` (axe-core via Playwright,
WCAG 2.2 AA) for `make a11y`, `tests/vrt/vrt.spec.mjs`
(`@playwright/test`'s `toHaveScreenshot`) for `make vrt`. Both read the same
`scan-urls.json` at the repo root, set by `init.sh` to match the flavour: the
front page always, plus one real content page for `blog` and `starlight`.
Edit the list as real content replaces the example pages.

Visual regression baselines are generated and compared on **Linux only**:
font rendering differs enough between macOS and Linux to make cross-OS
baselines flaky. Playwright suffixes each baseline with the OS it was
generated on (`tests/vrt/__screenshots__/linux/…`,
`tests/vrt/__screenshots__/darwin/…`); only `linux/` is committed. On a Mac:

- `make vrt` / `make vrt-update` are **advisory only**: useful to confirm the
  plumbing works, not to generate baselines to commit.
- Generate and refresh real baselines in CI (the `browser` GitHub Actions
  job) or a Linux container/VM, then commit the resulting
  `tests/vrt/__screenshots__/linux/` directory.
- In CI, a missing `linux/` baseline is not a failure: the job generates it
  and uploads it as a build artifact for review and commit. Once baselines
  exist, a genuine diff fails the job and the Playwright HTML report uploads
  as an artifact.

See `CONVENTIONS.md`, "Browser checks", for the full contract.
```

- [ ] **Step 4: Update PROMPTS.md's Stage 3 status**

In `template-docs/PROMPTS.md`, in the `## Status (2026-09-10)` list, replace:

```markdown
- **Stage 3, browser checks: PENDING.**
```

with:

```markdown
- **Stage 3, browser checks: DONE, needs live CI verification.**
  `scan-urls.json` set per flavour by `init.sh`; `scripts/a11y-scan.mjs`
  adapted from `localgov-drupal-dev-template` (read from a checkout);
  `playwright.config.mjs` / `tests/vrt/vrt.spec.mjs` net new; a fourth
  script, `scripts/browser-check.sh`, backs `make a11y` / `make vrt` /
  `make vrt-update`; a `browser` CI job inlines its own build-serve sequence.
  Full rationale in `CONVENTIONS.md`, "Browser checks". Verified live
  against a scaffolded project on 2026-09-10; see `memory.md`, "Browser
  checks verification", for exactly what ran. The `browser` GitHub Actions
  job itself has never run for real: that needs a push from a created
  project, same caveat Stage 2's `quality` job still carries.
```

(Task 10 fills in the exact date/details this references; if Task 10's live
run finds something that changes this summary, come back and correct it
rather than leaving it inconsistent with `memory.md`.)

- [ ] **Step 5: Commit**

```bash
git add cspell.json README.md template-docs/PROMPTS.md
git commit -m "docs: document the browser-checks layer in README and cspell.json"
```

---

### Task 10: Live verification against a scaffolded project

**Files:**
- Modify: `template-docs/memory.md` (new "Browser checks verification"
  section)
- Possibly modify: any file above, if this run finds a real bug (follow the
  precedent in `memory.md`'s existing "Bugs found by the live runs" section:
  fix it, comment the fix site, record it here rather than leaving it silent)

**Interfaces:** None; this is verification, not new surface area.

- [ ] **Step 1: Scaffold a throwaway minimal/static project**

```bash
TMP="$(mktemp -d "${TMPDIR:-/tmp}/browser-check-verify.XXXXXX")"
rsync -a --exclude='.git' --exclude='node_modules' --exclude='dist' \
  --exclude='.astro' --exclude='.claude/settings.local.json' \
  --exclude='.superpowers' \
  ./ "$TMP"/
cd "$TMP"
./scripts/init.sh --site verify-site --site-label "Verify Site" \
  --client "Verification" --skill-fork jamesfmcgrath \
  --flavour minimal --deploy-target static
cat scan-urls.json   # expect exactly ["/"]
./scripts/setup.sh
```

Report exactly what `setup.sh` printed, in particular whether the browser-check
dependency install and `pnpm exec playwright install chromium` steps
succeeded, not an inferred "should have worked."

- [ ] **Step 2: Run the full quality + browser check pipeline**

```bash
make check
make lint
make format-check
make spell
make test
make build
make a11y
make vrt
```

Report the actual exit code and a summary of the actual output for each,
especially `make a11y` (violation count, load failures, if any) and `make
vrt` (baselines generated on first run, since this is macOS and therefore
advisory only per the "Browser checks" contract). If any command fails,
diagnose and fix the real cause (in the template, not just in this throwaway
copy) before re-running from Step 1 with a fresh temp directory.

- [ ] **Step 3: Spot-check blog and starlight's scan-urls.json against a real build**

```bash
cd -
TMP2="$(mktemp -d "${TMPDIR:-/tmp}/browser-check-verify-blog.XXXXXX")"
rsync -a --exclude='.git' --exclude='node_modules' --exclude='dist' \
  --exclude='.astro' --exclude='.claude/settings.local.json' \
  --exclude='.superpowers' \
  ./ "$TMP2"/
cd "$TMP2"
./scripts/init.sh --site verify-blog --site-label "Verify Blog" \
  --client "Verification" --skill-fork jamesfmcgrath \
  --flavour blog --deploy-target static
cat scan-urls.json   # expect exactly ["/", "/blog/first-post/"]
./scripts/setup.sh
make build
ls dist/blog/first-post/   # expect index.html: proves the scan-urls.json path is real
```

Repeat the same for `--flavour starlight`, expecting
`["/", "/guides/example/"]` and `dist/guides/example/index.html`. Running
`make a11y` / `make vrt` against both too is worthwhile if time allows,
since it is stronger evidence than a directory listing, but the `ls` check
above is the minimum bar: it proves the path is not a 404 before the scan
even runs.

- [ ] **Step 4: Clean up**

```bash
cd -
rm -rf "$TMP" "$TMP2"
```

State the blast radius before running this: it only deletes the `mktemp -d`
throwaway directories staged in Steps 1 and 3, nothing under the repo
working directory.

- [ ] **Step 5: Record the result in template-docs/memory.md**

Add a new section after "## Quality toolchain verification" and before "##
Bugs found by the live runs":

```markdown
## Browser checks verification

Live on <actual date>, minimal/static, blog/static and starlight/static,
Node <actual>, pnpm <actual>: `setup.sh` installed the browser-check
devDependencies and the Playwright Chromium browser. `scan-urls.json` matched
the documented default for every flavour (`["/"]`,
`["/", "/blog/first-post/"]`, `["/", "/guides/example/"]`), and `make build`
produced a real `index.html` at each non-front-page path. `make check`,
`make lint`, `make format-check`, `make spell`, `make test`, `make build`,
`make a11y` and `make vrt` all <ran/passed, state actual outcome> on
minimal/static. `make vrt` on this macOS machine <generated advisory
baselines under tests/vrt/__screenshots__/darwin/, gitignored, not
committed>. The `browser` GitHub Actions job itself has not run yet: that
needs a push from a project created from this template, same as the
`quality` job's still-open verification gap.
```

Fill in the actual date, Node/pnpm versions, and actual outcomes observed in
Steps 1-3, not placeholders. If Step 2 found and fixed a real bug, add it to
"## Bugs found by the live runs" in the same style as the four entries
already there, including which file the fix lives in.

- [ ] **Step 6: Commit**

```bash
git add template-docs/memory.md
git commit -m "docs: record the local browser-checks live verification"
```

(If Step 2 fixed a real bug in a tracked file, that fix is its own commit
before this one, following the same "fix, then document" order the existing
`memory.md` bugs section describes.)

---

## Self-review notes

- **Spec coverage:** item 1 (`scan-urls.json` at the root, defaults per
  flavour set by `init.sh`) is Task 2; item 2 (serve step: build for
  static/ssr, `astro preview`, axe scan and VRT spec against it; local `make
  a11y` / `make vrt`) is Tasks 3, 4, 6; item 3 (CI `browser-checks` job:
  build, serve, wait, scan, VRT, upload report artifact on failure, missing
  baselines generate-and-upload) is Task 7; item 4 (WCAG 2.2 AA, port
  `.claude/commands/a11y-check.md` with Astro wording) is Task 8, cross-
  referenced from Task 1's `CONVENTIONS.md` rewrite; item 5 (bash 3.2 / BSD
  floor, verified on both platforms) is `scripts/browser-check.sh` (Task 6)
  plus the Global Constraints note on what does and does not need that
  floor; item 6 (`node --check`, `test-template.sh` extended, honest "needs
  live verification" marker for the CI job) is Tasks 3/4/6's syntax-check
  additions plus Task 7's CI comment and Task 10's live local run. No spec
  line was left without a task.
- **Placeholder scan:** no TBD/TODO, no "add appropriate handling". Task 10's
  `<actual date>` / `<ran/passed, state actual outcome>` placeholders are
  explicitly flagged as things the executor must replace with real observed
  values before committing, consistent with this project's own "needs live
  verification" house rule (`memory.md`'s Quality toolchain section does the
  same: "Fill in the actual date... not placeholders"), not a stand-in for
  content this plan should have written itself.
- **Type/name consistency:** `BASE_URL`/`http://localhost:4321` is the same
  literal in `scripts/a11y-scan.mjs` (Task 3), `tests/vrt/vrt.spec.mjs`
  (Task 4), `scripts/browser-check.sh` (Task 6) and the CI job (Task 7);
  `scan-urls.json`'s path is read the same way (`path.join(__dirname, '..',
  'scan-urls.json')` from `scripts/`, `path.join(__dirname, '..', '..',
  'scan-urls.json')` from `tests/vrt/`) in both `.mjs` files; `BROWSER_DEPS`
  in `setup.sh` (Task 5) follows the exact `QUALITY_DEPS`/`dep_present()`
  pattern it sits next to; the `a11y`/`vrt`/`vrt-update` Makefile targets
  (Task 6) match the `CHECK` values `scripts/browser-check.sh` switches on.
