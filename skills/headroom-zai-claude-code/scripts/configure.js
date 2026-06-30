#!/usr/bin/env node
const fs = require("fs");
const os = require("os");
const path = require("path");

const args = process.argv.slice(2);
const modeIndex = args.indexOf("--mode");
const mode = modeIndex >= 0 ? args[modeIndex + 1] : "headroom";

if (!["headroom", "direct"].includes(mode)) {
  console.error("Usage: ZAI_API_KEY=<key> node scripts/configure.js --mode headroom|direct");
  process.exit(2);
}

const home = os.homedir();
const claudeSettingsPath = path.join(home, ".claude", "settings.json");
const headroomManifestPath = path.join(home, ".headroom", "deploy", "default", "manifest.json");
const zAiUrl = "https://api.z.ai/api/anthropic";
const headroomUrl = "http://127.0.0.1:8787";

function readJsonIfExists(filePath, fallback) {
  if (!fs.existsSync(filePath)) return fallback;
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not parse ${filePath}: ${error.message}`);
  }
}

function writeJson(filePath, data) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`);
}

const settings = readJsonIfExists(claudeSettingsPath, {});
const env = { ...(settings.env || {}) };

if (process.env.ZAI_API_KEY) {
  env.ANTHROPIC_AUTH_TOKEN = process.env.ZAI_API_KEY;
}

env.ANTHROPIC_BASE_URL = mode === "headroom" ? headroomUrl : zAiUrl;
env.API_TIMEOUT_MS = "3000000";
env.CLAUDE_CODE_AUTO_COMPACT_WINDOW = "1000000";
env.ANTHROPIC_DEFAULT_HAIKU_MODEL = "glm-4.5-air";
env.ANTHROPIC_DEFAULT_SONNET_MODEL = "glm-5.2[1m]";
env.ANTHROPIC_DEFAULT_OPUS_MODEL = "glm-5.2[1m]";

settings.env = env;
writeJson(claudeSettingsPath, settings);

let headroomUpdated = false;
let headroomMissing = false;

if (mode === "headroom") {
  if (fs.existsSync(headroomManifestPath)) {
    const manifest = readJsonIfExists(headroomManifestPath, {});
    manifest.base_env = {
      ...(manifest.base_env || {}),
      ANTHROPIC_TARGET_API_URL: zAiUrl,
    };

    const oldArgs = Array.isArray(manifest.proxy_args) ? manifest.proxy_args : [];
    const filteredArgs = [];
    for (let i = 0; i < oldArgs.length; i += 1) {
      if (oldArgs[i] === "--anthropic-api-url") {
        i += 1;
        continue;
      }
      filteredArgs.push(oldArgs[i]);
    }
    manifest.proxy_args = [...filteredArgs, "--anthropic-api-url", zAiUrl];
    manifest.tool_envs = {
      ...(manifest.tool_envs || {}),
      claude: {
        ...(((manifest.tool_envs || {}).claude) || {}),
        ANTHROPIC_BASE_URL: headroomUrl,
      },
    };
    manifest.updated_at = new Date().toISOString();
    writeJson(headroomManifestPath, manifest);
    headroomUpdated = true;
  } else {
    headroomMissing = true;
  }
}

console.log(`Claude settings updated: ${claudeSettingsPath}`);
console.log(`Mode: ${mode}`);
console.log(`ANTHROPIC_BASE_URL=${env.ANTHROPIC_BASE_URL}`);
console.log(`ANTHROPIC_AUTH_TOKEN=${env.ANTHROPIC_AUTH_TOKEN ? "<set>" : "<missing>"}`);
console.log(`ANTHROPIC_DEFAULT_SONNET_MODEL=${env.ANTHROPIC_DEFAULT_SONNET_MODEL}`);
console.log(`ANTHROPIC_DEFAULT_OPUS_MODEL=${env.ANTHROPIC_DEFAULT_OPUS_MODEL}`);

if (mode === "headroom") {
  if (headroomUpdated) {
    console.log(`Headroom manifest updated: ${headroomManifestPath}`);
    console.log("Restart Headroom: launchctl kickstart -k gui/$(id -u)/com.headroom.default");
  }
  if (headroomMissing) {
    console.log(`Headroom manifest not found: ${headroomManifestPath}`);
    console.log("Install Headroom first, then rerun this script.");
  }
}
