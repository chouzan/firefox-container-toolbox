import { describe, it, expect } from "vitest";
import {
  parseBackup,
  generateBackup,
  extractBackupContainers,
} from "../src/background/modules/StgBridge.res.mjs";

const clone = <T>(obj: T): T => JSON.parse(JSON.stringify(obj));

const fullBackup = {
  version: "5.3.2",
  groups: [
    {
      id: 1,
      title: "Personal",
      iconColor: "#45818e",
      iconViewType: "circle",
      tabs: [
        {
          title: "Gmail",
          url: "https://mail.google.com",
          cookieStoreId: "firefox-default",
          id: 100,
        },
      ],
      newTabContainer: "firefox-default",
      catchTabContainers: ["firefox-container-1"],
      excludeContainersForReOpen: [],
      isArchive: false,
      isSticky: false,
      discardTabsAfterHide: false,
      discardExcludeAudioTabs: false,
      muteTabsWhenGroupCloseAndRestoreWhenOpen: true,
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
    {
      id: 2,
      title: "Work",
      iconColor: "#ff9f00",
      iconViewType: "circle",
      tabs: [
        {
          title: "Jira",
          url: "https://jira.example.com",
          cookieStoreId: "firefox-container-2",
          id: 200,
        },
        {
          title: "Slack",
          url: "https://slack.example.com",
          cookieStoreId: "firefox-container-2",
          id: 201,
        },
      ],
      newTabContainer: "firefox-container-2",
      catchTabContainers: ["firefox-container-2"],
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
    {
      id: 3,
      title: "Temporary",
      iconColor: "#ffffff",
      iconViewType: "circle",
      tabs: [],
      newTabContainer: "temporary-container",
      catchTabContainers: [],
      excludeContainersForReOpen: [],
      isArchive: false,
      isSticky: false,
      discardTabsAfterHide: true,
      discardExcludeAudioTabs: false,
      muteTabsWhenGroupCloseAndRestoreWhenOpen: false,
      prependTitleToWindow: false,
      exportToBookmarksWhenAutoBackup: false,
      leaveBookmarksOfClosedTabs: false,
      ifDifferentContainerReOpen: true,
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
      name: "Personal",
      color: "blue",
      icon: "fingerprint",
    },
    "firefox-container-2": {
      name: "Work",
      color: "orange",
      icon: "briefcase",
    },
  },
  hotkeys: [
    { value: "Ctrl+Alt+1", action: "load-custom-group", groupId: 1 },
    { value: "Ctrl+Alt+2", action: "load-custom-group", groupId: 2 },
    { value: "Ctrl+Alt+PageDown", action: "load-next-group", groupId: 0 },
  ],
  defaultGroupProps: {
    prependTitleToWindow: true,
    showNotificationAfterMovingTabIntoThisGroup: false,
  },
  lastCreatedGroupPosition: 3,
};

describe("STG round-trip", () => {
  it("preserves group count through round-trip", () => {
    const parsed = parseBackup(clone(fullBackup));
    const generated = generateBackup(parsed.config);
    expect(generated.groups).toHaveLength(3);
  });

  it("preserves group titles through round-trip", () => {
    const parsed = parseBackup(clone(fullBackup));
    const generated = generateBackup(parsed.config);
    expect(generated.groups[0].title).toBe("Personal");
    expect(generated.groups[1].title).toBe("Work");
    expect(generated.groups[2].title).toBe("Temporary");
  });

  it("preserves group properties through round-trip", () => {
    const parsed = parseBackup(clone(fullBackup));
    const generated = generateBackup(parsed.config);
    expect(generated.groups[0].prependTitleToWindow).toBe(true);
    expect(generated.groups[0].muteTabsWhenGroupCloseAndRestoreWhenOpen).toBe(
      true,
    );
    expect(generated.groups[2].discardTabsAfterHide).toBe(true);
    expect(generated.groups[2].ifDifferentContainerReOpen).toBe(true);
  });

  it("converts special containers to portable names and back", () => {
    const parsed = parseBackup(clone(fullBackup));
    // After parse: firefox-default → $default, temporary-container → $temporary
    expect(parsed.config.stgGroups[0].newTabContainer).toBe("$default");
    expect(parsed.config.stgGroups[2].newTabContainer).toBe("$temporary");

    const generated = generateBackup(parsed.config);
    // After generate: $default → firefox-default, $temporary → temporary-container
    expect(generated.groups[0].newTabContainer).toBe("firefox-default");
    expect(generated.groups[2].newTabContainer).toBe("temporary-container");
  });

  it("converts container IDs to names using backup dict", () => {
    const parsed = parseBackup(clone(fullBackup));
    expect(parsed.config.stgGroups[0].catchTabContainers).toEqual(["Personal"]);
    expect(parsed.config.stgGroups[1].newTabContainer).toBe("Work");
    expect(parsed.config.stgGroups[1].catchTabContainers).toEqual(["Work"]);
  });

  it("converts tab cookieStoreId through round-trip", () => {
    const parsed = parseBackup(clone(fullBackup));
    // Tab cookieStoreId should be portable name after parse
    expect(parsed.config.stgGroups[0].tabs[0].cookieStoreId).toBe("$default");
    expect(parsed.config.stgGroups[1].tabs[0].cookieStoreId).toBe("Work");
  });

  it("preserves tab count through round-trip", () => {
    const parsed = parseBackup(clone(fullBackup));
    const generated = generateBackup(parsed.config);
    expect(generated.groups[0].tabs).toHaveLength(1);
    expect(generated.groups[1].tabs).toHaveLength(2);
    expect(generated.groups[2].tabs).toHaveLength(0);
  });

  it("preserves tab content through round-trip", () => {
    const parsed = parseBackup(clone(fullBackup));
    const generated = generateBackup(parsed.config);
    expect(generated.groups[1].tabs[0].title).toBe("Jira");
    expect(generated.groups[1].tabs[0].url).toBe("https://jira.example.com");
  });

  it("assigns sequential group IDs on generate", () => {
    const parsed = parseBackup(clone(fullBackup));
    const generated = generateBackup(parsed.config);
    expect(generated.groups[0].id).toBe(1);
    expect(generated.groups[1].id).toBe(2);
    expect(generated.groups[2].id).toBe(3);
  });

  it("resolves hotkey groupId → groupTitle → groupId", () => {
    const parsed = parseBackup(clone(fullBackup));
    // After parse: groupId 1 → title "Personal"
    expect(parsed.config.stgHotkeys[0].groupTitle).toBe("Personal");
    expect(parsed.config.stgHotkeys[1].groupTitle).toBe("Work");
    // groupId 0 → no title
    expect(parsed.config.stgHotkeys[2].groupTitle).not.toBeDefined();

    const generated = generateBackup(parsed.config);
    // After generate: title "Personal" → groupId 1
    expect(generated.hotkeys[0].groupId).toBe(1);
    expect(generated.hotkeys[1].groupId).toBe(2);
    expect(generated.hotkeys[2].groupId).toBe(0);
  });

  it("preserves STG version through round-trip", () => {
    const parsed = parseBackup(clone(fullBackup));
    expect(parsed.config.stgVersion).toBe("5.3.2");

    const generated = generateBackup(parsed.config);
    expect(generated.version).toBe("5.3.2");
  });

  it("preserves defaultGroupProps", () => {
    const parsed = parseBackup(clone(fullBackup));
    const generated = generateBackup(parsed.config);
    expect(generated.defaultGroupProps.prependTitleToWindow).toBe(true);
    expect(
      generated.defaultGroupProps.showNotificationAfterMovingTabIntoThisGroup,
    ).toBe(false);
  });

  it("generates required STG backup fields", () => {
    const parsed = parseBackup(clone(fullBackup));
    const generated = generateBackup(parsed.config);
    expect(generated.version).toBeDefined();
    expect(generated.groups).toBeDefined();
    expect(generated.hotkeys).toBeDefined();
    expect(generated.defaultGroupProps).toBeDefined();
    expect(generated.containers).toBeDefined();
    expect(generated.pinnedTabs).toBeDefined();
    expect(generated.lastCreatedGroupPosition).toBe(3);
  });

  it("strips runtime fields (id, bookmarkId, iconUrl)", () => {
    const parsed = parseBackup(clone(fullBackup));
    const group = parsed.config.stgGroups[0] as any;
    expect(group.id).toBeUndefined();
    expect(group.bookmarkId).toBeUndefined();
    expect(group.iconUrl).toBeUndefined();
  });
});

describe("extractBackupContainers", () => {
  it("extracts container info from backup", () => {
    const containers = extractBackupContainers(fullBackup);
    expect(containers).toHaveLength(2);
    const personal = containers.find((c: any) => c.name === "Personal");
    expect(personal).toBeDefined();
    expect(personal.color).toBe("blue");
    expect(personal.icon).toBe("fingerprint");
  });

  it("returns empty for backup without containers", () => {
    const { containers, ...noContainers } = fullBackup;
    expect(extractBackupContainers(noContainers)).toHaveLength(0);
  });
});
