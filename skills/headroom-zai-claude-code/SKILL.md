---
name: headroom-zai-claude-code
description: Configure, repair, or verify Claude Code using Z.AI GLM Coding Plan through the Headroom proxy. Use when the user mentions Claude Code, Z.AI, GLM, GLM-5.2, ANTHROPIC_BASE_URL, Headroom proxy, Claude settings.json, or wants Claude Code traffic to flow through Headroom while still using Z.AI/GLM.
compatibility: macOS/Linux focused. Requires Claude Code, Node.js 18+, optional Headroom CLI, and network access for installs/docs. Windows Z.AI direct env setup is covered, but Headroom service steps are macOS/Linux oriented.
---

# Claude Code + Z.AI + Headroom

Use this skill to configure Claude Code so the request path is:

```text
Claude Code -> Headroom proxy on localhost -> Z.AI Anthropic-compatible endpoint -> GLM model
```

The common target setup is:

```text
Claude Code ANTHROPIC_BASE_URL = http://127.0.0.1:8787
Headroom ANTHROPIC_TARGET_API_URL = https://api.z.ai/api/anthropic
ANTHROPIC_DEFAULT_SONNET_MODEL = glm-5.2[1m]
ANTHROPIC_DEFAULT_OPUS_MODEL = glm-5.2[1m]
ANTHROPIC_DEFAULT_HAIKU_MODEL = glm-4.5-air
CLAUDE_CODE_AUTO_COMPACT_WINDOW = 1000000
```

Never print API keys. Redact `ANTHROPIC_AUTH_TOKEN`, `ZAI_API_KEY`, and shell command history that contains secrets.

## Sources To Check

For current Z.AI details, fetch the docs index first:

```bash
curl -fsSL https://docs.z.ai/llms.txt
```

Relevant pages from that index:

- `https://docs.z.ai/scenario-example/develop-tools/claude.md`
- `https://docs.z.ai/devpack/latest-model.md`
- `https://docs.z.ai/devpack/extension/coding-tool-helper.md`

For skills format changes, consult `https://agentskills.io/specification` before editing this skill.

## First Decide The Mode

Use **Headroom mode** when the user wants compression/proxy routing:

```text
Claude Code -> http://127.0.0.1:8787 -> Headroom -> https://api.z.ai/api/anthropic
```

Use **direct Z.AI mode** only when Headroom is not installed or the user explicitly wants to bypass it:

```text
Claude Code -> https://api.z.ai/api/anthropic
```

If Headroom mode fails and the user needs Claude Code working immediately, temporarily switch to direct Z.AI mode and tell them the proxy was bypassed.

## From-Scratch Setup

1. Check prerequisites:

```bash
node --version
npm --version
claude --version
```

Claude Code requires Node.js 18+. On macOS, prefer `nvm` for Node to avoid global npm permission issues.

2. Install or update Claude Code:

```bash
npm install -g @anthropic-ai/claude-code
claude --version
```

If already installed, prefer:

```bash
claude update
```

3. Get a Z.AI API key from:

```text
https://z.ai/model-api
https://z.ai/manage-apikey/apikey-list
```

Do not store the key in the skill. For scripted setup, put it in the current shell only:

```bash
read -s ZAI_API_KEY
export ZAI_API_KEY
```

4. Install Headroom if needed. The existing known-good installation on this machine used `headroom-ai` via `pipx`, with the CLI at `~/.local/bin/headroom`. If missing, install Headroom according to the current Headroom project instructions, then verify:

```bash
command -v headroom
headroom --version
```

5. Install the persistent Headroom proxy:

```bash
headroom install apply \
  --preset persistent-service \
  --scope user \
  --providers auto \
  --no-telemetry
```

For code-aware compression, the existing machine setup used:

```text
HEADROOM_CODE_AWARE_ENABLED=1
headroom proxy --code-aware
```

If tree-sitter dependencies are missing, Headroom may still run with weaker compression.

## Configure Existing Or New Machine

Prefer the bundled script because it preserves existing Claude settings, hooks, plugins, and unrelated config:

```bash
cd ~/.claude/skills/headroom-zai-claude-code
ZAI_API_KEY='paste-key-in-this-shell-only' node scripts/configure.js --mode headroom
```

For direct Z.AI mode:

```bash
cd ~/.claude/skills/headroom-zai-claude-code
ZAI_API_KEY='paste-key-in-this-shell-only' node scripts/configure.js --mode direct
```

The script:

- Updates `~/.claude/settings.json`.
- Preserves existing `hooks`, `enabledPlugins`, `statusLine`, and other settings.
- Sets `ANTHROPIC_AUTH_TOKEN` from `ZAI_API_KEY` if provided.
- Sets GLM 5.2 1M model mapping.
- In Headroom mode, points Claude Code at `http://127.0.0.1:8787`.
- In Headroom mode, updates `~/.headroom/deploy/default/manifest.json` so `/v1/messages` routes to Z.AI.
- Never prints the API key.

If you cannot use the script, edit `~/.claude/settings.json` manually.

Direct Z.AI:

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "your_zai_api_key",
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "1000000",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5.2[1m]",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-5.2[1m]"
  }
}
```

Headroom mode:

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "your_zai_api_key",
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:8787",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "1000000",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5.2[1m]",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-5.2[1m]"
  }
}
```

For Headroom, also make sure the persistent proxy starts with:

```text
ANTHROPIC_TARGET_API_URL=https://api.z.ai/api/anthropic
```

and proxy args include:

```text
--anthropic-api-url https://api.z.ai/api/anthropic
```

## Restart Headroom

After changing the Headroom manifest, restart the user service.

On this macOS machine, `headroom install restart` has been unreliable because its `launchctl kickstart -k` path can report failure or boot the service out. Prefer:

```bash
launchctl kickstart -k gui/$(id -u)/com.headroom.default
```

If that fails, reload the service:

```bash
launchctl bootout gui/$(id -u)/com.headroom.default 2>/dev/null
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.headroom.default.plist
```

Then check:

```bash
curl -sS http://127.0.0.1:8787/readyz
curl -sS http://127.0.0.1:8787/stats
```

Healthy output should show `status` or `ready` as healthy/true.

## Verify Without Leaking Secrets

Redacted config check:

```bash
node -e 'const fs=require("fs"), os=require("os"), h=os.homedir(); const s=JSON.parse(fs.readFileSync(h+"/.claude/settings.json","utf8")).env||{}; const mp=h+"/.headroom/deploy/default/manifest.json"; const m=fs.existsSync(mp)?JSON.parse(fs.readFileSync(mp,"utf8")):{}; for (const k of ["ANTHROPIC_BASE_URL","ANTHROPIC_AUTH_TOKEN","API_TIMEOUT_MS","CLAUDE_CODE_AUTO_COMPACT_WINDOW","ANTHROPIC_DEFAULT_HAIKU_MODEL","ANTHROPIC_DEFAULT_SONNET_MODEL","ANTHROPIC_DEFAULT_OPUS_MODEL"]) console.log(`${k}=${k.includes("TOKEN")?(s[k]?"<set>":"<missing>"):s[k]}`); console.log("ANTHROPIC_TARGET_API_URL="+((m.base_env||{}).ANTHROPIC_TARGET_API_URL||"<missing>"));'
```

MCP check:

```bash
claude mcp list
```

Expected Headroom line:

```text
headroom: headroom mcp serve - ✔ Connected
```

Other remote MCP servers may fail if network/auth is unavailable. Do not treat unrelated MCP failures as Headroom failures.

Interactive Claude Code check:

```bash
cd your-project
claude
/status
```

If prompted to use the API key, select yes. If prompted for file access, grant the project folder.

## Smoke Test Cautions

`claude -p "..."` can hang before it reaches Headroom because Claude Code may be doing startup, auth, plugin, or MCP initialization work. If Headroom `/stats` shows no `/v1/messages` request, the hang is before the proxy.

Use these checks to separate layers:

- `curl http://127.0.0.1:8787/readyz` fails: Headroom service problem.
- Headroom logs show `/v1/messages` reaching Z.AI and failing: upstream Z.AI/token/model problem.
- `claude -p` hangs and Headroom `/stats` has zero API requests: Claude Code startup or plugin problem.
- `/status` in interactive Claude Code works: prefer that as the functional verification.

Direct `curl` to `/v1/messages` is useful, but some sandboxed agent environments may block or behave differently from an interactive terminal. If a direct test fails, check `~/.headroom/logs/proxy.log` to confirm whether the request reached Headroom.

## Common Gotchas

- New terminal required: Claude Code reads env/settings at process start. Close all Claude Code windows and open a fresh terminal after changes.
- Settings merge: never replace the whole `~/.claude/settings.json`; preserve hooks, plugins, status line, and permissions settings.
- API key hygiene: avoid command lines that put keys in shell history. Prefer `read -s ZAI_API_KEY` and `export ZAI_API_KEY`.
- Direct Z.AI bypasses Headroom: if `ANTHROPIC_BASE_URL` is `https://api.z.ai/api/anthropic`, Claude Code is not using Headroom proxy compression.
- Headroom mode needs two URLs: Claude Code points to localhost; Headroom points to Z.AI via `ANTHROPIC_TARGET_API_URL` or `--anthropic-api-url`.
- GLM 1M suffix: use `glm-5.2[1m]` with `CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000`. If Claude Code says the `[1m]` model does not exist, upgrade Claude Code.
- Cost behavior: Z.AI docs describe GLM-5.2 and GLM-5-Turbo as premium models with peak/off-peak multipliers. Check current Z.AI pricing/docs before making cost claims.
- Version drift: Z.AI docs and Headroom options can change. Fetch `https://docs.z.ai/llms.txt` and run `headroom proxy --help` before major repairs.
- Headroom service status can be misleading: `headroom install status` may say stopped while `curl /readyz` is healthy. Trust the live endpoint and logs.
- Subscription tracking logs may still say Anthropic quota tracking because Headroom is emulating Anthropic-compatible traffic. That does not prove traffic is going to Anthropic.
- Remote MCP health checks can hang or fail for unrelated servers. Look specifically for the `headroom` MCP line.

## Useful Files

- Claude settings: `~/.claude/settings.json`
- Claude MCP registry: `~/.claude.json`
- Headroom manifest: `~/.headroom/deploy/default/manifest.json`
- Headroom runner log: `~/.headroom/deploy/default/runner.log`
- Headroom proxy log: `~/.headroom/logs/proxy.log`
- LaunchAgent: `~/Library/LaunchAgents/com.headroom.default.plist`

## Revert Paths

Switch Claude Code back to direct Z.AI:

```bash
cd ~/.claude/skills/headroom-zai-claude-code
node scripts/configure.js --mode direct
```

Fully remove Headroom wrapping only when the user explicitly asks:

```bash
headroom install remove
headroom unwrap claude
headroom unwrap codex
```

Do not run destructive cleanup or delete settings files unless the user explicitly approves it.
