import fs from "node:fs";
import path from "node:path";

const root = "force-app/main/default";
const modules = JSON.parse(fs.readFileSync("config/modules.json", "utf8"));
const roles = new Set([
  "services",
  "selectors",
  "domains",
  "dto",
  "exceptions",
  "interfaces",
  "strategies",
  "factories",
  "providers",
  "builders",
  "handlers",
  "tests"
]);
function files(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .flatMap((entry) =>
      entry.isDirectory()
        ? files(path.join(dir, entry.name))
        : [path.join(dir, entry.name)]
    );
}
const errors = [];
const classes = new Map();
for (const file of files(`${root}/classes`).filter((file) =>
  file.endsWith(".cls")
)) {
  const parts = path.relative(`${root}/classes`, file).split(path.sep);
  const [module, role, name] = parts;
  if (parts.length !== 3 || !modules[module] || !roles.has(role))
    errors.push(`Invalid module/role path: ${file}`);
  const className = path.basename(file, ".cls");
  if (classes.has(className)) errors.push(`Duplicate Apex name: ${className}`);
  if (!fs.existsSync(`${file}-meta.xml`))
    errors.push(`Missing metadata: ${file}`);
  const source = fs.readFileSync(file, "utf8");
  if (!new RegExp(`\\b(class|interface)\\s+${className}\\b`, "i").test(source))
    errors.push(`Declaration/file mismatch: ${file}`);
  if (/SeeAllData\s*=\s*true/i.test(source))
    errors.push(`Org-data-dependent test: ${file}`);
  classes.set(className, { file, module, source });
}
const archivedNames = files("archive/legacy-crm/main/default/classes")
  .filter((file) => file.endsWith(".cls"))
  .map((file) => path.basename(file, ".cls"))
  .filter((name) => !classes.has(name));
for (const [name, current] of classes) {
  for (const [other, dependency] of classes) {
    if (
      current.module !== dependency.module &&
      new RegExp(`(?<![\\w.])${other}\\b`).test(current.source) &&
      !modules[current.module]?.dependencies.includes(dependency.module)
    )
      errors.push(`Undeclared dependency: ${name} -> ${other}`);
  }
  for (const archived of archivedNames)
    if (new RegExp(`\\b${archived}\\b`).test(current.source))
      errors.push(`Core depends on archive: ${name} -> ${archived}`);
}
for (const file of files(root).filter((file) => file.endsWith(".cls-meta.xml")))
  if (!fs.existsSync(file.replace(/-meta.xml$/, "")))
    errors.push(`Orphan class metadata: ${file}`);
const knownObjects = new Set(
  Object.values(modules).flatMap((module) => module.objects)
);
for (const entry of fs.existsSync(`${root}/objects`)
  ? fs.readdirSync(`${root}/objects`)
  : [])
  if (!knownObjects.has(entry))
    errors.push(`Object has no module owner: ${entry}`);
if (errors.length) {
  console.error(errors.join("\n"));
  process.exitCode = 1;
} else
  console.log(
    `Module checks passed: ${Object.keys(modules).length} modules, ${classes.size} Apex classes/interfaces.`
  );
