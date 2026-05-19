import { createWriteStream, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { spawnSync } from "node:child_process";

function parseArgs(argv) {
  const args = {};

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === "--include-sharp") {
      args.includeSharp = true;
      continue;
    }

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

function listFiles(directory) {
  const files = [];

  for (const entry of readdirSync(directory)) {
    const path = join(directory, entry);
    const stats = statSync(path);

    if (stats.isDirectory()) {
      files.push(...listFiles(path));
      continue;
    }

    if (stats.isFile()) {
      files.push(path);
    }
  }

  return files;
}

const crcTable = new Uint32Array(256).map((_, index) => {
  let crc = index;

  for (let bit = 0; bit < 8; bit += 1) {
    crc = (crc & 1) ? (0xedb88320 ^ (crc >>> 1)) : (crc >>> 1);
  }

  return crc >>> 0;
});

function crc32(buffer) {
  let crc = 0xffffffff;

  for (const byte of buffer) {
    crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  }

  return (crc ^ 0xffffffff) >>> 0;
}

function dosDateTime(date) {
  const year = Math.max(date.getFullYear(), 1980);
  const dosTime = (date.getHours() << 11) | (date.getMinutes() << 5) | Math.floor(date.getSeconds() / 2);
  const dosDate = ((year - 1980) << 9) | ((date.getMonth() + 1) << 5) | date.getDate();

  return { dosDate, dosTime };
}

function writeZip(sourceDirectory, outputFile) {
  mkdirSync(dirname(outputFile), { recursive: true });

  const stream = createWriteStream(outputFile);
  const centralDirectory = [];
  let offset = 0;

  for (const file of listFiles(sourceDirectory).sort()) {
    const data = readFileSync(file);
    const name = relative(sourceDirectory, file).replace(/\\/g, "/");
    const nameBuffer = Buffer.from(name);
    const checksum = crc32(data);
    const { dosDate, dosTime } = dosDateTime(statSync(file).mtime);

    const localHeader = Buffer.alloc(30 + nameBuffer.length);
    localHeader.writeUInt32LE(0x04034b50, 0);
    localHeader.writeUInt16LE(20, 4);
    localHeader.writeUInt16LE(0, 6);
    localHeader.writeUInt16LE(0, 8);
    localHeader.writeUInt16LE(dosTime, 10);
    localHeader.writeUInt16LE(dosDate, 12);
    localHeader.writeUInt32LE(checksum, 14);
    localHeader.writeUInt32LE(data.length, 18);
    localHeader.writeUInt32LE(data.length, 22);
    localHeader.writeUInt16LE(nameBuffer.length, 26);
    localHeader.writeUInt16LE(0, 28);
    nameBuffer.copy(localHeader, 30);

    stream.write(localHeader);
    stream.write(data);

    centralDirectory.push({ nameBuffer, checksum, size: data.length, dosDate, dosTime, offset });
    offset += localHeader.length + data.length;
  }

  const centralStart = offset;

  for (const entry of centralDirectory) {
    const header = Buffer.alloc(46 + entry.nameBuffer.length);
    header.writeUInt32LE(0x02014b50, 0);
    header.writeUInt16LE(20, 4);
    header.writeUInt16LE(20, 6);
    header.writeUInt16LE(0, 8);
    header.writeUInt16LE(0, 10);
    header.writeUInt16LE(entry.dosTime, 12);
    header.writeUInt16LE(entry.dosDate, 14);
    header.writeUInt32LE(entry.checksum, 16);
    header.writeUInt32LE(entry.size, 20);
    header.writeUInt32LE(entry.size, 24);
    header.writeUInt16LE(entry.nameBuffer.length, 28);
    header.writeUInt16LE(0, 30);
    header.writeUInt16LE(0, 32);
    header.writeUInt16LE(0, 34);
    header.writeUInt16LE(0, 36);
    header.writeUInt32LE(0, 38);
    header.writeUInt32LE(entry.offset, 42);
    entry.nameBuffer.copy(header, 46);

    stream.write(header);
    offset += header.length;
  }

  const centralSize = offset - centralStart;
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(0, 4);
  end.writeUInt16LE(0, 6);
  end.writeUInt16LE(centralDirectory.length, 8);
  end.writeUInt16LE(centralDirectory.length, 10);
  end.writeUInt32LE(centralSize, 12);
  end.writeUInt32LE(centralStart, 16);
  end.writeUInt16LE(0, 20);
  stream.write(end);
  stream.end();
}

const args = parseArgs(process.argv.slice(2));

if (!args.project || !args.entry || !args.output) {
  throw new Error("Usage: node build-lambda.mjs --project <dir> --entry <entry.ts> --output <zip> [--include-sharp]");
}

const project = resolve(args.project);
const entry = join(project, args.entry);
const output = resolve(args.output);
const buildDirectory = output.replace(/\.zip$/, "");
const packageJson = JSON.parse(readFileSync(join(project, "package.json"), "utf8"));
const esbuildBin = join(project, "node_modules", ".bin", process.platform === "win32" ? "esbuild.cmd" : "esbuild");

rmSync(buildDirectory, { recursive: true, force: true });
mkdirSync(buildDirectory, { recursive: true });

run(esbuildBin, [
  entry,
  "--bundle",
  "--platform=node",
  "--target=node22",
  "--format=cjs",
  `--outfile=${join(buildDirectory, "index.js")}`,
  ...(args.includeSharp ? ["--external:sharp"] : []),
], { cwd: project });

if (args.includeSharp) {
  writeFileSync(join(buildDirectory, "package.json"), JSON.stringify({ dependencies: { sharp: packageJson.dependencies.sharp } }, null, 2));
  run("npm", ["install", "--omit=dev", "--no-audit", "--no-fund"], {
    cwd: buildDirectory,
    env: {
      ...process.env,
      NPM_CONFIG_BIN_LINKS: "false",
      npm_config_platform: "linux",
      npm_config_arch: "x64",
      npm_config_libc: "glibc",
    },
  });
}

writeZip(buildDirectory, output);
