import { transformWithEsbuild } from 'vite';
import { defineConfig, Plugin } from 'vitest/config';

// Webpack's require.context loads a whole folder. Vite has import.meta.glob for that, so swap one for the other.
// The setup file has the helper that makes the glob act like require.context.
function requireContext(): Plugin {
  return {
    name: 'require-context',
    enforce: 'pre',
    transform(code, id) {
      if (id.includes('node_modules') || !code.includes('require.context(')) {
        return;
      }
      return code.replace(
        /require\.context\(\s*['"]([^'"]+)['"]\s*(?:,\s*(true|false))?\s*(?:,\s*(\/.+?\/[a-z]*))?\s*\)/g,
        (_, folder, recursive, filter) =>
          `__requireContext(import.meta.glob('${folder}/${recursive === 'false' ? '' : '**/'}*.{js,jsx,ts,tsx}', { eager: true }), '${folder}', ${filter || 'undefined'})`
      );
    },
  };
}

// tgui's .js files have JSX in them, which Vite only expects in .jsx files
function jsxInJs(): Plugin {
  return {
    name: 'jsx-in-js',
    enforce: 'pre',
    transform(code, id) {
      if (id.includes('node_modules') || !id.endsWith('.js')) {
        return;
      }
      return transformWithEsbuild(code, id, { loader: 'jsx', jsx: 'automatic' });
    },
  };
}

// Draws the TGUI windows saved by the game tests, see packages/tgui/windows.check.tsx
export default defineConfig({
  plugins: [jsxInJs(), requireContext()],
  esbuild: { jsx: 'automatic' },
  test: {
    include: ['packages/tgui/windows.check.tsx'],
    environment: 'jsdom',
    setupFiles: ['packages/tgui/windows.check.setup.ts'],
    restoreMocks: true,
  },
});
