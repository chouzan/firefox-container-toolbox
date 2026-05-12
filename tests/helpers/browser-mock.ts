import { vi } from "vitest";

// In-memory storage
let storage: Record<string, unknown> = {};

// In-memory containers
let containers: Array<{
  cookieStoreId: string;
  name: string;
  color: string;
  icon: string;
}> = [];
let nextContainerId = 1;

export function resetBrowserMock() {
  storage = {};
  containers = [];
  nextContainerId = 1;
}

export function seedContainers(
  items: Array<{ name: string; color: string; icon: string }>,
) {
  containers = items.map((c, i) => ({
    cookieStoreId: `firefox-container-${i + 1}`,
    ...c,
  }));
  nextContainerId = containers.length + 1;
}

export function getContainers() {
  return [...containers];
}

export function getStorage() {
  return { ...storage };
}

// Install mock on globalThis.browser
export function installBrowserMock() {
  const mock = {
    contextualIdentities: {
      query: vi.fn(async () => [...containers]),
      create: vi.fn(
        async (details: { name: string; color: string; icon: string }) => {
          const id = `firefox-container-${nextContainerId++}`;
          const container = { cookieStoreId: id, ...details };
          containers.push(container);
          return container;
        },
      ),
      update: vi.fn(
        async (
          id: string,
          details: { name?: string; color?: string; icon?: string },
        ) => {
          const c = containers.find((c) => c.cookieStoreId === id);
          if (!c) throw new Error(`Container ${id} not found`);
          Object.assign(c, details);
          return c;
        },
      ),
      remove: vi.fn(async (id: string) => {
        const idx = containers.findIndex((c) => c.cookieStoreId === id);
        if (idx >= 0) containers.splice(idx, 1);
        return {};
      }),
      move: vi.fn(async () => {}),
      onCreated: { addListener: vi.fn() },
      onRemoved: { addListener: vi.fn() },
      onUpdated: { addListener: vi.fn() },
    },
    storage: {
      local: {
        get: vi.fn(async (keys: Record<string, unknown> | null) => {
          if (keys === null) return { ...storage };
          const result: Record<string, unknown> = {};
          for (const [k, defaultVal] of Object.entries(keys)) {
            result[k] = storage[k] ?? defaultVal;
          }
          return result;
        }),
        set: vi.fn(async (items: Record<string, unknown>) => {
          Object.assign(storage, items);
        }),
      },
    },
    runtime: {
      onMessage: { addListener: vi.fn() },
      onInstalled: { addListener: vi.fn() },
    },
    downloads: {
      download: vi.fn(async () => 1),
    },
    identity: {
      getRedirectURL: vi.fn(() => "https://test.extensions.allizom.org/"),
      launchWebAuthFlow: vi.fn(async () => "https://redirect?code=test_code"),
    },
  };

  (globalThis as any).browser = mock;
  return mock;
}
