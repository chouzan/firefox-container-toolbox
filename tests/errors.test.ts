import { describe, it, expect } from "vitest";
import { make, toInfo, AppError } from "../src/lib/Errors.res.mjs";

describe("Errors", () => {
  describe("make", () => {
    it("creates an exception with code and message", () => {
      const err = make("CONFIG_INVALID", "Bad config");
      expect(err).toBeDefined();
      expect(err.RE_EXN_ID).toBe(AppError);
    });
  });

  describe("toInfo", () => {
    it("extracts code and message from AppError", () => {
      const err = make("CONTAINER_NOT_FOUND", "Not found");
      const info = toInfo(err);
      expect(info.code).toBe("CONTAINER_NOT_FOUND");
      expect(info.message).toBe("Not found");
    });

    it("handles JS Error as unknown error", () => {
      // ReScript's JsExn pattern wraps differently than raw Error
      const err = new Error("something broke");
      const info = toInfo(err);
      expect(info.code).toBe("INTERNAL_ERROR");
      expect(typeof info.message).toBe("string");
    });

    it("handles non-Error objects", () => {
      const info = toInfo("string error" as any);
      expect(info.code).toBe("INTERNAL_ERROR");
    });

    it("throws on null/undefined (no crash guard)", () => {
      // ReScript's toInfo doesn't guard against null — callers should handle
      expect(() => toInfo(undefined as any)).toThrow();
      expect(() => toInfo(null as any)).toThrow();
    });
  });
});
