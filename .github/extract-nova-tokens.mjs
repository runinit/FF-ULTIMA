#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  mkdir,
  readFile,
  readdir,
  stat,
  writeFile,
} from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const BASELINE = Object.freeze({
  version: "154.0b2",
  tag: "FIREFOX_154_0b2_RELEASE",
  commit: "946dc6c3467a2a952e0bc3c8a8808cdbcb2acae6",
  sourceRepository: "https://github.com/mozilla-firefox/firefox",
  sourceStamp: "b7b1868f2e31da0d089ccb869ec773fa5d9fd9ac",
  buildId: "20260725024243",
  expectedFileCount: 20,
  expectedTokenCount: 307,
});

const SEARCH_ROOTS = Object.freeze([
  "browser/themes/shared/tabbrowser",
  "browser/themes/shared/urlbar",
  "toolkit/themes/shared/design-system/src/tokens/base",
  "toolkit/themes/shared/design-system/src/tokens/components",
]);

function usage() {
  return [
    "Usage:",
    "  node .github/extract-nova-tokens.mjs \\",
    "    --source /path/to/firefox-source \\",
    "    --output .github/nova-tokens/firefox-154.0b2.json",
  ].join("\n");
}

function parseArguments(argv) {
  const options = {};

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--help" || argument === "-h") {
      process.stdout.write(`${usage()}\n`);
      process.exit(0);
    }

    if (argument !== "--source" && argument !== "--output") {
      throw new Error(`Unknown argument: ${argument}`);
    }

    const value = argv[index + 1];
    if (!value || value.startsWith("--")) {
      throw new Error(`Missing value for ${argument}`);
    }

    options[argument.slice(2)] = value;
    index += 1;
  }

  if (!options.source || !options.output) {
    throw new Error(`Both --source and --output are required.\n\n${usage()}`);
  }

  return {
    source: path.resolve(options.source),
    output: path.resolve(options.output),
  };
}

function runGit(source, args) {
  try {
    return execFileSync("git", ["-C", source, ...args], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    }).trim();
  } catch (error) {
    const detail = error.stderr?.toString().trim();
    throw new Error(
      `Unable to inspect Firefox source checkout${detail ? `: ${detail}` : ""}`,
    );
  }
}

async function assertSourceCheckout(source) {
  let sourceStats;
  try {
    sourceStats = await stat(source);
  } catch {
    throw new Error(`Firefox source directory does not exist: ${source}`);
  }

  if (!sourceStats.isDirectory()) {
    throw new Error(`Firefox source path is not a directory: ${source}`);
  }

  const commit = runGit(source, ["rev-parse", "HEAD"]);
  if (commit !== BASELINE.commit) {
    throw new Error(
      `Firefox source revision mismatch: expected ${BASELINE.commit}, found ${commit}`,
    );
  }

  const tags = runGit(source, ["tag", "--points-at", "HEAD"])
    .split(/\r?\n/u)
    .filter(Boolean);
  if (!tags.includes(BASELINE.tag)) {
    throw new Error(
      `Firefox source checkout is missing expected tag ${BASELINE.tag}`,
    );
  }
}

async function findNovaFiles(source) {
  const files = [];

  for (const relativeRoot of SEARCH_ROOTS) {
    const absoluteRoot = path.join(source, relativeRoot);
    const entries = await readdir(absoluteRoot, { withFileTypes: true });

    for (const entry of entries) {
      if (entry.isFile() && entry.name.endsWith(".nova.tokens.json")) {
        files.push(path.posix.join(relativeRoot, entry.name));
      }
    }
  }

  files.sort();
  if (files.length !== BASELINE.expectedFileCount) {
    throw new Error(
      `Nova source file count mismatch: expected ${BASELINE.expectedFileCount}, found ${files.length}`,
    );
  }

  return files;
}

function sha256(contents) {
  return createHash("sha256").update(contents).digest("hex");
}

function getNode(root, segments) {
  return segments.reduce((node, segment) => node?.[segment], root);
}

function tokenName(prefix, segments) {
  const normalizedSegments = segments.filter((segment) => segment !== "@base");
  return `--${[prefix, ...normalizedSegments].join("-")}`;
}

function compareTokenNames(left, right) {
  return left.name < right.name ? -1 : left.name > right.name ? 1 : 0;
}

function collectTokens({
  value,
  baseValue,
  prefix,
  relativeSource,
  relativeBaseSource,
  owner,
  segments = [],
  tokens,
}) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(
      `Unexpected token structure in ${relativeSource} at ${segments.join(".")}`,
    );
  }

  if (Object.hasOwn(value, "value")) {
    const baseNode = getNode(baseValue, segments);
    if (!baseNode || !Object.hasOwn(baseNode, "value")) {
      throw new Error(
        `Missing base token for ${relativeSource} at ${segments.join(".")}`,
      );
    }

    tokens.push({
      name: tokenName(prefix, segments),
      path: segments.join("."),
      owner,
      source: relativeSource,
      baseSource: relativeBaseSource,
      value: value.value,
      baseValue: baseNode.value,
      override: baseNode.override ?? null,
      comment: value.comment ?? baseNode.comment ?? null,
    });
    return;
  }

  for (const key of Object.keys(value).sort()) {
    collectTokens({
      value: value[key],
      baseValue,
      prefix,
      relativeSource,
      relativeBaseSource,
      owner,
      segments: [...segments, key],
      tokens,
    });
  }
}

async function extractFile(source, relativeSource) {
  const relativeBaseSource = relativeSource.replace(
    /\.nova\.tokens\.json$/u,
    ".tokens.json",
  );
  const sourceContents = await readFile(path.join(source, relativeSource));
  const baseContents = await readFile(path.join(source, relativeBaseSource));
  const sourceJson = JSON.parse(sourceContents.toString("utf8"));
  const baseJson = JSON.parse(baseContents.toString("utf8"));
  const prefix = path.basename(relativeSource, ".nova.tokens.json");
  let owner;
  if (relativeSource.startsWith("browser/themes/shared/tabbrowser/")) {
    owner = "browser/tabbrowser";
  } else if (relativeSource.startsWith("browser/themes/shared/urlbar/")) {
    owner = "browser/urlbar";
  } else if (relativeSource.includes("/tokens/base/")) {
    owner = "toolkit-design-system/base";
  } else {
    owner = "toolkit-design-system/components";
  }
  const tokens = [];

  collectTokens({
    value: sourceJson,
    baseValue: baseJson,
    prefix,
    relativeSource,
    relativeBaseSource,
    owner,
    tokens,
  });

  tokens.sort(compareTokenNames);

  return {
    source: {
      path: relativeSource,
      sha256: sha256(sourceContents),
      basePath: relativeBaseSource,
      baseSha256: sha256(baseContents),
      owner,
      tokenCount: tokens.length,
    },
    tokens,
  };
}

async function main() {
  const { source, output } = parseArguments(process.argv.slice(2));
  await assertSourceCheckout(source);
  const files = await findNovaFiles(source);
  const extracted = await Promise.all(
    files.map((relativeSource) => extractFile(source, relativeSource)),
  );
  const tokens = extracted
    .flatMap((entry) => entry.tokens)
    .sort(compareTokenNames);
  const uniqueNames = new Set(tokens.map((token) => token.name));

  if (tokens.length !== BASELINE.expectedTokenCount) {
    throw new Error(
      `Nova token count mismatch: expected ${BASELINE.expectedTokenCount}, found ${tokens.length}`,
    );
  }
  if (uniqueNames.size !== tokens.length) {
    throw new Error(
      `Nova token names are not unique: ${tokens.length - uniqueNames.size} duplicates found`,
    );
  }

  const snapshot = {
    schemaVersion: 1,
    firefox: {
      version: BASELINE.version,
      tag: BASELINE.tag,
      commit: BASELINE.commit,
      sourceRepository: BASELINE.sourceRepository,
      sourceStamp: BASELINE.sourceStamp,
      buildId: BASELINE.buildId,
    },
    counts: {
      files: files.length,
      tokens: tokens.length,
    },
    sources: extracted.map((entry) => entry.source),
    tokens,
  };

  await mkdir(path.dirname(output), { recursive: true });
  await writeFile(output, `${JSON.stringify(snapshot, null, 2)}\n`, "utf8");
  process.stdout.write(
    `Extracted ${tokens.length} Nova tokens from ${files.length} files to ${output}\n`,
  );
}

main().catch((error) => {
  process.stderr.write(`extract-nova-tokens: ${error.message}\n`);
  process.exitCode = 1;
});
