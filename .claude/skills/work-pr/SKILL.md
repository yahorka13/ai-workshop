---
name: work-pr
description: Archive the issue's OpenSpec changes, push, open a draft PR, drive it through CI, and hand it to a human
argument-hint: <issue_number> [--auto]
---

# Ship a Pull Request

Verify and archive the issue's OpenSpec changes (if there are any), have the branch reviewed by a fresh agent, commit, push, open a draft pull request, drive it through CI, and hand it to a human for merge.

With `--auto` (automatic mode, from `/work <N> --auto`), nobody is asked: where a step says to ask the user, decide and record it in the PR's `## Review` section, or escalate (Step 7). The run ends at a ready PR (Step 9) and never merges it; the `/factory` coordinator merges.

## Step 1: Determine Issue and Change

Run `git branch --show-current`.

- **Change branch** (`<issue>-<6-hex>-<slug>`, e.g. `12-a3f9c1-session-slots`): the issue is the number, the hash is the second segment, and the branch is named after the issue's first change. Commit prefix: `[<issue>][<hash>]`.
- **Plain issue branch** (`<issue>-<slug>`): no change. Commit prefix: `[<issue>]`. Skip Step 3; Step 4 still runs.
- Otherwise use `$ARGUMENTS` as the issue number, or ask.

A change branch carries every change of its issue: the one it is named after and any later ones created on it, each an `openspec/changes/<issue>-*` folder with its own hash. List them with `ls -d openspec/changes/<issue>-*`. A commit that belongs to a later change takes that change's hash: `[<issue>][<its hash>]`.

## Step 2: Stage and Commit

First run the full `bin/e2e` locally, not `bin/e2e --changed`: it must pass. Fix what fails with a test-first fix before going on.

1. Run `git status` and `git diff` to review the changes.
2. Stage all relevant changes. Never stage secrets; generated contracts and clients are committed with their source.
3. Commit with the prefix from Step 1, using a HEREDOC. If changes span multiple logical units, create multiple commits, each with the prefix.

```bash
git commit -m "$(cat <<'EOF'
[12][a3f9c1] api: Reject expired tokens
EOF
)"
```

## Step 3: Archive the Changes

Only on a change branch. Archive every active `openspec/changes/<issue>-*` change, one archive commit per change, in the order of the issue's breakdown comment (a later change's deltas build on the earlier ones'); together they are the PR's last commits, so each change's deltas merge into the living spec in the same PR as its code. For each change `<change-id>` with hash `<hash>`:

1. Run `/opsx:verify <change-id>` (verify reads active changes only, so it runs before archiving it). Fix every CRITICAL issue test-first, then run it again until none is left. Keep its WARNING and SUGGESTION issues for the PR's `## Review` section (Step 6), each fixed or deferred with a reason.
2. `bin/openspec validate <change-id> --strict` — fix any errors.
3. Confirm every checkbox in `openspec/changes/<change-id>/tasks.md` is ticked. For each one that is not, ask the user whether it is done, dropped or blocking: tick a done task; write a dropped one as `- [x] N.M Dropped: <reason>. <task>`; stop on a blocking one.
4. `bin/openspec-archive <change-id>` — refuses while a task is unchecked or dropped without a reason; otherwise merges the deltas into `openspec/specs/` and moves the change to `openspec/changes/archive/YYYY-MM-DD-<change-id>/`.
5. Commit: `[<issue>][<hash>] Archive <change-id>`.

Then `bin/openspec validate --all --strict` — the living spec must still be valid —, `bin/openspec validate --archived` — no archived change has an unchecked task — and `bin/check-spec-coverage.sh` — every scenario is now cited by an end-to-end test or excluded. `bin/openspec-check-archived.sh <branch>` passes only once no change of the issue is active.

If more code commits are needed after archiving (review fixes), they go on top; the archives stay in place. If a review changes behaviour, edit the archived delta and the living spec together in the fix commit.

## Step 4: Review the Branch

A fresh agent, not the one that implemented the issue, reviews the whole branch once, after archiving and before the draft PR, on every branch: change branches and plain issue branches alike.

1. Run `git fetch origin main`, and merge `main` into the branch when it moved. Then use `superpowers:requesting-code-review` on `origin/main..HEAD`, with `git merge-base origin/main HEAD` as the base. Dispatch the reviewer on the most capable model the agent offers, named explicitly, never a smaller one than the implementer's.
2. Give the reviewer the range, the archived `design.md` and delta specs of every change of the issue, and AGENTS.md, and ask it to look for correctness and security bugs, gaps between the specs and the code, and rule violations no check catches. Give it the issue, not the implementer's conclusions: no summary of what you think works, no session history.
3. An agent that cannot dispatch a subagent starts a fresh non-interactive session of its own agent CLI from the shell instead, read-only, with the same reviewer prompt, and reads its findings from the output. When no such session can be started, stop and ask the human to run the review.
4. The reviewer's severity is advice: grade each finding by what it does to someone using the change. Then every Critical and Important finding is fixed test-first, in commits on top of the archives, before the draft PR opens: a failing test that reproduces it, then the fix, then the full suite. A finding that only questions an approved design, and is no correctness or security bug, is deferred with that reason rather than reworked. If a fix changes behaviour, edit the archived delta and the living spec together (Step 3). The fixes are not reviewed again.
5. Keep every finding with its outcome, fixed or deferred with a reason, for the PR's `## Review` section (Step 6).

## Step 5: Push

When `main` moved since the branch last took it, keep the branch current first: `git fetch origin && git merge origin/main`, then `bin/contracts generate` when a contract or its source changed, `bin/check` and `bin/e2e --changed`, and commit the merge. Never rebase or force-push.

```bash
git push
```

If the branch has no upstream, use `git push -u origin <branch_name>`. Never force-push; when `main` moves, merge it into the branch.

## Step 6: Create Draft Pull Request

1. Fetch the issue title via `gh issue view <issue> -R "$(bin/repo)"`.
2. Write the PR body to a temporary file (to avoid shell escaping issues):

The PR body must be pure markdown with the following structure:

```markdown
## Summary

<2-3 sentences describing what this PR does and why>

Closes #<ISSUE_NUMBER>
Change: `<change-id>`           ← change branches only: one line per change, every change ID of the issue

## Changes

### <Service Name> (only if multi-service changes)
- Change description 1
- Change description 2

### Specs (change branches only)
- <capability>: <requirements added / modified / removed>

## Proof

<screenshots, recording, or request/response excerpts from the running stack>

## Review

- <finding> — fixed in <commit>, or deferred: <reason>
```

For `## Proof`, run `bin/proof-markdown HEAD` after pushing: it prints the screenshots (and any videos) committed under the changes' `proof/` folders as permalinks that survive archiving. Add request/response excerpts or command output below it. A ready PR that changes `services/ui/src/` fails the `ui-proof` check until `## Proof` shows an image or a video; editing the description reruns the check.

For `## Review`, list every finding of the branch review (Step 4) and every WARNING or SUGGESTION of `/opsx:verify` (Step 3), one line each, with its outcome: fixed, or deferred with a reason. When there are none, write `No findings.` A ready PR without the section fails the `review-section` check; editing the description reruns it.

The body is plain markdown: no shell constructs. The Summary explains the "why", the Changes explain the "what".

3. Create the PR. The title uses the branch's prefix, the first change's hash:

```bash
gh pr create --draft -R "$(bin/repo)" --head "$(git branch --show-current)" --title "[<ISSUE>][<HASH>] <COMPREHENSIVE_MESSAGE>" --body-file <temp_file>
```

On a plain issue branch the title is `[<ISSUE>] <COMPREHENSIVE_MESSAGE>`. The `pr-body` check reads the title and body of the draft too, and names every rule they break; editing the description reruns it.

4. Clean up the temporary file.

## Step 7: Drive CI to Green

1. `gh pr checks "$(git branch --show-current)" --watch -R "$(bin/repo)"` until every check finishes. No checks reported (`no checks reported on the ... branch`) means no CI workflow covers this change yet: say so in the hand-over and continue to Step 8.
2. When the run fails, read the log of every failed job, not only the first (`gh run view <run-id> --log-failed -R "$(bin/repo)"`), and fix each cause with a test-first fix. Then re-run each failed job's own command locally: its `run:` lines in `.github/workflows/checks.yml`, or the failing step's command for `repo-checks`. Commit with the same prefix and push only once they pass, then watch again. Pushing while a run is still in progress is fine: the newer push cancels the stale run. A job whose command cannot run on this machine is pushed on the evidence you have and named in the hand-over.
3. In automatic mode, when the same check still fails after three fix pushes, or a merge of `main` conflicts in a way you cannot resolve with both sides' tests green, stop: post an issue comment starting `Escalated:` with what failed and what you tried, and report it (Step 9).
4. Loosening a check to get green is forbidden (AGENTS.md → "Definition of done"). If a failure is unrelated to this change, or fixing it means rewriting pushed commits, stop and tell the user.

## Step 8: Mark Ready

Mark the PR ready: `gh pr ready "$(git branch --show-current)" -R "$(bin/repo)"`. Checks that skip drafts (the archive check, `review-section`, `ui-proof`) run now: wait a few seconds for GitHub to start them, then watch every check to completion with `gh pr checks "$(git branch --show-current)" --watch -R "$(bin/repo)"`, and drive any failure back through Step 7. Hand over only once they are all green; in automatic mode, the coordinator merges as soon as you report.

## Step 9: Hand Over

1. Display the PR URL.
2. Run `git log --oneline -5` to show the final commit state.
3. Tell the user the PR is ready for their review and merge. Never merge it yourself.

In automatic mode, end with `ready: <PR URL>` instead of step 3: an Orca worker reports it through `worker_done` with the PR number and URL, and an escalation as a failed `worker_done` with its reason. The worker never merges, not even through `bin/factory-merge`; the coordinator does.
