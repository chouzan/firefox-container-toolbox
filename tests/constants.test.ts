import { describe, it, expect } from "vitest";
import {
  extensionId,
  extensionVersion,
  stgExtensionId,
  containerColors,
  containerIcons,
  specialContainers,
  specialContainersReverse,
  messagePrefix,
  defaultColor,
  defaultIcon,
  defaultConflictResolution,
  currentSchemaVersion,
  configVersion,
  action,
} from "../src/lib/Constants.res.mjs";

describe("Constants", () => {
  it("has correct extension identity", () => {
    expect(extensionId).toBe("container-toolbox@chouzan");
    expect(extensionVersion).toBe("0.1.0");
    expect(stgExtensionId).toBe("simple-tab-groups@drive4ik");
  });

  it("has 9 container colours", () => {
    expect(containerColors).toHaveLength(9);
    expect(containerColors).toContain("blue");
    expect(containerColors).toContain("toolbar");
  });

  it("has 13 container icons", () => {
    expect(containerIcons).toHaveLength(13);
    expect(containerIcons).toContain("fingerprint");
    expect(containerIcons).toContain("fence");
  });

  it("maps special containers bidirectionally", () => {
    expect(specialContainers["$default"]).toBe("firefox-default");
    expect(specialContainers["$private"]).toBe("firefox-private");
    expect(specialContainers["$temporary"]).toBe("temporary-container");

    expect(specialContainersReverse["firefox-default"]).toBe("$default");
    expect(specialContainersReverse["firefox-private"]).toBe("$private");
    expect(specialContainersReverse["temporary-container"]).toBe("$temporary");
  });

  it("has consistent defaults", () => {
    expect(defaultColor).toBe("blue");
    expect(defaultIcon).toBe("fingerprint");
    expect(defaultConflictResolution).toBe("local-wins");
  });

  it("has correct schema and config versions", () => {
    expect(currentSchemaVersion).toBe(1);
    expect(configVersion).toBe(1);
  });

  it("has message prefix", () => {
    expect(messagePrefix).toBe("container-toolbox:");
  });

  it("has all action constants defined", () => {
    const expectedActions = [
      "getStatus",
      "getContainers",
      "getSettings",
      "updateSettings",
      "createContainer",
      "updateContainer",
      "deleteContainer",
      "moveContainer",
      "reconcileNow",
      "exportConfig",
      "importConfig",
      "getConflicts",
      "resolveConflict",
      "driveAuthenticate",
      "driveRevoke",
      "driveStatus",
      "driveSetCredentials",
      "syncPull",
      "syncPush",
      "forcePushLocal",
      "clearRemote",
      "previewStgBackup",
      "confirmStgImport",
      "generateStgBackup",
    ];

    for (const key of expectedActions) {
      expect(action[key]).toBeDefined();
      expect(typeof action[key]).toBe("string");
      expect(action[key].length).toBeGreaterThan(0);
    }
  });

  it("action values are unique", () => {
    const values = Object.values(action);
    const unique = new Set(values);
    expect(unique.size).toBe(values.length);
  });
});
