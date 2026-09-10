# Project memory: astro-dev-template

Last updated: 2026-09-09

## What this is

GitHub template repo (github.com/jamesfmcgrath/astro-dev-template). Create a
project from it, run `./scripts/init.sh` (tokeniser), then `./scripts/setup.sh`
(scaffold plus dependencies), and get a working Astro project ready to code in.
Staged improvement prompts and their status live in `PROMPTS.md`. The rules the
repo follows live in `CONVENTIONS.md` at the root, which stays in created
projects.

Reference lineage: patterns were adapted from
localgov-drupal-dev-template (token grammar, the three-script split,
`template.answers`, dynamic file discovery, the CI guard-job inversion, the
agent-resources contract, the house rules). Nothing Drupal-specific was
carried over, and this repo owes that one no fidelity.

## Axes

- Flavour: `minimal`, `blog`, `starlight`. Maps to the `create-astro`
  `--template` name, currently identity.
- Deploy target: `static` (no adapter), `ssr` (`@astrojs/node`, swappable for
  `@astrojs/cloudflare` or `@astrojs/vercel`).

Six combinations. The regression suite covers four of them (the three flavours
on static, plus minimal on ssr), on the grounds that the adapter axis is
independent of the template axis at the tokeniser level.

## Verification status

Live means: `init.sh` run, `setup.sh` run to completion including
`create-astro`, `pnpm install`, the type-checking dependencies and `astro add`,
then `make check` and `make build` succeeded. A row gains a date only when that
has actually happened. Nothing here is inferred.

| Flavour | Deploy target | Status | Date | Notes |
| --- | --- | --- | --- | --- |
| minimal | static | verified end to end | 2026-09-09 | setup exit 0, 7 files copied and 3 template files kept, `make check` 0 errors, `make build` 1 page, `make dev` served the front page with HTTP 200. |
| minimal | ssr | verified end to end | 2026-09-09 | Adapter registered in `astro.config.mjs`, build reports `mode: "server"` and "Server built". Verified only after the adapter short-name fix below. `make dev` not exercised on this combination. |
| blog | static | verified end to end | 2026-09-09 | 33 files copied, 3 template files kept, `make check` 0 errors, `make build` 8 pages. `make dev` not exercised. |
| blog | ssr | not yet verified | | Not in the regression suite. No reason to expect a difference from minimal/ssr, but that is inference, not evidence. |
| starlight | static | verified end to end | 2026-09-09 | 10 files copied, 3 template files kept, `make check` 0 errors, `make build` 4 pages. Two build warnings come from the starter's own content, not from this template: the `i18n` collection is empty, and `docs -> 404` is not found. `make dev` not exercised. |
| starlight | ssr | not yet verified | | Not in the regression suite. Starlight is a docs site; confirm SSR is wanted before verifying. |

Environment for the runs above: macOS 15 (Darwin 25.6.0), Node 26.8.1
(Homebrew), pnpm 12.3.4, Astro 7.3.2, create-astro 5.2.4.

## Bugs found by the live runs (2026-09-09)

All four were found by running the thing, none by reading it. Each is fixed and
commented at the fix site.

1. **`cp -Rn` exit status.** BSD `cp` exits 1 when `-n` skips an existing file;
   GNU `cp` exits 0. `setup.sh` treated the exit status as success or failure
   and aborted every macOS run. Replaced with an explicit per-entry copy loop
   that also reports which template files won.
2. **`ERR_PNPM_IGNORED_BUILDS`.** pnpm 12 makes an unapproved dependency build
   script a hard `pnpm install` failure, not a warning. Astro needs `esbuild`
   built. `setup.sh` now writes `pnpm-workspace.yaml` with `esbuild` and
   `sharp` allowed, using `allowBuilds` on pnpm 11 and later and
   `onlyBuiltDependencies` on pnpm 10, rather than turning on
   `dangerouslyAllowAllBuilds`.
3. **`astro check` prompted for its own dependencies.** Without `@astrojs/check`
   and `typescript` the command stops on an interactive prompt, which would
   hang CI. `setup.sh` installs them, and **pins `typescript@^6`**: an unpinned
   add installs TypeScript 7.0.2, whose native compiler does not expose the
   programmatic API the checker uses, so `make check` fails with
   `assertCompatibleTypeScript`. `@astrojs/check` 0.9.10 peer-requires
   `^5.0.0 || ^6.0.0`. Track
   https://github.com/withastro/roadmap/discussions/1321 and drop the pin when
   TypeScript 7 is supported.
4. **`astro add @astrojs/node` is inert.** Given the scoped package name,
   `astro add` installs the package and writes nothing into `astro.config.mjs`.
   The build then stays fully static with no error. Only the short name
   (`node`, `cloudflare`, `vercel`, `netlify`) registers the adapter.
   `setup.sh` now strips the `@astrojs/` scope before calling `astro add`, and
   the README and Makefile say to use short names.

## Known non-bugs

- `[@astrojs/sitemap] The Sitemap integration requires the site astro.config
  option. Skipping.` on every build. Correct: a fresh project has no production
  URL. `setup.sh` ends by telling the user to set `site`.
- `output: "static"` on an ssr project. Correct for Astro 5 and later: with an
  adapter present, routes prerender by default and opt into on-demand rendering
  with `export const prerender = false`. The build line to watch is
  `mode: "server"`.
- `corepack not found` on Node 25 and later. Corepack was removed from the Node
  distribution in v25 (nodejs/node "build: remove corepack from release
  tarballs"). `setup.sh` warns and falls back to a pnpm already on PATH, which
  is why the runs above used Homebrew pnpm 12.3.4. CI pins Node 22, which still
  bundles corepack.

## Facts verified without a live run (2026-09-09)

Read from the npm registry and the published packages, not from memory:

- `astro` latest 7.3.2. `engines`: node >=22.12.0, npm >=9.6.5, pnpm >=7.1.0.
- `create-astro` 5.2.4, engines node >=22.12.0. Template choices offered:
  `basics`, `blog`, `starlight`, `minimal`. `minimal` and `blog` resolve to
  `github:withastro/astro/examples/<name>`; `starlight` is special-cased to
  `github:withastro/starlight/examples/basics`. Flags: `--template`, `--ref`,
  `--yes`/`-y`, `--no`/`-n`, `--install`/`--no-install`, `--git`/`--no-git`,
  `--no-ai`, `--skip-houston`, `--dry-run`, `--help`, `--fancy`, `--add`.
  There is no `--typescript` flag.
- `astro add` takes `--yes` and `--help` only, and accepts a scoped package
  name such as `@astrojs/node`. Official adapter short names: `node`,
  `netlify`, `vercel`, `cloudflare`.
- `@astrojs/check` 0.9.10, `@astrojs/sitemap` 3.7.4, `@astrojs/node` 11.1.5,
  `@astrojs/starlight` 0.42.0.
- `eslint-plugin-astro` 3.1.0, `typescript-eslint` 8.70.0, `prettier` 3.9.6,
  `prettier-plugin-astro` 1.0.0, `vitest` 5.0.0, `cspell` 10.3.0. Confirmed
  live in a throwaway sandbox (not just read from the registry): the flat
  config order matters (`typescript-eslint` before `eslint-plugin-astro`, or
  the astro parser gets overwritten), `eslint-plugin-jsx-a11y` cannot install
  alongside ESLint 10, and `typescript-eslint`'s `typescript <6.1.0` peer
  range still fits our `^6` pin because only `6.0.x` has shipped.
- GitHub Actions: `actions/checkout` v7.0.1, `actions/setup-node` v7.0.0.

## Open questions

- Whether `starlight` should be offered on `ssr` at all.
- The `quality` and `build` CI jobs have never run. They cannot, until a
  project created from this template pushes with a `package.json` present.
- `make dev` has been exercised on minimal/static only.
