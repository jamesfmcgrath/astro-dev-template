# Conventions

Rules for this repo: the astro-dev-template GitHub template and every project
created from it. Lineage notes mark rules carried over from
localgov-drupal-dev-template, which is a reference for this repo and nothing
more.

**Created projects keep this file.** It documents the scripts and contracts a
project still holds after `init.sh` runs (setup.sh, the Makefile, the agent
resources contract, the browser checks). Removing it would strand those.

## Token grammar

- Only `{{UPPER_SNAKE}}` is a token: two braces, uppercase ASCII letters and
  underscores, no spaces. Nothing else is substituted.
- GitHub Actions `${{ }}` expressions are never tokens and must survive
  `init.sh` byte for byte. The regression suite counts them before and after.
- Prompted tokens come from a flag or a prompt. Derived tokens are computed by
  `init.sh` from prompted answers and are never asked for.
- Every token, prompted or derived, is registered in `TEMPLATE.md`. A token
  that is not in that table is a bug.
- `init.sh` discovers the files to substitute by grepping for the token
  pattern. It does not carry a hardcoded file list, so a file added after the
  template was written is still substituted. Exclusions are explicit
  (`SKIP_PATHS` and the excluded directories in `discover_token_files`).
- This file contains the literal string above as documentation, so it is the
  one exception to the "no leftover tokens" assertion. The suite lists it by
  name.

Lineage: token grammar, dynamic discovery and the `${{ }}` rule come from
localgov-drupal-dev-template.

## Script contract

All three scripts live in `scripts/`, are committed `100755`, are
`#!/usr/bin/env bash`, and are portable across macOS (BSD) and Linux (GNU). A
fourth script, `scripts/browser-check.sh`, lives here too and is held to the
same portability floor, but it is an ordinary dev-task helper, not part of the
init/setup/test-template tokeniser lifecycle this section describes; see
"Browser checks" below.

**Portability floor: macOS bash 3.2 with BSD userland.** No GNU-only flag or
behaviour is assumed. `cp -n`'s differing exit code across BSD and GNU (fixed
in `setup.sh`) and BSD `tr` rejecting a multi-char set such as `tr '-_' '  '`
as an illegal option (fixed in `init.sh`'s `titlecase()`) are the two bugs
this rule exists to stop repeating. In particular: no `sed -i` without an
explicit (possibly empty) backup suffix, no `tr` with ranges or multi-char
sets, no `readlink -f`, `date -d`, `grep -P`, `sort -V`, `find -printf` or
`xargs -r`, no GNU-only `stat`/`head -c`/`mktemp` flags, and no bash 4+ syntax
(`${x^}`, `${x,,}`, `mapfile`, `readarray`, associative arrays, `globstar`).
The floor is bash 3.2, not whatever ships on the developer's machine.

- `init.sh` is the **one-time tokeniser**. It takes every answer from a flag,
  a prompt, or both; records the resolved answers in `template.answers`;
  substitutes tokens across every discovered file; removes `TEMPLATE.md`,
  `scripts/test-template.sh` and `template-docs/`; then removes itself. It
  refuses to run twice. It touches no network.
- `setup.sh` is the **idempotent spin-up**. Re-running it must be safe. It
  never clobbers a template file: the Astro scaffold is generated into a temp
  directory and copied across with `cp -n`. It starts no server; `make dev`
  does that.
- `test-template.sh` is the **no-network regression suite**. It copies the repo
  to a temp directory, drives `init.sh` through every supported combination,
  and asserts the tokeniser and file invariants. It runs no package manager, no
  network call, and no scaffold.

Lineage: the three-script split, `template.answers`, and the self-removing
initialiser come from localgov-drupal-dev-template. The flag grammar
(`--flag VALUE` and `--flag=VALUE`, where `--flag=` supplies an explicit empty
value) is inherited too.

## CI guard-job inversion

`.github/workflows/ci.yml` opens with a `guard` job that reports whether a
project has been scaffolded, keyed on the presence of `package.json`. The bare
template has none.

- `run == false` (bare template): the **template** job runs
  `scripts/test-template.sh`. Nothing else runs.
- `run == true` (created project): the **project** job runs `make check`,
  `make lint`, `make format-check`, `make spell`, `make test` and
  `make build`, in that order.

The point of the inversion is that the template repo gets a green, meaningful
CI run of its own instead of a run that skips everything.

Lineage: inherited from localgov-drupal-dev-template, with `composer.json`
swapped for `package.json`.

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

`typescript-eslint` is pinned to `^8` in `scripts/setup.sh` for the same
reason: its flat-config ordering behaviour and its `typescript` peer range are
both verified against 8.70.0 specifically. **Reopen** when deliberately
testing a `typescript-eslint` major bump, re-verifying the ordering and
peer-range facts above against the new version before lifting the pin.

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

## Agent resources

- `AGENTS.md` is canonical and is the only file to edit. Cursor reads it
  natively.
- `CLAUDE.md` is a stub containing `@AGENTS.md` and nothing else of substance.
- `agr.toml` is the tracked source of truth for skills. A created project also
  commits the `agr.lock` that `setup.sh` generates; the bare template does not,
  because `agr.toml` still holds the `{{SKILL_FORK}}` token and cannot resolve.
- Installed skills (`.claude/skills/`, `.cursor/skills/`) are gitignored. Never
  vendor a copy.
- An `agr` failure warns and continues. Skills are a convenience, not a
  prerequisite for a working project.

Lineage: inherited wholesale from localgov-drupal-dev-template.

## Docs

- `README.md` is for the person using the template and the project made from
  it. It stays.
- `CONVENTIONS.md` stays (see the top of this file).
- `TEMPLATE.md` is the token registry and template-only instructions.
  `init.sh` removes it.
- `template-docs/` is maintainer-only (`PROMPTS.md`, `memory.md`, dated
  implementation plans under `plans/`). `init.sh` removes it.
- `CHANGELOG.md` is the update path. A project created from the template pulls
  template improvements by reading the changelog and applying the entries it
  wants, not by merging the template's history.

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

Astro 7's `astro preview` detaches as a background daemon: the command prints
the address it bound to and returns immediately, so a shell `&` and its `$!`
PID buy nothing, and a later step still finds the server running with no
process this session owns. `scripts/browser-check.sh` and the `browser` CI
job's serve step both start it explicitly with `--background`, then read the
address back from the server's own log output and assert it matches
`http://localhost:4321`, because `astro preview` falls back silently to the
next free port instead of failing when 4321 is already taken; a plain
readiness probe on 4321 would not catch that fallback.
`scripts/browser-check.sh` also refuses to start at all if something already
answers on port 4321 before the build even begins, a pre-flight check that
catches the same silent-fallback failure mode one step earlier, before a
build is wasted on it; the `browser` CI job skips this, relying on the
post-start assertion alone, since a hosted runner starts clean each run.
Teardown is
`astro preview stop`, not a process signal: the shell never owns a PID for a
detached daemon, so killing the `pnpm` wrapper leaves the real server running
and holding the port.

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

## House rules

- **No em dashes** anywhere: prose, comments, commit messages, script output.
  Use commas, colons, or restructure.
- **Staged PROMPTS.md workflow.** Work lands in numbered stages recorded in
  `template-docs/PROMPTS.md`, each with a status. A stage is not DONE until its
  verification has run.
- **The "needs live verification" honesty rule.** Anything not actually
  executed is labelled "needs live verification" and says what was and was not
  observed. Inference is never reported as a passing result.
  `template-docs/memory.md` carries the verification status table, one row per
  supported combination, and a row gains a date only when a live run proves it.
- Accessibility is not optional. Target WCAG 2.2 AA in user-facing work.

Lineage: house rules inherited from localgov-drupal-dev-template.
