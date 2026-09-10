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
