# {{SITE_LABEL}} Development Guidelines

This is an Astro project for {{CLIENT}}. Follow these guidelines when working on it.

This file is the single source of truth for AI coding tools. Cursor reads it natively; Claude Code loads it via the `@AGENTS.md` import in `CLAUDE.md`. Edit this file, not the stub.

## Project Context

- **Site:** `{{SITE_NAME}}` ({{SITE_LABEL}})
- **Flavour:** `{{FLAVOUR}}` (the create-astro starter this project began from)
- **Deploy target:** `{{DEPLOY_TARGET}}`, adapter `{{ADAPTER}}` (empty means a fully static build)
- **Stack:** Astro 7, Node 22.12.0 or higher, pnpm
- **Conventions:** see `CONVENTIONS.md` for the script, CI, docs and agent-resources contracts
- **Do not use git worktrees**, work directly in the repo on the feature branch

Run everything through pnpm from the repo root, or through the Makefile:

```bash
make dev      # astro dev
make check    # astro check
make build    # astro build
make help     # every target
```

## Components

- Build components as `.astro` files. Reach for a framework component only when
  the interaction genuinely needs one.
- **Every component declares a typed `Props` interface** in its frontmatter and
  destructures from `Astro.props` against it. An untyped prop is a bug.

  ```astro
  ---
  interface Props {
    title: string;
    level?: 2 | 3 | 4;
  }
  const { title, level = 2 } = Astro.props;
  ---
  ```

- Use slots for anything the caller passes in as markup, named slots when there
  is more than one. Do not accept markup through a string prop.
- Scope styles in the component's own `<style>` block. Astro scopes them by
  default; do not reach for `:global` to escape that without a stated reason.
- Do not reach into another component's internals. If two components need the
  same value, it is a design token or a shared module, not a copied literal.

## Zero JavaScript by Default

Astro ships no client JavaScript unless you ask for it. Keep it that way.

- A component with no interactivity gets **no `client:*` directive**. Static
  markup is the default and the goal.
- Where interactivity is genuinely required, use the **narrowest directive that
  works**, in this order of preference:
  `client:visible` (below the fold, most cases) →
  `client:idle` (needed soon after load) →
  `client:load` (needed immediately, above the fold) →
  `client:only` (last resort, no server render at all, so it costs a layout
  shift and has no no-JS fallback).
  `client:media` is the right answer when the interactivity only exists at a
  given breakpoint.
- Prefer a solution with no directive at all: CSS for disclosure and hover, a
  native `<details>`, a form that posts, a link that navigates.
- Never add a directive speculatively. If a reviewer cannot say which user
  action needs it, remove it.

## Content Collections

- Content lives in content collections with **typed schemas**, defined in
  `src/content.config.ts` with `defineCollection` and a Zod schema. An
  unvalidated frontmatter field is a bug waiting for a build to fail.
- Use a loader (`glob()` or `file()`) rather than reading the filesystem by
  hand.
- Query with `getCollection` and `getEntry`. Do not glob content directories
  directly in a page.
- Schema changes are breaking changes for the content: update the entries in
  the same commit.

## Dev Toolbar Audits

- The Astro dev toolbar's audit panel reports accessibility and performance
  problems on the page you are looking at. **Treat its findings like lint
  findings:** they block the change, they are not advisory.
- Check the audit panel after any template or style change, on every page the
  change touches.
- Do not dismiss a finding without either fixing it or recording in the commit
  message why it does not apply.

## Accessibility

Build and review to **WCAG 2.2 AA**. Treat accessibility findings like security
findings: they block merge.

- Semantic markup first: landmarks, one `h1`, heading order, buttons for
  actions, links for navigation; ARIA only when native HTML cannot do it.
- Keyboard: everything reachable and operable, visible `:focus-visible` styles,
  never `outline: none` without a replacement, no positive `tabindex`.
- Contrast at least 4.5:1 for text and 3:1 for large text and UI components;
  meaning never conveyed by colour alone.
- Motion behind `prefers-reduced-motion`; touch targets at least 24x24 CSS px;
  reflow at 320 px width and 200% zoom.
- An island that only works with JavaScript needs a sensible state before
  hydration, not an empty box.

## Front-end Standards

- **Modern CSS**: flexbox/grid with `gap`, logical properties (`margin-inline`,
  `padding-block`), custom properties for design tokens, `clamp()` for fluid
  sizing, `aspect-ratio`. No floats for layout, no `!important` escalation.
- **DRY**: reuse existing tokens and components before adding new ones.
  Repeated values become custom properties; repeated rule blocks mean the
  component should be extended, not copied.
- **Simple, clean code**: smallest change that solves the problem, lowest
  specificity that works, no speculative abstractions, delete dead code as you
  go.
- Use `rem`/`em` for type and spacing so user font scaling works; `px` only for
  borders and fine detail.
- Use `<Image />` from `astro:assets` for local images so they are optimised and
  carry intrinsic dimensions. Every image needs a considered `alt`, empty only
  when it is genuinely decorative.

## Agent Resources

**Pending Stage 5.** The `astro-expert` skill does not exist yet, so `agr.toml`
ships with an empty dependency list and `setup.sh`'s `agr sync` is a no-op.
When the skill lands, add it to `agr.toml`, re-run `./scripts/setup.sh`, commit
the generated `agr.lock`, and replace this paragraph with the usage guidance.

Contract while it is pending (see `CONVENTIONS.md`): `AGENTS.md` is canonical,
`CLAUDE.md` is an import stub, `agr.toml` is tracked, installed skills are
gitignored, and an `agr` failure warns rather than aborting setup.

## Working Rules

- Work incrementally: small, self-contained changes, tested as you go.
- Any change ships passing `make check`, `make lint`, `make test` and
  `make build` before it is considered done.
- No em dashes in output. No code comments unless essential.
