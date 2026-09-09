# Changelog

Changes to the astro-dev-template itself. This is the update path for projects
already created from it: read the entries added since your project was created
and apply the ones you want by hand. Do not merge the template's git history
into a project.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Initial standalone Astro project template.
- `CONVENTIONS.md`: token grammar, script contract, CI guard-job inversion,
  agent-resources contract, docs contract, browser-checks contract, house
  rules. Created projects keep this file.
- `scripts/init.sh`: flag-driven one-time tokeniser with interactive fallback.
  Prompted tokens `SITE_NAME`, `SITE_LABEL`, `CLIENT`, `SKILL_FORK`, `FLAVOUR`,
  `DEPLOY_TARGET`; derived tokens `ASTRO_TEMPLATE`, `ADAPTER`. Discovers the
  files to substitute rather than carrying a hardcoded list. Writes
  `template.answers`, then removes itself, `TEMPLATE.md`,
  `scripts/test-template.sh` and `template-docs/`.
- `scripts/setup.sh`: idempotent spin-up. Checks Node against Astro's 22.12.0
  minimum, enables pnpm through corepack, installs agent resources through
  `agr`, scaffolds with `create-astro` into a temp directory and copies across
  with `cp -n`, runs `pnpm install`, then `pnpm astro add` for the default
  integrations and the adapter. `--skip-install` stops before the installs.
  Starts no server.
- `scripts/test-template.sh`: no-network regression suite over the combinations
  minimal/static, blog/static, starlight/static and minimal/ssr.
- `Makefile`: dev, build, preview, check, lint, lint-fix, format, format-check,
  test, spell, add, clean, help.
- `AGENTS.md` written for Astro: typed `Props` interfaces, zero JavaScript by
  default and the narrowest `client:*` directive, typed content collections,
  dev toolbar audits treated as lint, WCAG 2.2 AA. `CLAUDE.md` is the
  `@AGENTS.md` import stub.
- `.github/workflows/ci.yml` with the guard-job inversion: the template job
  runs the regression suite while `package.json` is absent, the project jobs
  run `make check`, `make lint`, `make test` and `make build` once it exists.
- `template-docs/PROMPTS.md` and `template-docs/memory.md` (maintainer only,
  removed by `init.sh`).

### Verified

- Astro 7.3.2 is current; Node minimum 22.12.0 confirmed from the `astro`
  package's `engines` field.
- `create-astro` 5.2.4 template names `minimal`, `blog` and `starlight`
  confirmed by reading the package, along with the flags `--template`,
  `--yes`, `--no-install`, `--no-git`, `--no-ai` and `--skip-houston`, and
  `astro add <name> --yes`.
- `eslint-plugin-astro` 3.1.0 plus `prettier-plugin-astro` 1.0.0 remain the
  mature choice over Biome 2.5.12, which still lists Astro parsing, formatting
  and linting as experimental and supports no plugins for it.

### Verified live (2026-09-09)

Run end to end on macOS 15, Node 26.8.1, pnpm 12.3.4, Astro 7.3.2: minimal on
static (including `make dev` serving HTTP 200), minimal on ssr, blog on static,
starlight on static. Each completed `setup.sh` with exit 0, then `make check`
with 0 errors and `make build`. Per-combination detail is in
`template-docs/memory.md`. Four bugs were found by those runs and fixed:

- `setup.sh` no longer treats `cp -Rn`'s exit status as success or failure. BSD
  `cp` exits 1 when `-n` skips an existing file while GNU `cp` exits 0, which
  aborted every macOS run. Replaced with an explicit per-entry copy.
- `setup.sh` writes `pnpm-workspace.yaml` allowing the `esbuild` and `sharp`
  build scripts, because pnpm 12 makes an unapproved dependency build a hard
  `pnpm install` failure. Uses `allowBuilds` on pnpm 11 and later,
  `onlyBuiltDependencies` on pnpm 10.
- `setup.sh` installs `@astrojs/check` and `typescript@^6` so `make check` does
  not stop on an interactive prompt. The pin matters: TypeScript 7's native
  compiler does not expose the API the checker uses.
- `setup.sh` strips the `@astrojs/` scope before calling `astro add` for the
  adapter. Given the scoped name, `astro add` installs the package and
  configures nothing, silently leaving a static build.

### Needs live verification

- blog on ssr and starlight on ssr.
- The `quality` and `build` CI jobs, which cannot run until a project exists.
- `make lint`, `make format`, `make test` and `make spell`, which have no
  configuration behind them until Stage 2.
