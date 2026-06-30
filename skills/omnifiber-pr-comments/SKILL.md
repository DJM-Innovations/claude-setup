---
name: omnifiber-pr-comments
description: Post or clean up review comments on gitlab.omnifiber.org merge requests as inline (line-anchored) discussions under the user's identity. Use when asked to leave comments, post a review, or annotate findings on an Omnifiber MR.
argument-hint: "<MR url or project-id + MR-iid>"
allowed-tools: Bash, Read, Write, Edit
---

# Omnifiber MR Review Comments

End-to-end workflow for posting line-anchored review comments on a GitLab merge request at `gitlab.omnifiber.org`, under the user's real identity (not a bot).

Always read `~/.claude/rules/omnifiber-pr-comments.md` alongside this skill — that rule governs identity checks, comment style, and cleanup. This skill is the operational how-to.

## Inputs

- **MR identifier**: either a full URL like `https://gitlab.omnifiber.org/<group>/<project>/-/merge_requests/<iid>/diffs`, or `<project_id> <mr_iid>` directly.
- **Personal access token**: from the user's own profile at `https://gitlab.omnifiber.org/-/user_settings/personal_access_tokens` with `api` scope. Group/project access tokens will attribute comments to a bot — refuse to use them per the rule.

## Workflow

### Step 1 — Resolve project ID and MR iid

If user gives the URL, extract:
- `path_with_namespace` from the URL (everything between `gitlab.omnifiber.org/` and `/-/merge_requests/`)
- `iid` from the path segment after `/merge_requests/`

Then look up project ID:
```bash
PATH_ENC=$(python3 -c "import urllib.parse;print(urllib.parse.quote('GROUP/PROJ', safe=''))")
curl -s -H "PRIVATE-TOKEN: $TOKEN" \
  "https://gitlab.omnifiber.org/api/v4/projects/$PATH_ENC" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])'
```

### Step 2 — Verify token identity (NON-NEGOTIABLE)

```bash
curl -s -H "PRIVATE-TOKEN: $TOKEN" \
  "https://gitlab.omnifiber.org/api/v4/user" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["username"], d["name"])'
```

If username contains `_bot_` or starts with `group_` / `project_`, abort and ask for a personal token.

### Step 3 — Fetch MR diff refs and changed files

```bash
curl -s -H "PRIVATE-TOKEN: $TOKEN" \
  "https://gitlab.omnifiber.org/api/v4/projects/$PROJ/merge_requests/$IID" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin)["diff_refs"];print(d["base_sha"],d["head_sha"],d["start_sha"])'

curl -s -H "PRIVATE-TOKEN: $TOKEN" \
  "https://gitlab.omnifiber.org/api/v4/projects/$PROJ/merge_requests/$IID/changes" > /tmp/mr_changes.json
```

### Step 4 — Identify exact line numbers in HEAD files

For each file you want to comment on, fetch the raw content **at the MR's source branch** to determine line numbers:

```bash
PATH_ENC=$(python3 -c "import urllib.parse;print(urllib.parse.quote('src/foo.py', safe=''))")
curl -s -H "PRIVATE-TOKEN: $TOKEN" \
  "https://gitlab.omnifiber.org/api/v4/projects/$PROJ/repository/files/$PATH_ENC/raw?ref=$SOURCE_BRANCH" \
  > /tmp/mr_file.py
grep -n "pattern" /tmp/mr_file.py
```

The line numbers here are the `new_line` values you'll pass to the position object.

### Step 5 — Read the diff carefully and form findings

Before writing comments, read each changed file end-to-end. Look ONLY for blocking findings (the rule `omnifiber-pr-comments.md` section 2a defines what counts):

- **Crashes / wrong results with realistic input** — SQL injection on data the system actually parses, NullPointerException paths exercised by normal input, broken proc name, wrong parameter binding.
- **Build / install breakers** — stdlib modules in `requirements.txt`, missing imports, wrong driver suffix that needs system deps.
- **Data corruption** — unclosed connections in long jobs, swallowed exceptions that silently drop rows, transactions that never commit.
- **Real security exploits** — paths an attacker can actually trigger.

**Do NOT post non-blocking findings.** No style/idiomatic nits, no future-proofing for hypothetical schema changes, no "worth documenting", no validation gaps for inputs the system never sees, no hardcoded constants the operator owns. Summarize those in the chat reply to the user instead — let them decide whether to file a follow-up.

**Heuristic check per finding:** "If this stays in production for six months, what would actually break?" If "nothing realistic" — skip it.

**Pre-flight count check:** if you're about to post more than ~5 comments on a typical MR, re-read the blocking criteria and prune. A 20-comment review usually means you wrote 15 nits and 5 real findings.

Each blocking finding → one sentence. One sentence → one comment. Do not stack findings.

### Step 6 — Post comments

Use a small Python script (matches what worked previously). Template:

```python
#!/usr/bin/env python3
import json, urllib.parse, urllib.request

TOKEN = "<personal token>"
BASE = "https://gitlab.omnifiber.org/api/v4"
PROJECT_ID = <int>
MR_IID = <int>
BASE_SHA = "<from step 3>"
HEAD_SHA = "<from step 3>"
START_SHA = "<from step 3>"

COMMENTS = [
    # (new_path, new_line, one-sentence body)
    ("src/foo.py", 42, "Short, direct comment ending here."),
    # ...
]

def post(payload):
    data = urllib.parse.urlencode(payload).encode()
    url = f"{BASE}/projects/{PROJECT_ID}/merge_requests/{MR_IID}/discussions"
    req = urllib.request.Request(
        url, data=data, method="POST",
        headers={"PRIVATE-TOKEN": TOKEN, "Content-Type": "application/x-www-form-urlencoded"},
    )
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        return {"error": e.read().decode()}

ok = err = 0
for path, line, body in COMMENTS:
    resp = post({
        "body": body,
        "position[base_sha]": BASE_SHA,
        "position[head_sha]": HEAD_SHA,
        "position[start_sha]": START_SHA,
        "position[position_type]": "text",
        "position[new_path]": path,
        "position[new_line]": str(line),
    })
    if "id" in resp:
        ok += 1; print(f"OK  {path}:{line}")
    else:
        err += 1; print(f"ERR {path}:{line} -- {resp}")
print(f"\nposted={ok} failed={err}")
```

### Step 7 — Confirm to user

Report:
- Number posted, number failed
- Which file:line each finding hit
- A reminder to revoke the personal token when done

## Cleanup mode

If asked to delete previously-posted comments (e.g. attribution mistake):

```python
import json, urllib.request
TOKEN = "<token>"
BASE = "https://gitlab.omnifiber.org/api/v4"
PROJ, IID = <int>, <int>
TARGET_USER_ID = <int>  # The user_id whose comments to delete

def api(method, path):
    req = urllib.request.Request(f"{BASE}{path}", method=method,
                                  headers={"PRIVATE-TOKEN": TOKEN})
    with urllib.request.urlopen(req) as r:
        body = r.read()
        return json.loads(body) if body else None

discussions = []
page = 1
while True:
    chunk = api("GET", f"/projects/{PROJ}/merge_requests/{IID}/discussions?per_page=100&page={page}")
    if not chunk: break
    discussions.extend(chunk)
    if len(chunk) < 100: break
    page += 1

deleted = 0
for d in discussions:
    for note in d.get("notes", []):
        if note.get("author", {}).get("id") == TARGET_USER_ID and not note.get("system"):
            api("DELETE", f"/projects/{PROJ}/merge_requests/{IID}/notes/{note['id']}")
            deleted += 1
print(f"deleted={deleted}")
```

## Gotchas

- **Group/project access tokens look like personal tokens** (both start with `glpat-`). The difference is only visible in `GET /user`. Always check.
- **MR diff `new_line` is the line number in the HEAD version of the file**, not a position in the diff hunk. Use the raw file at the source branch to count.
- **Personal tokens can have long expiries by accident.** Recommend 1 day for one-off reviews.
- **GitLab masking rules reject most passwords** (special chars, short length). For comment posting we never put the token in a CI variable, so this doesn't apply — just don't try to set the same value as a masked CI var elsewhere.
- **Comments anchored to lines in deleted hunks need `old_line` + `old_path`** instead of new_line/new_path. Most reviews are on added/changed lines so this rarely comes up.
