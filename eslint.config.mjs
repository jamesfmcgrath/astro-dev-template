// ESLint flat config. typescript-eslint's config is spread before
// eslint-plugin-astro's, not after: eslint-plugin-astro's base config
// assigns astro-eslint-parser to *.astro files, and typescript-eslint's
// config sets a parser with no `files` restriction, so loading it second
// would overwrite that assignment and break Astro frontmatter parsing.
// See CONVENTIONS.md, "Quality toolchain".
import js from '@eslint/js';
import eslintPluginAstro from 'eslint-plugin-astro';
import tseslint from 'typescript-eslint';

export default [
  { ignores: ['dist/**', '.astro/**', 'node_modules/**'] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  ...eslintPluginAstro.configs.recommended,
];
