import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const checker = fileURLToPath(new URL("./check-modules.mjs", import.meta.url));

function checkReference(t, reference, dependencies = []) {
  const root = mkdtempSync(join(tmpdir(), "module-reference-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  function write(file, source) {
    const target = join(root, file);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, source);
  }
  write(
    "config/modules.json",
    JSON.stringify({
      trigger: { dependencies: [], objects: [] },
      logging: { dependencies, objects: [] }
    })
  );
  for (const [path, source] of [
    ["trigger/dto/TriggerContext", "public class TriggerContext {}"],
    [
      "logging/services/LogEventTriggerService",
      `public class LogEventTriggerService { ${reference} }`
    ]
  ]) {
    const file = `force-app/main/default/classes/${path}.cls`;
    write(file, source);
    write(`${file}-meta.xml`, "<ApexClass />");
  }
  const result = spawnSync(process.execPath, [checker], {
    cwd: root,
    encoding: "utf8"
  });
  assert.ifError(result.error);
  return result;
}

test("platform-qualified nested type does not create an application dependency", (t) => {
  const result = checkReference(t, "EventBus.TriggerContext context;");
  assert.equal(result.status, 0, result.stderr);
});

test("unqualified application type requires a declared dependency", (t) => {
  const result = checkReference(t, "TriggerContext context;");
  assert.equal(result.status, 1);
  assert.match(
    result.stderr,
    /Undeclared dependency: LogEventTriggerService -> TriggerContext/
  );
});

test("static application reference still requires a declared dependency", (t) => {
  const result = checkReference(
    t,
    "Object context = TriggerContext.current();"
  );
  assert.equal(result.status, 1);
  assert.match(
    result.stderr,
    /Undeclared dependency: LogEventTriggerService -> TriggerContext/
  );
});

test("declared application dependency is accepted", (t) => {
  const result = checkReference(t, "TriggerContext context;", ["trigger"]);
  assert.equal(result.status, 0, result.stderr);
});
