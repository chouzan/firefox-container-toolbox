import { describe, it, expect } from "vitest";
import {
  parseBackup,
  generateBackup,
  extractContainerNames,
  isVersionSupported,
} from "../src/background/modules/StgBridge.res.mjs";

describe("isVersionSupported", () => {
  it("accepts 5.3", () => {
    expect(isVersionSupported("5.3")).toBe(true);
  });

  it("accepts 5.3.2", () => {
    expect(isVersionSupported("5.3.2")).toBe(true);
  });

  it("accepts 5.5", () => {
    expect(isVersionSupported("5.5")).toBe(true);
  });

  it("accepts 6.0", () => {
    expect(isVersionSupported("6.0")).toBe(true);
  });

  it("rejects 5.2", () => {
    expect(isVersionSupported("5.2")).toBe(false);
  });

  it("rejects 4.0", () => {
    expect(isVersionSupported("4.0")).toBe(false);
  });
});

describe("extractContainerNames", () => {
  it("extracts unique names from groups", () => {
    const groups = [
      {
        title: "G1",
        newTabContainer: "Work",
        catchTabContainers: ["Personal", "Work"],
        excludeContainersForReOpen: [],
      },
      {
        title: "G2",
        newTabContainer: "$default",
        catchTabContainers: [],
        excludeContainersForReOpen: ["Finance"],
      },
    ] as any;

    const names = extractContainerNames(groups);
    expect(names).toContain("Work");
    expect(names).toContain("Personal");
    expect(names).toContain("Finance");
    expect(names).not.toContain("$default");
  });

  it("excludes special containers", () => {
    const groups = [
      {
        title: "G1",
        newTabContainer: "$temporary",
        catchTabContainers: ["$default"],
        excludeContainersForReOpen: ["$private"],
      },
    ] as any;

    const names = extractContainerNames(groups);
    expect(names).toHaveLength(0);
  });
});

describe("parseBackup", () => {
  // Deep clone helper — parseBackup mutates group objects in-place
  const clone = <T>(obj: T): T => JSON.parse(JSON.stringify(obj));

  const minimalBackup = {
    version: "5.3",
    groups: [
      {
        id: 1,
        title: "Work",
        iconColor: "#ff9f00",
        iconViewType: "circle",
        tabs: [
          {
            title: "Example",
            url: "https://example.com",
            cookieStoreId: "firefox-container-1",
          },
        ],
        newTabContainer: "firefox-container-1",
        catchTabContainers: ["firefox-container-1"],
        excludeContainersForReOpen: [],
        isArchive: false,
        isSticky: false,
        discardTabsAfterHide: false,
        discardExcludeAudioTabs: false,
        muteTabsWhenGroupCloseAndRestoreWhenOpen: false,
        prependTitleToWindow: true,
        exportToBookmarksWhenAutoBackup: false,
        leaveBookmarksOfClosedTabs: false,
        ifDifferentContainerReOpen: false,
        showTabAfterMovingItIntoThisGroup: false,
        showOnlyActiveTabAfterMovingItIntoThisGroup: false,
        showNotificationAfterMovingTabIntoThisGroup: false,
        catchTabRules: "",
        moveToGroupIfNoneCatchTabRules: null,
        bookmarkId: null,
      },
    ],
    containers: {
      "firefox-container-1": {
        name: "Work",
        color: "orange",
        icon: "briefcase",
      },
    },
    hotkeys: [],
    defaultGroupProps: {
      prependTitleToWindow: true,
      showNotificationAfterMovingTabIntoThisGroup: false,
    },
    lastCreatedGroupPosition: 1,
  };

  it("parses a valid backup", () => {
    const result = parseBackup(clone(minimalBackup));
    expect(result).not.toBeNull();
    expect(result.config.stgGroups).toHaveLength(1);
    expect(result.config.stgGroups[0].title).toBe("Work");
  });

  it("converts container IDs to names using backup dict", () => {
    const result = parseBackup(clone(minimalBackup));
    expect(result.config.stgGroups[0].newTabContainer).toBe("Work");
    expect(result.config.stgGroups[0].catchTabContainers).toEqual(["Work"]);
  });

  it("converts tab cookieStoreId using backup dict", () => {
    const result = parseBackup(clone(minimalBackup));
    const tab = result.config.stgGroups[0].tabs[0];
    expect(tab.cookieStoreId).toBe("Work");
  });

  it("converts special containers to portable names", () => {
    const backup = {
      ...minimalBackup,
      groups: [
        {
          ...minimalBackup.groups[0],
          newTabContainer: "firefox-default",
          catchTabContainers: ["temporary-container"],
        },
      ],
    };
    const result = parseBackup(clone(backup));
    expect(result.config.stgGroups[0].newTabContainer).toBe("$default");
    expect(result.config.stgGroups[0].catchTabContainers).toEqual([
      "$temporary",
    ]);
  });

  it("detects orphaned tabs", () => {
    const backup = {
      ...minimalBackup,
      groups: [
        {
          ...minimalBackup.groups[0],
          tabs: [
            {
              title: "Orphan",
              url: "https://orphan.com",
              cookieStoreId: "firefox-container-99",
            },
          ],
        },
      ],
    };
    const result = parseBackup(clone(backup));
    expect(result.orphanedTabs).toHaveLength(1);
    expect(result.orphanedTabs[0].group).toBe("Work");
    expect(result.orphanedTabs[0].container).toBe("firefox-container-99");
  });

  it("auto-fixes orphaned tabs to group newTabContainer", () => {
    const backup = {
      ...minimalBackup,
      groups: [
        {
          ...minimalBackup.groups[0],
          tabs: [
            {
              title: "Orphan",
              url: "https://orphan.com",
              cookieStoreId: "firefox-container-99",
            },
          ],
        },
      ],
    };
    const result = parseBackup(clone(backup));
    const tab = result.config.stgGroups[0].tabs[0];
    expect(tab.cookieStoreId).toBe("Work");
  });

  it("preserves STG version", () => {
    const result = parseBackup(clone(minimalBackup));
    expect(result.config.stgVersion).toBe("5.3");
  });

  it("preserves hotkey groupTitle resolution", () => {
    const backup = {
      ...minimalBackup,
      hotkeys: [
        { value: "Ctrl+1", action: "load-custom-group", groupId: 1 },
        { value: "Ctrl+N", action: "load-next-group", groupId: 0 },
      ],
    };
    const result = parseBackup(clone(backup));
    expect(result.config.stgHotkeys[0].groupTitle).toBe("Work");
    // groupId 0 → no group match → groupTitle absent (undefined in JS)
    expect(result.config.stgHotkeys[1].groupTitle).not.toBeDefined();
  });

  it("rejects unsupported version", () => {
    const old = { ...minimalBackup, version: "4.0" };
    expect(() => parseBackup(clone(old))).toThrow();
  });

  it("returns undefined for non-object input", () => {
    // ReScript option None compiles to undefined
    expect(parseBackup("not json")).toBeUndefined();
    expect(parseBackup(null)).toBeUndefined();
  });
});

describe("generateBackup round-trip", () => {
  it("generates valid STG backup structure", () => {
    const config = {
      version: 1,
      meta: { exportedAt: "2026-01-01", exportedFrom: "test" },
      containers: [],
      stgGroups: [
        {
          title: "Test",
          iconColor: "#fff",
          iconViewType: "circle",
          newTabContainer: "$default",
          catchTabContainers: [],
          excludeContainersForReOpen: [],
          isArchive: false,
          isSticky: false,
          discardTabsAfterHide: false,
          discardExcludeAudioTabs: false,
          muteTabsWhenGroupCloseAndRestoreWhenOpen: false,
          prependTitleToWindow: false,
          exportToBookmarksWhenAutoBackup: false,
          leaveBookmarksOfClosedTabs: false,
          ifDifferentContainerReOpen: false,
          showTabAfterMovingItIntoThisGroup: false,
          showOnlyActiveTabAfterMovingItIntoThisGroup: false,
          showNotificationAfterMovingTabIntoThisGroup: false,
          catchTabRules: "",
          moveToGroupIfNoneCatchTabRules: null,
          tabs: [],
        },
      ],
      stgHotkeys: [],
      stgDefaultGroupProps: {
        prependTitleToWindow: false,
        showNotificationAfterMovingTabIntoThisGroup: false,
      },
      stgVersion: "5.3",
    };

    const backup = generateBackup(config);
    expect(backup.version).toBe("5.3");
    expect(backup.groups).toHaveLength(1);
    expect(backup.groups[0].id).toBe(1);
    expect(backup.groups[0].title).toBe("Test");
    expect(backup.groups[0].newTabContainer).toBe("firefox-default");
    expect(backup.pinnedTabs).toEqual([]);
    expect(backup.lastCreatedGroupPosition).toBe(1);
  });

  it("uses default version when stgVersion is missing", () => {
    const config = {
      version: 1,
      meta: { exportedAt: "2026-01-01", exportedFrom: "test" },
      containers: [],
      stgGroups: [],
      stgHotkeys: [],
      stgDefaultGroupProps: {
        prependTitleToWindow: false,
        showNotificationAfterMovingTabIntoThisGroup: false,
      },
    };

    const backup = generateBackup(config);
    expect(backup.version).toBe("5.3");
  });
});
