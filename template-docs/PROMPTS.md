# Maintenance prompts and status

Staged Claude Code prompts for improving this template, with current status.
Run open stages from the repo root unless noted. Companion to `memory.md`,
which holds the verification status table.

Shared conventions (repeated so they survive pasting into a fresh session): no
em dashes anywhere; scripts stay executable (100755); run
`scripts/test-template.sh` before calling a script change done; keep every
flavour and deploy target working; only `{{UPPER_SNAKE}}` names are template
tokens and GitHub Actions `${{ }}` expressions must never be touched; anything
not actually executed is labelled "needs live verification" and says what was
and was not observed.

## Status (2026-09-10)

- **Stage 1, foundation: DONE.** `CONVENTIONS.md`, `scripts/init.sh`,
  `scripts/setup.sh`, `scripts/test-template.sh`, `Makefile`, `AGENTS.md`,
  `CLAUDE.md`, `agr.toml`, CI with the guard-job inversion, `README.md`,
  `TEMPLATE.md`, `CHANGELOG.md`, and these maintainer docs. Regression suite
  passes 257/257. Four of the six flavour/deploy-target combinations verified
  live on 2026-09-09, which found and fixed four real bugs in `setup.sh`; see
  `memory.md`. blog/ssr and starlight/ssr still need a live run.
- **Stage 2, quality toolchain: DONE, merged into `main` 2026-09-10 (PR #1).**
  ESLint (`eslint-plugin-astro` plus `typescript-eslint`) plus Prettier
  (`prettier-plugin-astro`), decided 2026-09-09 over Biome (still
  experimental for Astro), plus Vitest and CSpell. `typescript-eslint`'s
  config must load before `eslint-plugin-astro`'s in `eslint.config.mjs`, or
  Astro frontmatter parsing breaks. Full rationale and reopen triggers in
  `CONVENTIONS.md`. Verified live against a scaffolded minimal/static
  project (regression suite 287/287); GitHub Actions on `main` post-merge
  ran the `guard` and `Template regression suite` jobs green, but the
  restructured `quality` job itself reported `skipped` (`main` has no
  `package.json`) and still has never run for real; see `memory.md`,
  "Quality toolchain verification". Two items found live and deliberately
  left unfixed as out of this stage's scope: `scripts/init.sh`'s
  `titlecase()` breaks on BSD `tr` (macOS), leaving `SITE_LABEL` empty on a
  real run that does not pass `--site-label`; and `blog`/`starlight`/`ssr`
  have not been exercised against this toolchain, which is Stage 4's job.
- **Stage 3, browser checks: DONE, needs live CI verification.**
  `scan-urls.json` set per flavour by `init.sh`; `scripts/a11y-scan.mjs`
  adapted from `localgov-drupal-dev-template` (read from a checkout);
  `playwright.config.mjs` / `tests/vrt/vrt.spec.mjs` net new; a fourth
  script, `scripts/browser-check.sh`, backs `make a11y` / `make vrt` /
  `make vrt-update`; a `browser` CI job inlines its own build-serve sequence.
  Full rationale in `CONVENTIONS.md`, "Browser checks". Verified live
  against scaffolded minimal, blog and starlight projects on 2026-09-10, four
  real fixes needed first; see `memory.md`, "Browser checks verification", for
  exactly what ran and what was left for Stage 4. The `browser` GitHub Actions
  job itself has never run for real: that needs a push from a created
  project, same caveat Stage 2's `quality` job still carries.
- **Stage 4, flavour and deploy-target axes proven live: PENDING.**
- **Stage 5, astro-expert skill: PENDING.**

## Stage 2, quality toolchain decision and wiring

Decide and wire the quality toolchain, then make `make lint`, `make lint-fix`,
`make format`, `make format-check`, `make test` and `make spell` actually work.
The verification done on 2026-09-09 says `eslint-plugin-astro` 3.1.0 plus
`prettier-plugin-astro` 1.0.0 is still the mature pair and Biome 2.5.12 still
treats `.astro` as experimental, so the expected answer is flat-config ESLint
with `eslint-plugin-astro`, Prettier with `prettier-plugin-astro`, Vitest
(Astro ships a `getViteConfig` helper for this), CSpell, and `@astrojs/check`
plus `typescript` for `make check`. Re-verify that before committing to it.
The open design question is where the configuration and devDependencies live:
this template ships no `package.json` (the scaffold brings one), so either
`setup.sh` installs the devDependencies after the copy, or the template ships
config files and `setup.sh` adds the dependencies. Decide, record the reasoning
in `CONVENTIONS.md`, and update the note in `README.md` and the `quality` CI
job comment that currently says those targets do not work yet.

## Stage 3, browser checks

Add the accessibility and visual regression checks the browser-checks contract
in `CONVENTIONS.md` already describes. axe-core through Playwright for
accessibility (adapted from localgov-drupal-dev-template, where it exists as
`scripts/a11y-scan.mjs`), and Playwright visual regression, which is net new
here. Both read the same `scan-urls.json`, generated at run time against the
built site rather than hardcoded, so a path a flavour does not serve is not a
false failure. Visual regression baselines are Linux-only and only
`tests/vrt/__screenshots__/linux/` is committed; the `.gitignore` entries for
this are already in place. Add a `browser` CI job behind the same guard as the
other project jobs, with the first-run "generate baselines and upload, do not
fail" path and the genuine-diff failure path both handled. Add `make a11y` and
`make vrt` targets. Scan the built output through `astro preview`, not a dev
server.

## Stage 4, flavour and deploy-target axes proven live

Run every flavour and deploy-target combination end to end and fill in the
verification status table in `memory.md`. For each: `init.sh` with flags,
`setup.sh` to completion including `create-astro`, `pnpm install` and
`astro add`, then `make build` and `make dev`. Report exactly what was observed
and fix what breaks. Four combinations were already done on 2026-09-09
(minimal/static, minimal/ssr, blog/static, starlight/static); what remains is
blog/ssr and starlight/ssr, plus `make dev` on everything but minimal/static.
Stage 3's live run already found three things waiting here: on blog, `make lint`
fails on the starter's own `HeaderLink.astro` and `make spell` reports over a
thousand hits on its Lorem ipsum prose; on starlight, `make spell` reports four
(`evenodd`, `Diátaxis`). Decide whether each is a config change or content a
real project deletes.
The scaffold merge turned out to be undramatic: the starters ship their own
`README.md`, `.gitignore` and `.vscode/extensions.json`, all three of which the
template keeps, and starlight copied 10 files without incident. Decide from the
evidence whether `starlight` on `ssr` should be offered at all, and record the
answer.

## Stage 5, astro-expert skill

Write the `astro-expert` skill and host it in the agent-resources fork, then
list it in `agr.toml`, re-run `setup.sh`, and commit the generated `agr.lock`.
It should carry the Astro-specific judgement that `AGENTS.md` states as rules:
when a `client:*` directive is genuinely warranted and which one, content
collection schema design, islands versus server islands versus static markup,
image handling through `astro:assets`, and the adapter and `output` decisions
per deploy target. Replace the "Pending Stage 5" paragraph in the Agent
Resources section of `AGENTS.md` with real usage guidance once it exists.
