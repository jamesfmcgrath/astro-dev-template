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
