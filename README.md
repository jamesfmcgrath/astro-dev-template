# {{SITE_LABEL}}

An Astro site for {{CLIENT}}.

- **Package:** `{{SITE_NAME}}`
- **Flavour:** `{{FLAVOUR}}` (the create-astro starter this project began from)
- **Deploy target:** `{{DEPLOY_TARGET}}` (adapter: `{{ADAPTER}}`, empty means a fully static build)

> Created from [astro-dev-template](https://github.com/jamesfmcgrath/astro-dev-template).
> If you are looking at the bare template and the values above still read as
> `{{`-wrapped tokens, start at **First run** below, then read `TEMPLATE.md`.

## Requirements

- **Node 22.12.0 or higher.** Astro 7 will not run on anything older. Prefer an
  even-numbered major; odd majors never become LTS.
- **pnpm**, provided by corepack (`corepack enable pnpm`). `scripts/setup.sh`
  does this for you.
- **git**.
- Optional: [`agr`](https://docs.astral.sh/uv/) (`uv tool install agr`) to
  install the Claude Code and Cursor skills. Setup skips them if it is absent.

## First run

```bash
./scripts/init.sh     # one time: answer the prompts, substitute the tokens
./scripts/setup.sh    # scaffold Astro, install dependencies, add integrations
make dev              # start the dev server
```

`init.sh` also takes flags, so a project can be created without a tty:

```bash
./scripts/init.sh --site acme-site --site-label "Acme Site" \
  --client "Acme Ltd" --skill-fork jamesfmcgrath \
  --flavour blog --deploy-target static
```

Run `./scripts/init.sh --help` for the full flag list. It records what it used
in `template.answers`, removes the template-only files, then removes itself.
Commit the result.

`setup.sh` is idempotent: re-running it is safe. It generates the Astro
scaffold in a temp directory and copies it in with `cp -n`, so a file this
template ships always wins over the upstream starter's version of the same
path. It starts no server.

```
./scripts/setup.sh --skip-install   # scaffold and skills only
```

Commit the `pnpm-lock.yaml` and `agr.lock` it generates.

## Tasks

```
make help          Show every target
make dev           Start the Astro dev server
make build         Production build
make preview       Serve the production build locally
make check         Type check .astro and TypeScript (astro check)
make lint          Lint (ESLint)
make lint-fix      Lint and apply fixes
make format        Format (Prettier)
make format-check  Check formatting without writing
make test          Unit tests (Vitest)
make spell         Spell check (CSpell)
make add I=<name>  Add an Astro integration or adapter
make clean         Remove dist/ and .astro/
make a11y          Accessibility scan (axe-core via Playwright)
make vrt           Visual regression test (Playwright)
make vrt-update    Regenerate VRT baselines (Linux/CI only; see below)
```

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
- The **first** local `make vrt` always fails: Playwright writes the missing
  baseline and reports the run as failed ("A snapshot doesn't exist ...,
  writing actual"). Run it again and it compares against what it just wrote
  and passes. Not a bug, and the CI job handles the same case its own way.
- Generate and refresh real baselines in CI (the `browser` GitHub Actions
  job) or a Linux container/VM, then commit the resulting
  `tests/vrt/__screenshots__/linux/` directory.
- In CI, a missing `linux/` baseline is not a failure: the job generates it
  and uploads it as a build artifact for review and commit. Once baselines
  exist, a genuine diff fails the job and the Playwright HTML report uploads
  as an artifact.

See `CONVENTIONS.md`, "Browser checks", for the full contract.

## Changing the deploy target

`{{DEPLOY_TARGET}}` decided whether an adapter was installed. To change it
later:

```bash
make add I=node        # server rendering on Node
make add I=cloudflare  # or Cloudflare
make add I=vercel      # or Vercel
```

**Use the short adapter name, not the scoped package name.** `astro add node`
installs `@astrojs/node` and writes the `adapter` entry into
`astro.config.mjs`; `astro add @astrojs/node` installs the package and
configures nothing, which leaves a fully static build and no error to tell you
so.

Then set `output` in `astro.config.mjs` to suit, and update `DEPLOY_TARGET` and
`ADAPTER` in `template.answers` so the record stays honest.

## Conventions

`CONVENTIONS.md` holds the rules this repo and its scripts follow: the token
grammar, the script contract, the CI guard-job inversion, the agent-resources
contract, the docs contract, and the house rules. `AGENTS.md` holds the coding
guidelines for AI tools and humans alike. Read both before changing anything in
`scripts/`.

## Updating from the template

The template's `CHANGELOG.md` is the update path. Read the entries added since
you created this project and apply the ones you want by hand. Do not merge the
template's git history into a project.
