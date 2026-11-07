/**
 * Draws every TGUI window the game tests opened, with the data the game sent it, and fails on any that crash.
 * The game test (code/tests/test_tgui_windows.dm) saves the windows to data/tgui_window_data.json.
 * Run with: tgui/bin/tgui --window-check
 */

import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { act } from 'react';
import { createRoot } from 'react-dom/client';
import { describe, expect, it, vi } from 'vitest';

import { backendUpdate, setGlobalStore } from './backend';
import { IconProvider } from './Icons';
import { configureStore } from './store';

type SavedWindow = {
  type: string;
  interface: string;
  payload: string;
};

// Paths are from the tgui folder, which is where this runs
const dataFile = resolve(process.env.TGUI_WINDOW_DATA || '../data/tgui_window_data.json');
const savedWindows: SavedWindow[] = JSON.parse(readFileSync(dataFile, 'utf8'));

// Same places routes.tsx looks for an interface
const interfaceFolder = resolve('packages/tgui/interfaces');
const interfacePaths = (name: string) =>
  [`${name}.tsx`, `${name}.jsx`, `${name}/index.tsx`, `${name}/index.jsx`].map((path) =>
    resolve(interfaceFolder, path)
  );

// Same as Byond.parseJson in tgui-setup/helpers.js
function parseByondJson(json: string) {
  return JSON.parse(json, (key, value) =>
    typeof value === 'object' && value !== null && value.__number__ ? parseFloat(value.__number__) : value
  );
}

async function drawWindow(window: SavedWindow) {
  const path = interfacePaths(window.interface).find((path) => existsSync(path));
  if (!path) {
    throw new Error(`no interface called ${window.interface}`);
  }
  const Interface = (await import(/* @vite-ignore */ path))[window.interface];
  if (!Interface) {
    throw new Error(`${path} doesn't export ${window.interface}`);
  }

  const store = configureStore({ sideEffects: false });
  setGlobalStore(store);
  store.dispatch(backendUpdate(parseByondJson(window.payload)));

  const container = document.createElement('div');
  document.body.appendChild(container);
  const errors: unknown[] = [];
  const root = createRoot(container, { onCaughtError: (error) => errors.push(error) });
  try {
    await act(async () =>
      root.render(
        <>
          <Interface />
          <IconProvider />
        </>
      )
    );
    await act(async () => root.unmount());
  } finally {
    container.remove();
  }
  if (errors.length) {
    throw errors[0];
  }
}

describe('TGUI windows', () => {
  // Lots of windows get the same data, so only draw each once
  const seen = new Set<string>();
  const windows = savedWindows.filter((window) => {
    const key = window.interface + window.payload;
    return !seen.has(key) && seen.add(key);
  });

  it('has windows to draw', () => {
    expect(windows.length).toBeGreaterThan(0);
  });

  for (const window of windows) {
    it(`${window.type} (${window.interface})`, async () => {
      // Warnings aren't crashes, and there are thousands of windows
      vi.spyOn(console, 'error').mockImplementation(() => {});
      vi.spyOn(console, 'warn').mockImplementation(() => {});
      vi.spyOn(console, 'log').mockImplementation(() => {});
      await drawWindow(window);
    });
  }
});
