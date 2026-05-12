import { describe, it, expect, beforeEach } from "vitest";
import {
  installBrowserMock,
  resetBrowserMock,
  seedContainers,
  getContainers,
} from "../helpers/browser-mock.js";

// Install mock before importing ReScript modules
installBrowserMock();

// Dynamic imports so browser mock is in place first
const { listContainers, createContainer, removeContainer, reconcile } =
  await import("../../src/background/modules/ContainerManager.res.mjs");
const { initialize, refresh } =
  await import("../../src/background/modules/NameResolver.res.mjs");
const { migrate } =
  await import("../../src/background/modules/StorageManager.res.mjs");

describe("ContainerManager integration", () => {
  beforeEach(async () => {
    resetBrowserMock();
    await migrate();
  });

  it("lists containers", async () => {
    seedContainers([
      { name: "Personal", color: "blue", icon: "fingerprint" },
      { name: "Work", color: "orange", icon: "briefcase" },
    ]);

    const result = await listContainers();
    expect(result).toHaveLength(2);
    expect(result[0].name).toBe("Personal");
    expect(result[1].name).toBe("Work");
  });

  it("creates a container", async () => {
    const result = await createContainer("Test", "blue", "fingerprint");
    expect(result.name).toBe("Test");
    expect(result.cookieStoreId).toBe("firefox-container-1");
    expect(getContainers()).toHaveLength(1);
  });

  it("removes a container", async () => {
    seedContainers([{ name: "ToDelete", color: "red", icon: "circle" }]);
    expect(getContainers()).toHaveLength(1);

    await removeContainer("firefox-container-1");
    expect(getContainers()).toHaveLength(0);
  });

  it("reconciles — creates missing containers", async () => {
    seedContainers([{ name: "Personal", color: "blue", icon: "fingerprint" }]);
    await refresh();

    const desired = [
      { name: "Personal", color: "blue", icon: "fingerprint", order: 0 },
      { name: "Work", color: "orange", icon: "briefcase", order: 1 },
    ];

    const result = await reconcile(desired);
    expect(result.created).toContain("Work");
    expect(getContainers()).toHaveLength(2);
  });

  it("reconciles — updates mismatched colour/icon", async () => {
    seedContainers([{ name: "Personal", color: "red", icon: "circle" }]);
    await refresh();

    const desired = [
      { name: "Personal", color: "blue", icon: "fingerprint", order: 0 },
    ];

    const result = await reconcile(desired);
    expect(result.updated).toContain("Personal");
    const updated = getContainers().find((c) => c.name === "Personal");
    expect(updated?.color).toBe("blue");
    expect(updated?.icon).toBe("fingerprint");
  });

  it("reconciles — no changes when already matching", async () => {
    seedContainers([{ name: "Personal", color: "blue", icon: "fingerprint" }]);
    await refresh();

    const desired = [
      { name: "Personal", color: "blue", icon: "fingerprint", order: 0 },
    ];

    const result = await reconcile(desired);
    expect(result.created).toHaveLength(0);
    expect(result.updated).toHaveLength(0);
    expect(result.removed).toHaveLength(0);
  });
});
