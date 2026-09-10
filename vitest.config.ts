// No `/// <reference types="vitest/config" />` here on purpose: the import
// below already pulls those types in, and having both is exactly what
// @typescript-eslint/triple-slash-reference's default "prefer-import" flags,
// so "make lint" fails. Observed live on 2026-09-10.
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
