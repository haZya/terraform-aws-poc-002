import { existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

function parseArgs(argv) {
  const args = {};

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg.startsWith("--")) {
      args[arg.slice(2)] = argv[index + 1];
      index += 1;
    }
  }

  return args;
}

function run(command, args, options) {
  const result = spawnSync(command, args, {
    stdio: "inherit",
    shell: process.platform === "win32",
    ...options,
  });

  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed with exit code ${result.status}`);
  }
}

const args = parseArgs(process.argv.slice(2));

if (!args.project) {
  throw new Error("Usage: node install-deps.mjs --project <dir>");
}

const project = resolve(args.project);
const hasLockfile = existsSync(join(project, "package-lock.json"));

run("npm", hasLockfile ? ["ci"] : ["install"], { cwd: project });
