import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
const args = process.argv.slice(2);
if (args.length !== 2 || args[0] !== "--target-org" || !args[1]) {
  console.error(
    "Usage: npm run validate:core -- --target-org <development-org-alias>"
  );
  process.exit(2);
}
function files(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) =>
    entry.isDirectory() ? files(join(dir, entry.name)) : [join(dir, entry.name)]
  );
}
const tests = files("force-app/main/default/classes")
  .filter(
    (file) =>
      file.endsWith("Test.cls") &&
      /@IsTest\s+static\s+void/i.test(readFileSync(file, "utf8"))
  )
  .map((file) => file.split("/").at(-1).replace(".cls", ""))
  .sort();
if (!tests.length) throw new Error("No test classes found");
const result = spawnSync(
  "sf",
  [
    "project",
    "deploy",
    "start",
    "--dry-run",
    "--target-org",
    args[1],
    "--source-dir",
    "force-app",
    "--test-level",
    "RunSpecifiedTests",
    ...tests.flatMap((test) => ["--tests", test]),
    "--wait",
    "10"
  ],
  { stdio: "inherit" }
);
if (result.error) throw result.error;
process.exit(result.status ?? 1);
