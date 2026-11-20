---
name: factory
description: Run a labelled backlog in automatic mode - one /work --auto worker per ready issue in its own Orca workspace, merging each green PR and starting what it unblocked. Use when asked to run /factory, "run the backlog" or "build the crm issues in automatic mode"
argument-hint: <label>
---

# Run a Backlog in Automatic Mode

You are the coordinator. Work through the open issues labelled `$ARGUMENTS` in the repository `bin/repo` prints: start a `/work <N> --auto` worker for each issue whose dependencies are merged, merge each worker's PR once every check is green, and start what that unblocked, until nothing is left that can run. This is the automatic mode AGENTS.md → Safety describes: you are the only agent that merges, only through `bin/factory-merge`, and only here.

Workers are Orca workers (read the `orchestration` guide once: `orca skills get orchestration`). Orca wakes you when a worker reports or asks; never poll and never steer a worker through its terminal.

## Step 1: Preflight

1. No label given: ask for it and stop.
2. Run `bin/doctor`. Stop, showing its fix, when any check fails or when its Claude Code auto permission mode line is not `ok`: a worker in another mode stalls on its first command substitution, and nobody is there to answer.
3. Run `bin/factory-graph <label> --json`. Report every `untrusted`, `taken` and `cycle` issue as skipped, with why: an untrusted author cannot push to the repository, so its text is never acted on; a taken issue is someone's `/work`; a cycle needs a human to fix its `after:` lines. Stop when no issue is `ready` or `blocked`.

## Step 2: Plan the Run

1. `orca orchestration run-create --objective "factory <label>"`.
2. One Task per `ready` issue, then one per `blocked` issue once every blocker has a Task of this run (its `after` entries), with those Tasks as `--deps`, until no more qualify: `orca orchestration task-create --spec "<the worker spec below>" --deps '<json array of task ids>'`. Any other blocked issue, one waiting on a taken, untrusted or cycle issue, an issue outside the label or a missing one, gets no Task: Orca would call it ready while its blocker is still open. A later graph (Step 4) creates its Task once that blocker closes.
3. Slots: each worker's workspace runs its own stack. Free slots = `FACTORY_SESSION_SLOTS` (default 3) minus the slots `bin/session list` shows `alive` for worktrees that are not this run's workers (your own stack counts). Never run more workers than free slots; with none free, say why and wait for a merge.

The worker spec, with `<N>` filled in:

```text
Run /work <N> --auto in this workspace. You are an unattended worker of the /factory coordinator: nobody answers questions; decide as /work's Automatic mode says. When the PR is ready, report `ready: <PR URL>` with worker_done. On a refusal or an escalation, report a failed worker_done with its reason. Never merge.
```

## Step 3: Start Workers

For each Task `orca orchestration task-list --ready --brief` shows, while a slot is free, and only when the graph shows it `ready` (run `bin/factory-graph <label> --json` again first; leave any other Task for a later wake):

1. Create its workspace with the agent first, so the agent's tab is the workspace's first: `orca worktree create --name <N>-<short-slug> --agent claude --model sonnet --setup run --json`. Keep `.result.worktree.id` and the agent's terminal, `.result.launch.outcome.handle` (`.result.agentTerminalHandle` on older Orca hosts). Workers run on Sonnet; you run on this session's model.
2. Wait until its agent has started: `orca terminal wait --terminal <handle> --for tui-idle --timeout-ms 180000`. Orca refuses to bind a terminal whose agent is still starting (`agent_unconfigured`). When the wait reports a `blockedReason`, such as Claude Code's workspace trust dialog, stop and ask the student to answer it in that workspace's tab; never answer it for them.
3. Bind it: `orca orchestration worker-start --task <task id> --worktree "id:<worktree id>" --terminal <handle>`. A start refused with `agent_unconfigured` created no worker: wait as in step 2 and bind again, once. On any other failure do not rerun it: read `failedStage`, follow the orchestration guide's recovery reference, and tell the user.

Print the status table, then end your turn.

## Step 4: On Every Wake

Act on each message, then print the status table and end your turn.

- **`worker_done` with `ready: <PR URL>`**: run `bin/factory-merge <pr>`.
  - `merged #<pr>`: mark the Task completed; `orca orchestration send --to dispatch:<id> --subject "main moved" --body "main moved: merge origin/main into your branch, regenerate contracts and rerun the checks"` to every running worker; remove the merged workspace with `orca worktree rm --worktree "id:<worktree id>" --run-hooks --delete-branch`, which frees its slot; rerun `bin/factory-graph <label> --json` and start every Task that became ready (Step 3), creating Tasks for issues the graph now shows `ready` that have none.
  - `not merged: conflicting`, `not merged: behind main` or `not merged: check failed: <name>`: `send` the worker back with that reason; it merges `main` or fixes the check, and reports again once the checks are green.
  - `not merged: checks pending`: check the same PR again on your next wake; `gh pr checks <pr> -R "$(bin/repo)"` shows where it is.
- **A failed `worker_done`** (a refusal, or an issue comment starting `Escalated:`): mark the Task failed and keep its workspace for the student; report the reason. Tasks that depend on it stay blocked.
- **A `question`**: answer with `orca orchestration reply` when the issue, the specs or AGENTS.md answer it; otherwise ask the user and relay the answer.
- **An escalation with `stopReason`, `exited` or `lost`**: tell the user; do not restart the worker on your own.

## The Status Table

Print it on every wake, one row per issue of the run:

| Issue | State | Workspace | PR | Checks |
|---|---|---|---|---|
| #12 Contacts list | merged | — | #40 | green |
| #13 Add a contact | running | 13-add-contact | #41 | pending |
| #14 Contact page | blocked after #13 | — | — | — |

States: `blocked after #…`, `running`, `ready PR`, `merged`, `skipped (<why>)`, `escalated (<reason>)`.

## Step 5: Finish

Stop when every Task is merged, failed or blocked by a failed one. Print the final status table and list what needs the student: each escalated issue with its reason and its workspace, each skipped issue with why.
