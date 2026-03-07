const { spawnSync } = require("node:child_process");
const { cpSync, existsSync, mkdirSync, mkdtempSync, rmSync } = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..", "..", "..");
const appRoot = path.resolve(__dirname, "..");
const zipPath = path.join(repoRoot, "lambda.zip");
const sourcePath = path.join(appRoot, "src");
const nodeModulesPath = path.join(repoRoot, "node_modules");
const packageJsonPath = path.join(repoRoot, "package.json");

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { stdio: "inherit", ...options });

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

if (!existsSync(nodeModulesPath)) {
  console.error("node_modules is missing. Run `npm ci` before packaging.");
  process.exit(1);
}

const stagingRoot = mkdtempSync(path.join(os.tmpdir(), "placethedude-lambda-"));
const stagingPackage = path.join(stagingRoot, "package");

try {
  mkdirSync(stagingPackage, { recursive: true });
  cpSync(sourcePath, path.join(stagingPackage, "src"), { recursive: true });
  cpSync(nodeModulesPath, path.join(stagingPackage, "node_modules"), { recursive: true });
  cpSync(packageJsonPath, path.join(stagingPackage, "package.json"));

  if (process.platform === "win32") {
    run("powershell", [
      "-NoProfile",
      "-Command",
      `if (Test-Path '${zipPath}') { Remove-Item '${zipPath}' }; Compress-Archive -Path src,node_modules,package.json -DestinationPath '${zipPath}'`
    ], { cwd: stagingPackage });
  } else {
    run("bash", ["-lc", `rm -f '${zipPath}' && zip -qr '${zipPath}' src node_modules package.json`], { cwd: stagingPackage });
  }
} finally {
  rmSync(stagingRoot, { recursive: true, force: true });
}
