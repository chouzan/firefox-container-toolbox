import { describe, it, expect } from "vitest";
import { validateConfig } from "../src/lib/Validators.res.mjs";

describe("validateConfig", () => {
  const validConfig = {
    version: 1,
    meta: {
      exportedAt: "2026-05-12T00:00:00Z",
      exportedFrom: "container-toolbox@0.1.0",
    },
    containers: [
      { name: "Personal", color: "blue", icon: "fingerprint", order: 0 },
      { name: "Work", color: "orange", icon: "briefcase", order: 1 },
    ],
    stgGroups: [{ title: "Personal" }],
    stgHotkeys: [],
    stgDefaultGroupProps: {
      prependTitleToWindow: false,
      showNotificationAfterMovingTabIntoThisGroup: false,
    },
  };

  it("accepts a valid config", () => {
    expect(validateConfig(validConfig)).toBe(true);
  });

  it("rejects null", () => {
    expect(validateConfig(null)).toBe(false);
  });

  it("rejects non-object", () => {
    expect(validateConfig("string")).toBe(false);
    expect(validateConfig(42)).toBe(false);
  });

  it("rejects wrong version", () => {
    expect(validateConfig({ ...validConfig, version: 2 })).toBe(false);
  });

  it("rejects missing meta", () => {
    const { meta, ...noMeta } = validConfig;
    expect(validateConfig(noMeta)).toBe(false);
  });

  it("rejects missing containers array", () => {
    const { containers, ...noContainers } = validConfig;
    expect(validateConfig(noContainers)).toBe(false);
  });

  it("rejects container with empty name", () => {
    const bad = {
      ...validConfig,
      containers: [{ name: "", color: "blue", icon: "fingerprint", order: 0 }],
    };
    expect(validateConfig(bad)).toBe(false);
  });

  it("rejects container with negative order", () => {
    const bad = {
      ...validConfig,
      containers: [
        { name: "Test", color: "blue", icon: "fingerprint", order: -1 },
      ],
    };
    expect(validateConfig(bad)).toBe(false);
  });

  it("rejects missing stgGroups", () => {
    const { stgGroups, ...noGroups } = validConfig;
    expect(validateConfig(noGroups)).toBe(false);
  });

  it("rejects stgGroup without title", () => {
    const bad = { ...validConfig, stgGroups: [{ iconColor: "#fff" }] };
    expect(validateConfig(bad)).toBe(false);
  });

  it("rejects missing stgDefaultGroupProps", () => {
    const { stgDefaultGroupProps, ...noProps } = validConfig;
    expect(validateConfig(noProps)).toBe(false);
  });

  it("accepts empty containers array", () => {
    expect(validateConfig({ ...validConfig, containers: [] })).toBe(true);
  });

  it("accepts empty stgGroups array", () => {
    expect(validateConfig({ ...validConfig, stgGroups: [] })).toBe(true);
  });
});
