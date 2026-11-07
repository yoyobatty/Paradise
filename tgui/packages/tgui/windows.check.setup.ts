// Everything tgui expects BYOND to give it, set up before tgui's own files load
(globalThis as any).IS_REACT_ACT_ENVIRONMENT = true;
(globalThis as any).Byond = {
  windowId: 'window-check',
  iconRefMap: {},
  winget: async () => ({}),
  winset: () => {},
  sendMessage: () => {},
  subscribe: () => {},
  loadCss: () => {},
  loadJs: () => {},
};

// Makes an import.meta.glob of a folder act like webpack's require.context, see vitest.window-check.config.mts
(globalThis as any).__requireContext = (modules: Record<string, unknown>, folder: string, filter?: RegExp) => {
  const load = (key: string) => {
    const module = modules[folder + key.slice(1)];
    if (!module) {
      throw Object.assign(new Error(`Cannot find module '${key}'`), { code: 'MODULE_NOT_FOUND' });
    }
    return module;
  };
  load.keys = () =>
    Object.keys(modules)
      .map((path) => '.' + path.slice(folder.length))
      .filter((key) => !filter || filter.test(key));
  return load;
};
