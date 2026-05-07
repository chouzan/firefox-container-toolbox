// Minimal type declarations for Firefox WebExtension APIs used by Container Toolbox.
// Hand-written for the subset of APIs this extension uses.

declare namespace browser {
  // --- contextualIdentities ---
  namespace contextualIdentities {
    interface ContextualIdentity {
      cookieStoreId: string;
      name: string;
      color: string;
      icon: string;
      colorCode?: string;
      iconUrl?: string;
    }

    function create(details: {
      name: string;
      color: string;
      icon: string;
    }): Promise<ContextualIdentity>;

    function query(details: { name?: string }): Promise<ContextualIdentity[]>;

    function get(cookieStoreId: string): Promise<ContextualIdentity>;

    function update(
      cookieStoreId: string,
      details: { name?: string; color?: string; icon?: string },
    ): Promise<ContextualIdentity>;

    function remove(cookieStoreId: string): Promise<ContextualIdentity>;

    function move(
      cookieStoreIds: string | string[],
      position: number,
    ): Promise<void>;

    interface ChangeInfo {
      contextualIdentity: ContextualIdentity;
    }

    const onCreated: Events.Event<(changeInfo: ChangeInfo) => void>;
    const onRemoved: Events.Event<(changeInfo: ChangeInfo) => void>;
    const onUpdated: Events.Event<(changeInfo: ChangeInfo) => void>;
  }

  // --- storage ---
  namespace storage {
    namespace local {
      function get(
        keys?: string | string[] | Record<string, unknown> | null,
      ): Promise<Record<string, unknown>>;
      function set(items: Record<string, unknown>): Promise<void>;
      function remove(keys: string | string[]): Promise<void>;
      function clear(): Promise<void>;
    }
  }

  // --- runtime ---
  namespace runtime {
    function sendMessage(
      extensionId: string,
      message: unknown,
    ): Promise<unknown>;
    function sendMessage(message: unknown): Promise<unknown>;

    function getURL(path: string): string;

    function openOptionsPage(): Promise<void>;

    const onMessage: Events.Event<
      (
        message: unknown,
        sender: runtime.MessageSender,
        sendResponse: (response?: unknown) => void,
      ) => boolean | Promise<unknown> | void
    >;

    const onInstalled: Events.Event<
      (details: { reason: string; previousVersion?: string }) => void
    >;

    interface MessageSender {
      tab?: { id: number; url?: string };
      frameId?: number;
      id?: string;
      url?: string;
    }

    function getManifest(): Record<string, unknown>;
  }

  // --- downloads ---
  namespace downloads {
    function download(options: {
      url: string;
      filename?: string;
      saveAs?: boolean;
      conflictAction?: "uniquify" | "overwrite" | "prompt";
    }): Promise<number>;
  }

  // --- notifications ---
  namespace notifications {
    function create(
      notificationId: string,
      options: {
        type: "basic";
        title: string;
        message: string;
        iconUrl?: string;
      },
    ): Promise<string>;
  }

  // --- identity ---
  namespace identity {
    function launchWebAuthFlow(details: {
      url: string;
      interactive: boolean;
      redirectUri?: string;
    }): Promise<string>;

    function getRedirectURL(): string;
  }

  // --- Events helper ---
  namespace Events {
    interface Event<T extends (...args: never[]) => unknown> {
      addListener(callback: T): void;
      removeListener(callback: T): void;
      hasListener(callback: T): boolean;
    }
  }
}
