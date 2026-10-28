import { describe, expect, it } from "vitest";
import { safeReturnTo } from "./safe-redirect";

const FE = "http://localhost:8080";

describe("safeReturnTo", () => {
  it("keeps paths on the frontend", () => {
    expect(safeReturnTo("/branches?x=1#top", FE)).toBe("/branches?x=1#top");
    expect(safeReturnTo("/", FE)).toBe("/");
  });
  it("refuses anything that leaves the site", () => {
    for (const bad of ["//evil.com", "/\\evil.com", "https://evil.com", "javascript:alert(1)", "evil.com", "/%5C%5Cevil.com\\x", ""]) {
      expect(safeReturnTo(bad, FE)).toBe("/dashboard");
    }
    expect(safeReturnTo(null, FE)).toBe("/dashboard");
  });
});
