# repo-rules Specification

## Purpose
The rules every commit, push and pull request in the repository follows, and the hooks and checks that enforce them: commit subjects, file hygiene, pull request titles and bodies, protected branches and the counts of suppressions that only go down.

## Requirements

### Requirement: Commit subject prefix matches the branch
A commit subject SHALL start with the prefix its branch dictates: `[N][hash] ` on a change branch `<N>-<hash>-<slug>`, `[N] ` on an issue branch `<N>-<slug>`, and one of `[N] `, `[N][hash] ` or `[HOTFIX] ` on any other branch, a failing subject being reported with the expected prefix.

#### Scenario: [repo-rules-c8d469] Change branch accepts its issue and hash
- **WHEN** the branch is `1-a38e64-git-hooks` and the subject is `[1][a38e64] Add hooks`
- **THEN** the subject check passes

#### Scenario: [repo-rules-8e90f9] Change branch rejects a wrong or missing hash
- **WHEN** the branch is `1-a38e64-git-hooks` and the subject is `[1] Add hooks` or `[1][bbbbbb] Add hooks`
- **THEN** the subject check fails and names the expected prefix `[1][a38e64] `

#### Scenario: [repo-rules-b32b92] Issue branch requires its issue number
- **WHEN** the branch is `12-fix-typo` and the subject is `[13] Fix typo`
- **THEN** the subject check fails and names the expected prefix `[12] `

#### Scenario: [repo-rules-2f8e68] Other branches accept any valid prefix
- **WHEN** the branch is `hotfix-login` and the subject is `[HOTFIX] Fix login`, `[7] Fix login` or `[7][a1b2c3] Fix login`
- **THEN** the subject check passes

#### Scenario: [repo-rules-6d5b27] Unprefixed subject is rejected
- **WHEN** the branch is `hotfix-login` and the subject is `Fix login` or `12: Fix login`
- **THEN** the subject check fails

### Requirement: Fixup commits are allowed locally only
Subjects starting with `fixup!`, `squash!` or `amend!` SHALL be rejected by CI and accepted by the local commit-msg hook.

#### Scenario: [repo-rules-777ce1] CI rejects fixup commits
- **WHEN** a PR's commit range contains a commit with subject `fixup! [1][a38e64] Add hooks`
- **THEN** the `commit-subjects` step of `repo-checks` fails

#### Scenario: [repo-rules-7c7601] Local hook accepts fixup commits
- **WHEN** a contributor runs `git commit --fixup <sha>` with hooks installed
- **THEN** the commit is created

### Requirement: Every commit in a PR is checked
The commit-range check SHALL validate every non-merge commit on the first-parent chain between the PR base and head, report every failing subject, and fail if any subject fails, leaving unchecked the commits that a merge brings in through its second parent, such as an imported subtree's history.

#### Scenario: [repo-rules-78f6f8] One bad commit fails the range
- **WHEN** a range holds three commits and only the second has a malformed subject
- **THEN** the range check fails and names that commit's short SHA and subject

#### Scenario: [repo-rules-43b88d] Merge commits are skipped
- **WHEN** a range contains a merge commit with subject `Merge branch 'main'` and otherwise valid commits
- **THEN** the range check passes

#### Scenario: [repo-rules-4a1a86] Merged-in history is not checked
- **WHEN** a range contains a merge whose second parent brings in commits with subjects that break the rules, and every first-parent commit is valid
- **THEN** the range check passes and counts only the first-parent commits

### Requirement: Text files end with a newline
The newline check SHALL fail for every non-empty text file whose last byte is not a newline, skipping empty files, binary files and paths that no longer exist.

#### Scenario: [repo-rules-ec4393] Missing final newline is rejected
- **WHEN** a checked file's content is `hello` with no trailing newline
- **THEN** the newline check fails and names the file

#### Scenario: [repo-rules-82eeee] Well-formed, empty, binary and deleted files pass
- **WHEN** the checked files are one ending in a newline, an empty file, a binary file and a deleted path
- **THEN** the newline check passes

### Requirement: Local hooks assist at commit time
After `bin/setup-git-hooks.sh` runs, every worktree of the clone SHALL use the repository hooks: they prepend the branch's prefix to new commit messages, reject malformed subjects, add a missing final newline to fully staged text files in the same commit, and reject a staged text file still missing one.

#### Scenario: [repo-rules-6b931f] Setup installs hooks idempotently
- **WHEN** `bin/setup-git-hooks.sh` runs twice
- **THEN** both runs exit 0 and `git config core.hooksPath` is `.githooks`

#### Scenario: [repo-rules-126d5f] Prefix is added from the branch
- **WHEN** a contributor on branch `1-a38e64-git-hooks` commits with message `Add hooks`
- **THEN** the commit subject is `[1][a38e64] Add hooks`
- **AND** on branch `12-fix-typo` the message `Fix typo` becomes `[12] Fix typo`

#### Scenario: [repo-rules-b22c7d] Existing prefixes and amends are left alone
- **WHEN** the message already starts with `[`, or the commit is a merge or an amend
- **THEN** the message is not changed

#### Scenario: [repo-rules-46cbe1] Malformed subject is rejected at commit time
- **WHEN** a contributor on branch `feature-x` commits with message `fix stuff`
- **THEN** the commit is refused with the subject error

#### Scenario: [repo-rules-b54e71] Staged file without final newline is rejected
- **WHEN** a staged text file lacks a final newline, even if the working copy has one
- **THEN** the commit is refused and the file is named

#### Scenario: [repo-rules-b9098e] A missing final newline is fixed in the same commit
- **WHEN** a fully staged text file lacks a final newline and the contributor commits
- **THEN** the hook adds the newline, stages it and names the file, and the commit holds the fixed file
- **AND** nothing is left unstaged, so the next push sends the fixed file
- **AND** text files that already end with a newline are not changed

#### Scenario: [repo-rules-fd2681] Binary and partially staged files are not completed
- **WHEN** the staged files include a binary file, or a text file whose staged content differs from its working copy
- **THEN** the binary file is committed unchanged and the partially staged file is rejected rather than completed

### Requirement: A merged sibling change keeps its attribution
A commit subject on a change branch SHALL also be accepted when it carries the
hash of another change of the same issue that exists in `openspec/changes` or
its archive, while a hash that no change of that issue has, or one belonging
to another issue, is still rejected.

#### Scenario: [repo-rules-b507a6] A branch that merged a sibling change
- **WHEN** a commit on a change branch carries the hash of another change of the same issue, and that change exists in `openspec/changes` or its archive
- **THEN** the subject check passes, so merged commits keep their own attribution
- **AND** a hash no change of that issue has, or one belonging to another issue, is still rejected

### Requirement: AGENTS.md forbids force-push
`AGENTS.md` SHALL forbid agents from force-pushing any branch and from ever pushing `main`.

#### Scenario: [repo-rules-e81bfb] AGENTS.md forbids force-push and drops gh stack
- **WHEN** `AGENTS.md` is read
- **THEN** its Safety rules say never to force-push and never to push to `main`, and no line of it mentions `gh stack`

### Requirement: Lint suppressions never grow
CI SHALL fail when a count of a service's `eslint-disable` and `@ts-expect-error` comments in tracked source, tests and tooling, excluding generated code, differs from the committed baseline. A rise fails naming the new comments; a fall fails until the lower number is committed.

#### Scenario: [repo-rules-64c670] A new suppression fails CI
- **WHEN** a pull request adds an `eslint-disable` or `@ts-expect-error` comment to a service without raising its baseline
- **THEN** the `lint-disables` step of `repo-checks` fails, naming the service, its count and baseline, and each comment's file and line
- **AND** the step passes once the baseline is raised in the same pull request

#### Scenario: [repo-rules-c50a83] A removed suppression lowers the baseline
- **WHEN** a pull request removes a suppression and leaves the baseline unchanged
- **THEN** the step fails, naming the service and the lower count to commit
- **AND** it passes once the baseline holds that count

#### Scenario: [repo-rules-fb5bf1] Generated code is not counted
- **WHEN** a suppression appears only in generated code
- **THEN** the counts are unchanged and the step passes

### Requirement: Shared files carry no personal home paths
The pre-commit hook and CI SHALL reject a personal home-directory path, `/Users/<name>`, `/home/<name>` or `<drive>:\Users\<name>`, in the files every teammate's agent reads, naming the file, the line and the fix: `openspec/` except archived changes, every `AGENTS.md`, `CLAUDE.md` and `GEMINI.md`, `docs/` and the hand-written skills. The hook refuses a commit that stages one; CI fails on one.

#### Scenario: [repo-rules-72a7e8] A commit adding a home path is refused
- **WHEN** a commit stages an `openspec/changes/<change>/tasks.md` line that names a file under `/Users/` followed by a real user name, such as alice's `notes.md`
- **THEN** the pre-commit hook refuses the commit, naming the file, the line and the path
- **AND** says to name the file relative to the repository or describe where it came from

#### Scenario: [repo-rules-c20195] CI fails on a home path in a tracked file
- **WHEN** CI's repo checks run on a tree whose `AGENTS.md` names a file under `/home/` followed by a real user name
- **THEN** the `home-paths` step fails, naming `AGENTS.md`, the line and the path

#### Scenario: [repo-rules-d539ba] Paths that are not personal homes pass
- **WHEN** the files in scope name `src/pages/home/HomePage.tsx`, the placeholder `/Users/<name>/`, or the shared `~/.factory/sessions`
- **AND** an archived change under `openspec/changes/archive/` names a server path under `/home/`
- **THEN** the check passes

### Requirement: The pre-push hook refuses force-pushes
The pre-push hook SHALL refuse a push that would replace a branch's remote commits rather than extend them, on any branch, naming the branch and saying to merge instead, while letting new branches, fast-forward pushes and deletions of other branches through.

#### Scenario: [repo-rules-dce864] A force-push is refused
- **WHEN** a branch's history was rewritten locally and `git push --force` sends it to a remote that has its old commits
- **THEN** the pre-push hook refuses the push, naming the branch and saying to merge `origin/main` instead of rewriting
- **AND** the remote branch is unchanged

#### Scenario: [repo-rules-72abe8] Fast-forward and new branches pass
- **WHEN** a push adds commits on top of the remote branch, or creates a branch the remote does not have
- **THEN** the pre-push hook lets it through

### Requirement: The pre-push hook refuses pushes to main
The pre-push hook SHALL refuse a push or deletion of `main` and print how to push on purpose, except that with `FACTORY_PUSH_PROTECTED=1` set it lets a fast-forward push to `main` through; a force-push stays refused.

#### Scenario: [repo-rules-407e29] The variable does not allow a force-push
- **WHEN** `FACTORY_PUSH_PROTECTED=1 git push --force origin HEAD:main` would replace `main`'s remote commits
- **THEN** the pre-push hook refuses the push

### Requirement: CI enforces the repository's writing conventions
CI SHALL fail, naming each file and line with the fix, when:

- a tracked file lies under `docs/superpowers/`;
- a YAML or env value is a quoted number that reads back as the same number unquoted, unless its line marks it `# string: <reason>`;
- an `AGENTS.md`, a hand-written skill or the OpenSpec schema runs a `gh` command other than `gh api` without `-R "$(bin/repo)"`.

#### Scenario: [repo-rules-64e3da] Superpowers output outside the change fails
- **WHEN** the tree has `docs/superpowers/specs/2026-11-06-topic-design.md`
- **THEN** the `conventions` step fails and says to write designs to the change's `design.md` and plans to its `tasks.md`

#### Scenario: [repo-rules-4451ca] A quoted number fails
- **WHEN** a tracked YAML file has `MAX_TOKENS: "2000"`
- **THEN** the `conventions` step fails, naming the file and line and saying to write the number unquoted

#### Scenario: [repo-rules-32d0c8] Values YAML would misread stay quoted
- **WHEN** tracked YAML files have `code: "0123"`, `python-version: "3.10"`, `port: 8080` and `user: "1000" # string: Compose requires a string`
- **THEN** the quoted-number rule passes

#### Scenario: [repo-rules-336b7d] A gh command without -R fails
- **WHEN** a hand-written skill says to run `gh pr view 12 --json body`
- **THEN** the `conventions` step fails, naming the skill and line and saying to pass `-R "$(bin/repo)"`

#### Scenario: [repo-rules-831c64] gh api and -R pass
- **WHEN** `AGENTS.md` runs `gh issue view 12 -R "$(bin/repo)"` and `gh api repos/"$(bin/repo)"/pulls`
- **THEN** the `gh` rule passes

### Requirement: Commit subject text is sentence case
After the prefix, a commit subject SHALL have an optional lowercase `<scope>: `, then text starting with an uppercase letter.

#### Scenario: [repo-rules-3adb07] Scoped sentence-case subject passes
- **WHEN** the subject is `[12][a3f9c1] api: Reject expired tokens` on branch `12-a3f9c1-tokens`
- **THEN** the subject check passes

#### Scenario: [repo-rules-0f67af] Lowercase description is rejected
- **WHEN** the subject is `[12] add tokens` or `[12] api: reject tokens` on branch `12-tokens`
- **THEN** the subject check fails

### Requirement: A commit subject is at most 72 characters
A whole commit subject SHALL be at most 72 characters.

#### Scenario: [repo-rules-5c481b] Overlong subject is rejected
- **WHEN** the subject is 73 characters long and otherwise valid
- **THEN** the subject check fails and reports the length limit
- **AND** a 72-character subject passes

### Requirement: AGENTS.md describes the single-branch flow
`AGENTS.md` SHALL describe the single-branch flow for a multi-change issue, without mentioning `gh stack`.

#### Scenario: [repo-rules-fbb29c] AGENTS.md runs a multi-change issue on one branch
- **WHEN** `AGENTS.md` is read
- **THEN** it says an issue's changes share one branch and one PR, and no line of it mentions `gh stack`

### Requirement: Text read on stdin is checked for home paths
`bin/check-home-paths.sh -` SHALL fail on text read from standard input that holds a personal home-directory path, inside a `file://` URL too, naming the line and the path.

#### Scenario: [repo-rules-98a0c5] Text with a home path fails
- **WHEN** text piped to `bin/check-home-paths.sh -` names a screenshot under `/Users/` followed by a real user name
- **THEN** the check fails, naming `<stdin>`, the line and the path

### Requirement: AGENTS.md forbids loosening a check to pass
`AGENTS.md`'s Definition of done SHALL forbid editing a test, a scenario exclusion, a ratchet or a suppression file to make a check pass, and tell the agent to stop and report instead.

#### Scenario: [repo-rules-e74c70] AGENTS.md forbids loosening a check
- **WHEN** `AGENTS.md` is read
- **THEN** its Definition of done forbids editing a test, a `NO E2E` exclusion, a ratchet or a suppression file to make a check pass and says to stop and report
- **AND** `.claude/skills/work-pr/SKILL.md` refers to that rule instead of restating it

### Requirement: No service tracks a lint suppressions file
CI SHALL fail while any `eslint-suppressions.json` under `services/` is tracked, naming each such file.

#### Scenario: [repo-rules-d4605b] A tracked suppressions file fails CI
- **WHEN** a branch commits an `eslint-suppressions.json` in a service
- **THEN** the `lint-disables` step fails, naming the file's path and saying to fix the violations and delete it

#### Scenario: [repo-rules-7efca0] A repository without a suppressions file passes
- **WHEN** no `eslint-suppressions.json` is tracked under `services/` and every inline suppression count matches its baseline
- **THEN** the `lint-disables` step passes

### Requirement: Marked clones never grow
CI SHALL fail when a service's count of `jscpd:ignore-start` marks in tracked code, excluding generated code, differs from its line in `bin/duplicate-disables.txt`.

#### Scenario: [repo-rules-925e9d] A new marked clone fails CI
- **WHEN** a pull request adds a `jscpd:ignore-start` mark to a service without raising its baseline
- **THEN** the `duplicate-disables` step of `repo-checks` fails, naming the service, its count and baseline, and each mark's file and line
- **AND** the step passes once the baseline is raised in the same pull request

#### Scenario: [repo-rules-0caa12] A removed mark lowers the baseline
- **WHEN** a pull request removes a mark and leaves the baseline unchanged
- **THEN** the step fails, naming the service and the lower count to commit
- **AND** it passes once the baseline holds that count

#### Scenario: [repo-rules-a36de1] Marks in generated code are not counted
- **WHEN** a `jscpd:ignore-start` mark appears only in generated code
- **THEN** the counts are unchanged and the step passes

### Requirement: Unused-code exceptions never grow
CI SHALL fail when a service's count of unused-code exception marks (`@knipignore`, `// knipignore:`, and the `@public` and `@beta` tags the checker also obeys) in tracked code and configuration, excluding generated code, differs from its line in `bin/unused-disables.txt`.

#### Scenario: [repo-rules-69f853] A new unused-code exception fails CI
- **WHEN** a pull request adds a `knipignore` mark, or a `@public` or `@beta` tag, to a service without raising its baseline
- **THEN** the `unused-disables` step of `repo-checks` fails, naming the service, its count and baseline, and each mark's file and line
- **AND** the step passes once the baseline is raised in the same pull request

#### Scenario: [repo-rules-ba4550] A removed exception lowers the baseline
- **WHEN** a pull request removes a `knipignore` mark and leaves the baseline unchanged
- **THEN** the step fails, naming the service and the lower count to commit
- **AND** it passes once the baseline holds that count

### Requirement: Import-rule exceptions never grow
CI SHALL fail when a service's count of `import-exception` marks in tracked code and configuration, excluding generated code, differs from its line in `bin/import-disables.txt`.

#### Scenario: [repo-rules-42b923] A new import-rule exception fails CI
- **WHEN** a pull request adds an `import-exception` mark to a service without raising its baseline
- **THEN** the `import-disables` step of `repo-checks` fails, naming the service, its count and baseline, and each mark's file and line
- **AND** the step passes once the baseline is raised in the same pull request

#### Scenario: [repo-rules-c362cb] A removed exception lowers the baseline
- **WHEN** a pull request removes an `import-exception` mark and leaves the baseline unchanged
- **THEN** the step fails, naming the service and the lower count to commit
- **AND** it passes once the baseline holds that count

### Requirement: A failing range check never advises a force-push
When the commit-range check fails, its advice SHALL say that rewriting pushed commits is a human's call and name no force-push.

#### Scenario: [repo-rules-9cdb65] The advice is to ask a human
- **WHEN** the range check fails on a malformed subject
- **THEN** its output says to ask a human before rewording pushed commits and holds neither `force-push` nor `--force`

### Requirement: The newline check reads paths literally
The newline check SHALL treat every path it is given as a literal file name, never as a pattern.

#### Scenario: [repo-rules-2c7244] A glob-like path that is not staged is skipped
- **WHEN** `bin/check-eof-newline.sh --staged '*.txt'` runs while `a.txt` is staged with a final newline and no file is named `*.txt`
- **THEN** it exits 0 without an error

### Requirement: bin/repo reads any origin that reaches GitHub
`bin/repo` SHALL print `<owner>/<repo>` for an origin URL whose host is `github.com` or `ssh.github.com` after dropping any port, or an SSH host alias that `ssh -G` resolves to either.

#### Scenario: [repo-rules-21cc49] An SSH host alias is resolved
- **WHEN** origin is `git@gh-work:o/r.git` and `ssh -G gh-work` reports `hostname github.com`
- **THEN** `bin/repo` prints `o/r`

#### Scenario: [repo-rules-abe2d1] A port is ignored
- **WHEN** origin is `ssh://git@github.com:22/o/r.git`, `ssh://git@ssh.github.com:443/o/r.git` or `https://github.com:443/o/r`
- **THEN** `bin/repo` prints `o/r`

#### Scenario: [repo-rules-78e066] An alias for another host still fails
- **WHEN** origin is `git@work:o/r.git` and `ssh -G work` reports `hostname gitlab.com`
- **THEN** `bin/repo` exits 1 saying origin is not a GitHub repository

### Requirement: Equivalent-mutant markers never grow
CI SHALL fail when a service's count of equivalent-mutant markers (`// Stryker disable next-line <mutator>: <reason>`) in tracked code, tests included and generated code excluded, differs from its line in `bin/mutation-disables.txt`.

#### Scenario: [repo-rules-b0b547] A new marker fails CI
- **WHEN** a pull request adds an equivalent-mutant marker to a service without raising its baseline
- **THEN** the `mutation-disables` step of `repo-checks` fails, naming the service, its count and baseline, and each marker's file and line
- **AND** the step passes once the baseline is raised in the same pull request

#### Scenario: [repo-rules-76b314] A removed marker lowers the baseline
- **WHEN** a pull request removes a marker and leaves the baseline unchanged
- **THEN** the step fails, naming the service and the lower count to commit
- **AND** it passes once the baseline holds that count

#### Scenario: [repo-rules-cdf0be] Markers in generated code are not counted
- **WHEN** a marker appears only in generated code, or in a file that is not tracked
- **THEN** the counts are unchanged and the step passes

### Requirement: An equivalent-mutant marker names its mutator and reason
The `mutation-disables` step SHALL fail on any Stryker disable comment in tracked service code that is not `// Stryker disable next-line <mutator>[,<mutator>...]: <reason>`: one without `next-line`, without a named mutator, naming `all`, or without a reason.

#### Scenario: [repo-rules-3e3d9b] A marker in another form is rejected
- **WHEN** a tracked service file holds `// Stryker disable all`, a marker naming no mutator, one naming `all`, one without `next-line`, or one without a reason
- **THEN** the `mutation-disables` step fails and names the file and line of each, saying the one form to use

#### Scenario: [repo-rules-8ccd75] Markers in the one form pass
- **WHEN** every Stryker disable comment is in the one form, in source or tests, and the baseline holds their count
- **THEN** the `mutation-disables` step passes

### Requirement: Every image is pinned by digest
CI SHALL fail any image reference in the tracked Dockerfiles, Compose files, workflows, `bin/` scripts and end-to-end scripts (`bin/tests/*.e2e.sh`) that does not carry its tag and a `@sha256:` digest of 64 hex digits, naming its file and line and how to resolve the digest.

#### Scenario: [repo-rules-a7ca79] A tag-only image fails the check
- **WHEN** a Dockerfile has `FROM oven/bun:1.4.3`, or a Compose file `image: postgres:17-alpine`, or a workflow `docker run` a tag-only image
- **THEN** the image-digests check fails naming that file and line and the command that resolves the digest

#### Scenario: [repo-rules-848a03] An end-to-end script's image is checked
- **WHEN** `bin/tests/db.e2e.sh` assigns `postgres_image=postgres:17-alpine`
- **THEN** the image-digests check fails naming that file and line, and a `bin/tests/*.test.sh` fixture is not checked

#### Scenario: [repo-rules-c1528d] Pinned references pass
- **WHEN** every image reference is `<name>:<tag>@sha256:<64 hex digits>`
- **THEN** the image-digests check passes

#### Scenario: [repo-rules-8470e0] Build stages and scratch are not images
- **WHEN** a Dockerfile has `FROM base AS runtime` naming an earlier stage, or `FROM scratch`
- **THEN** the image-digests check does not report them

#### Scenario: [repo-rules-02a22a] A malformed digest fails
- **WHEN** a reference carries `@sha256:` followed by fewer than 64 hex digits
- **THEN** the image-digests check fails naming that file and line

### Requirement: The repository ships a licence
The repository root SHALL hold a `LICENSE` file with the MIT licence text.

#### Scenario: [repo-rules-b5a737] The licence is MIT
- **WHEN** the root `LICENSE` is read
- **THEN** it holds the MIT licence with a copyright line

### Requirement: The README guides a newcomer
The repository root SHALL hold a `README.md` that explains the idea and the flow of a change, installs the tools and the stack step by step with `bin/doctor`, `bin/setup`, `bin/up` and `bin/down`, starts the first issue with `/work`, and maps the repository with a study guide whose links all resolve.

#### Scenario: [repo-rules-5af1ca] The README guides a newcomer
- **WHEN** the root `README.md` is read
- **THEN** it has the sections The idea, How a change flows, Installation, Your first issue, Repository map and Study guide, names `bin/doctor`, `bin/setup`, `bin/up`, `bin/down` and `/work`, and every relative link points at a file or folder of the repository

### Requirement: The security policy asks for private reports
The repository root SHALL hold a `SECURITY.md` that asks for vulnerabilities to be reported privately through GitHub's vulnerability reporting, not in a public issue.

#### Scenario: [repo-rules-e58ddd] The security policy points at private reporting
- **WHEN** the root `SECURITY.md` is read
- **THEN** it points at GitHub's private vulnerability reporting and asks not to open a public issue
