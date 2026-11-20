# Engineering principles

This repository is developed agent-native: AI agents write, test and ship the
code, many of them in parallel; humans set direction, approve designs and merge.
These principles say **why** we work the way we do and change rarely.
`AGENTS.md` turns them into concrete rules and commands and changes often. When
the two disagree, fix `AGENTS.md`.

## A. How work flows

1. **Agent-native, human-gated.** Agents do the work. A human approves at four
   gates: the issue breakdown, the design, the plan, and the merge. Every other
   step must be runnable by an agent from the command line, unattended. In
   automatic mode the `/factory` coordinator and its workers stand in for the
   human at every gate; the mechanical checks never relax.
2. **Everything starts with an issue.** No code without a GitHub issue. An issue
   breaks into OpenSpec changes, all on one branch and in one PR; a change too
   big for one review becomes two. The issue number and change hash appear in the branch
   name, every commit and the PR title, so any line of code traces back to why
   it exists.
3. **Specs are the source of truth for behavior.** Read the capability's spec
   before changing its behavior. The spec delta is part of the change and is
   archived into the living spec in the PR's last commit.

## B. How the system is built

4. **Services are isolated.** Each service owns its dependencies, lockfile,
   config and Dockerfile. No code is shared between services.
5. **Contracts are the only coupling.** Every service boundary has a committed,
   machine-readable contract: GraphQL SDL, OpenAPI, or JSON Schema for jobs and
   events. Consumers generate their types from it. CI fails when a contract is
   stale or a consumer no longer type-checks against it.
6. **Services look the same from outside.** Same script names, same coverage
   gate, same Dockerfile layout, and a `services/<name>/AGENTS.md` in each. An
   agent that knows one service knows how to operate all of them.
7. **TypeScript on Bun, strict.** Bun does not type-check, so `tsc --noEmit` in
   strict mode is its own gate. Another language needs a written justification.
8. **Generated files are never edited by hand.** Contracts, clients and vendored
   skills are changed at their source and regenerated.
9. **Tools are pinned.** Repository CLIs run through pinned `bin/` wrappers.
   Each service declares its exact runtime version in its package configuration
   and runs commands inside its service container; Docker pins the same version.

## C. How work is proven

10. **Untested is unfinished.** Unit, integration and end-to-end tests, and 100%
    line and function coverage per service. Every coverage exclusion carries an
    inline reason, which a reviewer can see and challenge.
11. **Coverage is necessary, not sufficient.** Tests assert behavior: no
    assertion-free tests, no snapshot-only tests of logic.
12. **Tests come first.** Write the failing test, then the code. Tests written
    after the code describe the code instead of the spec.
13. **Tests are hermetic and deterministic.** Unit and integration tests never
    reach the real network or third-party APIs: external providers are faked at
    their contract. Time, randomness and seeds are fixed. A flaky test is a P1
    bug — fix it or quarantine it immediately, because agents waste hours
    chasing flakes and learn to ignore red builds.
14. **Specs are traceable to tests.** Every spec scenario has a stable ID. Every
    end-to-end test is tagged with the scenarios it covers, and CI fails when a
    scenario is neither covered nor explicitly marked out of scope with a reason.
15. **The agent proves its work on the running system.** Green tests are not
    the finish line. Before claiming done, the agent brings up its own stack and
    uses the change for real — in a browser for anything a user sees, with real
    requests for APIs and workers — and attaches screenshots or a recording to
    the PR.
16. **Review is layered.** Green CI and an independent agent review first,
    then human approval. A fresh agent, not the one that wrote the code,
    reviews every pull request before it opens, and the pull request lists
    what it found and what happened to each finding. Only a human merges,
    except in automatic mode, where the `/factory` coordinator merges a pull
    request once every check is green and nobody is asked along the way.

## D. How environments work

17. **One command up, one command down.** `bin/up` brings a fresh checkout to a
    running, seeded stack and prints its URLs; `bin/down` removes all of it. No
    manual steps in between.
18. **Many stacks side by side.** Each worktree gets its own slot: its own
    Compose project, port range, databases and data. Several versions of the
    system run on one machine without interfering. The slot count is set by
    measured memory, not by port arithmetic.
19. **No secrets in the repository.** `bin/setup` generates a local `.env`
    with random development values; only `.env.example`, which names the
    variables, is committed.
20. **Agents get the least privilege that works.** Agents never push to
    `main`; the pre-push hook refuses it, and branch protection, where enabled,
    makes that a fact, not a request.

## E. How changes are guarded

21. **Every change is reversible.** Migrations only expand (expand, then
    contract in a later change), so any version of the code runs against the
    database of the next.
22. **CI enforces; hooks assist.** Every rule that matters is a required CI
    check. Local git hooks only save a round trip.
23. **Supply chain is guarded.** CI scans for secrets and audits dependencies.
    A new dependency is justified in the change's design — agents can invent
    package names, and attackers register them.

## F. How agents stay effective

24. **Encode, don't exhort.** When an agent needs the same correction twice,
    the fix becomes a lint rule, test, type or CI check. A line in `AGENTS.md`
    is the fallback when nothing mechanical can enforce it.
25. **Failures point to the fix.** Error messages, check output and scripts say
    what went wrong and what to do next. `bin/logs <service>` reaches any
    session's logs.
26. **Context is a budget.** Small files, focused modules, short root docs, and
    detail loaded on demand through per-service `AGENTS.md` files and skills.
    The repository is the only memory: decisions live in each change's
    `design.md`, not in chat history.
27. **A change fits one agent session.** If a change cannot be built and
    verified in one session, split it.
28. **Boring, popular technology.** Agents are most reliable with tools that
    are well represented in their training data. Prefer the mainstream option.
