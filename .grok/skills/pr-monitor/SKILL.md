---
name: pr-monitor
description: >-
  Monitor-only babysit for GitHub (and GitHub Enterprise) pull requests.
  Use when the user says "Monitor this PR", "watch this PR", or runs /pr-monitor.
  Do not use the bundled pr-babysit skill for these PRs — this skill reads
  pr-babysit and overlays a no-fix policy.
when-to-use: >-
  "Monitor this PR", "watch this PR", /pr-monitor, monitor-only CI babysit.
argument-hint: "add <number|url> | remove <number> | list | check"
---

# PR Monitor (monitor-only overlay)

Monitor-only babysit for GitHub PRs on any `gh`-authenticated host. Never invoke `/pr-babysit` — that skill fixes code. Read it as a reference, then apply the overrides below. Overrides win on conflict.

## Load pr-babysit

Resolve `$GROK_HOME` (`$GROK_HOME` if set, else `~/.grok`). Locate `pr-babysit` in this order; stop at the first hit:

1. Available-skills list in this session (bundled / user / repo / plugin).
2. `$GROK_HOME/bundled/skills/pr-babysit/SKILL.md`
3. `$GROK_HOME/skills/pr-babysit/SKILL.md`
4. `<repo>/.grok/skills/pr-babysit/SKILL.md`
5. `grok inspect --json` — any skill named `pr-babysit`; use its `source.path`.

If found: **read the full SKILL.md** with `read_file`. Use its add / remove / list / check-cycle shape, auth checks, `gh pr view` query, scheduler backing, and “never merge” rule.

If not found: continue with this file only. Do not fail.

Do not spawn pr-babysit worktree fix subagents. Do not write `~/.grok/plugin-data/pr-babysit/`.

## Overrides (win on conflict)

### Host, repo, state

Resolve **host** and **repo** per PR. Never hardcode them. Prefer, in order:

1. PR URL `https://<host>/<owner>/<repo>/pull/<n>` (or `http://`).
2. Existing per-PR state (`host`, `repo`).
3. Watchlist entry for that PR (`host`, `repo`).
4. `gh repo view --json nameWithOwner,url` in the current clone (host from the URL).
5. `GH_HOST` if already set in the environment.
6. Active host from `gh auth status`.

`github.com` is a valid host. Never prefix `gh` with `GH_HOST=` (or other env assignments). Pass the host on the command:

- Repo-scoped: `gh <cmd> --repo <host>/<owner>/<repo>`
- `gh api` / `gh api graphql`: `--hostname <host>`
- `gh auth status`: `--hostname <host>`

When host is `github.com` and `gh` already defaults there, omit `--hostname` and use `--repo <owner>/<repo>`.

- Watchlist: `~/.grok/plugin-data/pr-monitor/watchlist.json`
- Per-PR: `~/.grok/plugin-data/pr-monitor/<host>/<owner>/<repo>/pr-<n>.json`

Legacy fallback: if `~/.grok/plugin-data/pr-monitor/pr-<n>.json` exists, keep using it for that PR until it is removed.

`watchlist.json` shape (each PR carries its own host/repo):

```json
{
  "mode": "monitor-only",
  "prs": [
    {"number": 13328, "host": "<host>", "repo": "<owner>/<repo>"}
  ],
  "policy": {},
  "merged": [],
  "updated_at": "2026-08-18T00:00:00Z"
}
```

Legacy watchlists may have top-level `host` / `repo` and `prs: [<n>, ...]`. Treat each bare number as that host/repo. On the next write, migrate those entries to objects.

Copy `policy` from this skill into the watchlist and each per-PR file. Create directories and files if missing.

A bare “Monitor this PR \<url\>” is `add`. Parse host, owner, repo, and number from the URL. A bare number uses the resolved host/repo from steps 4–6.

### Forbidden actions

Do **not** fix code, push, reply to reviews, resolve conflicts, restack, or merge. Do not post “Automated fix” comments. The only write to GitHub is `gh run rerun` when the retrigger policy matches.

### Check cycle

One cycle per fire, then exit. Durable 5-minute scheduler re-fires. Scheduler prompt must contain `pr-monitor` (not `pr-babysit`).

For each PR in `watchlist.prs`:

1. `gh auth status --hostname <host>`. Stop on auth failure for that host.
2. `gh pr view <n> --repo <host>/<owner>/<repo> --json state,mergeable,mergeStateStatus,statusCheckRollup,reviewDecision,url,title,headRefName,headRefOid`
3. Fetch `isRequired` via GraphQL (see below).
4. Classify failed required checks from `gh run view <run_id> --repo <host>/<owner>/<repo> --log-failed`.
5. Apply retrigger policy. Persist the per-PR file and `watchlist.updated_at`.
6. Short status: what changed or needs attention.

**MERGED / CLOSED:** remove from `watchlist.prs`, append to `merged`, persist. If `prs` is empty, `scheduler_list` and delete any task whose prompt contains `pr-monitor`.

**All required green + MERGEABLE + APPROVED:** report merge-ready. Keep watching until merged.

**Pending required checks, no failed required:** `last_status=pending`. No action.

Ignore non-required failures (including the `Required builds` aggregate when `isRequired=false`).

### Required-check GraphQL

```
gh api graphql --hostname <host> -f owner="<owner>" -f name="<repo>" -F number=<n> -f query='
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      commits(last: 1) {
        nodes {
          commit {
            oid
            statusCheckRollup {
              state
              contexts(first: 50) {
                nodes {
                  ... on CheckRun {
                    name conclusion status
                    detailsUrl
                    isRequired(pullRequestNumber: $number)
                  }
                  ... on StatusContext {
                    context state
                    isRequired(pullRequestNumber: $number)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}'
```

Re-trigger only checks with `isRequired=true`. Never re-trigger non-required checks.

### Retrigger policy

Classify from failed-job logs:

| Class | Meaning | Action |
|---|---|---|
| **INFRA TIMEOUT** | Runner/job timeout, not a test assertion | `gh run rerun <run_id> --repo <host>/<owner>/<repo> --failed`. **No cap.** |
| **INFRA** | Flaky runner, OOM, queue, checkout, lost worker — not PR code | Same rerun. Max **2** per `run_id`. |
| **LATENCY** | Measured vs expected **ms** / latency threshold | Same rerun. Max **2** per `run_id`. After 2 still failing, stop and report persistent. |
| **CODE** | FileCheck, hash mismatch, SNR assert, compile, clang-tidy finding, test assertion | Report only. **No re-run.** |

Track counts in `pr-<N>.json` (`retrigger_count`, `retriggers[]`, `retrigger_by_run_id`). After a re-run, persist and mention it in the cycle status.

### Todos

Per watched PR (not the pr-babysit triple):

- `pr-<n>:monitor` — watch until merged/closed
- `pr-<n>:ci` — required CI; retrigger INFRA only
- `pr-<n>:ready` — notify when merge-ready or merged

### Scheduler prompt

Use this text (update the “Currently watching” line):

```
Monitor-only babysit. Follow the pr-monitor user skill.
Do not follow pr-babysit fix/push/review/conflict behavior.

Watchlist: ~/.grok/plugin-data/pr-monitor/watchlist.json
Per-PR host/repo are on each watchlist entry — pass host via `--repo <host>/<owner>/<repo>` and `--hostname` on `gh api`.

Currently watching: <host> <owner>/<repo>#<n> ...
```

`scheduler_create` with `interval=5m`, `durable=true`. Do not create a second loop if one whose prompt contains `pr-monitor` already exists.
