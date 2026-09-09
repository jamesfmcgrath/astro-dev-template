# Using this template

This file exists only in the bare template. `scripts/init.sh` removes it, along
with `scripts/test-template.sh` and `template-docs/`.

## What you get

A standalone Astro project skeleton: a one-time tokeniser, an idempotent
spin-up script that scaffolds Astro through `create-astro`, a Makefile, CI that
tests the template itself until a project exists, and agent instructions
(`AGENTS.md`) written for Astro.

There is nothing Drupal-specific here: no DDEV, no composer, no PHP tooling, no
database concept.

## Steps

1. Create a repo from this template on GitHub.
2. Clone it.
3. Run `./scripts/init.sh` (prompts) or pass flags (see `--help`).
4. Run `./scripts/setup.sh`.
5. `make dev`.

## Token registry

Every `{{UPPER_SNAKE}}` name the tokeniser substitutes. Nothing else is a
token, and GitHub Actions `${{ }}` expressions are never touched.

### Prompted

| Token | Flag | Prompt | Default | Notes |
| --- | --- | --- | --- | --- |
| `SITE_NAME` | `--site` | Site machine name (kebab-case) | `my-site` | Becomes the npm package name. Must start with a lowercase letter, then lowercase letters, digits and hyphens only. |
| `SITE_LABEL` | `--site-label` | Site label | title-cased `SITE_NAME` | Human-readable name, used in headings and script output. |
| `CLIENT` | `--client` | Client / context | `an internal project` | Free text. `&` and `\|` are escaped for the substitution. |
| `SKILL_FORK` | `--skill-fork` | agent-resources fork owner | `jamesfmcgrath` | GitHub owner used as `default_owner` in `agr.toml`. |
| `FLAVOUR` | `--flavour` | Astro flavour | `minimal` | One of `minimal`, `blog`, `starlight`. |
| `DEPLOY_TARGET` | `--deploy-target` | Deploy target | `static` | One of `static`, `ssr`. |

`--defaults` accepts every default without prompting. A full flag set does the
same. Flags take `--flag VALUE` or `--flag=VALUE`; use `--flag=` for an
explicitly empty value.

### Derived

Computed by `init.sh` from the answers above. Never prompted, never flagged.

| Token | Derived from | Value |
| --- | --- | --- |
| `ASTRO_TEMPLATE` | `FLAVOUR` | The `create-astro --template` name. Currently the identity map: `minimal` to `minimal`, `blog` to `blog`, `starlight` to `starlight`. Verified against create-astro 5.2.4, which resolves `minimal` and `blog` to `github:withastro/astro/examples/<name>` and special-cases `starlight` to `github:withastro/starlight/examples/basics`. |
| `ADAPTER` | `DEPLOY_TARGET` | Empty for `static` (no adapter, fully static build). `@astrojs/node` for `ssr`. Swappable for `@astrojs/cloudflare` or `@astrojs/vercel`: see "Changing the deploy target" in the README. `setup.sh` strips the `@astrojs/` scope before calling `astro add`, because the command only registers an official adapter in `astro.config` when given the short name. |

Adding a token means: use it in a file, register it in both tables above, add a
`sub` line in `scripts/init.sh`, and add an assertion in
`scripts/test-template.sh`.

## What init.sh removes

- itself (`scripts/init.sh`)
- `TEMPLATE.md` (this file)
- `scripts/test-template.sh`
- `template-docs/` (`PROMPTS.md`, `memory.md`)

It keeps `CONVENTIONS.md`, because a created project still has the scripts and
contracts that file documents.

## Testing a change to the tokeniser

```bash
./scripts/test-template.sh
```

No network, no package manager, no scaffold: it copies the repo to a temp
directory and drives `init.sh` through every supported combination. Run it
before calling any script change done. CI runs it automatically while this repo
is still a bare template.
