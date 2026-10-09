/** Regression coverage for the recurrence-aware duplicate guard. */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/src"],
  testMatch: ["**/*.test.ts"],
  // `lib/` holds the compiled output — never run those as tests twice.
  testPathIgnorePatterns: ["/node_modules/", "/lib/"],
};
