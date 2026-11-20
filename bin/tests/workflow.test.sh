# shellcheck shell=bash disable=SC2016 # literal backticks of markdown commands
# The workflow instructions: the /work, /ticket, /work-pr and /crm-backlog skills ship to
# every copy of the template, so they name no repository and send every gh
# command to the one bin/repo prints.

SKILLS=".claude/skills/work/SKILL.md .claude/skills/ticket/SKILL.md .claude/skills/work-pr/SKILL.md .claude/skills/crm-backlog/SKILL.md .claude/skills/factory/SKILL.md"

test_skills_name_no_literal_repository() {
  local file
  for file in $SKILLS; do
    [ -f "$ROOT/$file" ] || fail "$file missing"
    ! grep -nE -- '(-R|--repo)[ =]+[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' "$ROOT/$file" || fail "$file names a repository"
    ! grep -nE 'github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/' "$ROOT/$file" || fail "$file links a repository"
  done
}

test_ticket_skill_files_with_the_repo_helper() {
  grep -qF 'gh issue create -R "$(bin/repo)"' "$ROOT/.claude/skills/ticket/SKILL.md" \
    || fail 'the ticket skill does not file with gh issue create -R "$(bin/repo)"'
}

test_instructions_name_bin_spec() {
  local file
  for file in openspec/schemas/factory/schema.yaml .claude/skills/work/SKILL.md; do
    grep -qF 'bin/spec show' "$ROOT/$file" || fail "$file does not name bin/spec show"
    grep -qF 'bin/spec changed' "$ROOT/$file" || fail "$file does not name bin/spec changed"
  done
}

test_skills_name_no_issue_of_this_repository() {
  local file
  for file in $SKILLS AGENTS.md; do
    ! grep -nE '(issue|PR|pull request) #[0-9]+' "$ROOT/$file" || fail "$file names an issue number"
  done
}

# The repo-checks job runs every workflow check, each after an earlier failure.
test_ci_runs_the_workflow_checks() {
  local checks="$ROOT/.github/workflows/checks.yml" step script
  grep -qE '^      - uses: actions/setup-node@[0-9a-f]{40} # v' "$checks" || fail 'setup-node is not pinned by SHA'
  grep -qE '^          node-version: 24$' "$checks" || fail 'Node is not 24'
  for step in openspec-validate change-archived claude-plugins spec-coverage spec-obligations; do
    grep -A1 -E "^      - name: $step\$" "$checks" | grep -qF '!cancelled()' || fail "$step missing or skipped after a failure"
  done
  grep -qF 'bin/openspec validate --all --strict' "$checks" || fail 'specs are not validated strictly'
  grep -qF 'bin/openspec validate --archived' "$checks" || fail 'archived changes are not validated'
  grep -A1 -E '^      - name: change-archived$' "$checks" | grep -qF "github.event_name == 'pull_request'" \
    || fail 'change-archived runs outside pull requests'
  grep -qF 'bin/ci-change-archived.sh "$PR" "$HEAD_REF"' "$checks" || fail 'change-archived does not run its script'
  grep -qF 'bin/check-spec-obligations.sh --base "$BASE_SHA"' "$checks" || fail 'spec-obligations ignores the base'
  ! grep -qF 'check-spec-coverage.sh --base' "$checks" || fail 'spec-coverage takes no --base'
  for script in bin/openspec bin/openspec-archive bin/spec bin/issue-start bin/issue-trust bin/factory-graph bin/factory-merge; do
    grep -E '^        run: docker run .*shellcheck' "$checks" | grep -qF " $script " || fail "shellcheck skips $script"
  done
}

# [ci-3c9837] [ci-a31d7f] The eof-newline step hands the pull request's or the
# push's range to its script, which checks every tracked file without a base.
test_ci_eof_newline_runs_its_script() {
  grep -qF 'run: bin/ci-eof-newline.sh "${BASE_SHA:-$BEFORE}" "${HEAD_SHA:-$GITHUB_SHA}"' "$ROOT/.github/workflows/checks.yml" \
    || fail 'eof-newline does not run bin/ci-eof-newline.sh'
}

# [ci-5c3c03] The backend's gates run in CI through the reusable workflow.
test_ci_5c3c03_backend_gates_run_in_ci() {
  local checks="$ROOT/.github/workflows/checks.yml" reusable="$ROOT/.github/workflows/service-check.yml" job
  [ -f "$reusable" ] || fail 'no .github/workflows/service-check.yml'
  job="$(awk '/^  backend-checks:$/ { on = 1; print; next } on && /^  [a-z]/ { exit } on' "$checks")"
  [ -n "$job" ] || fail 'checks.yml has no backend-checks job'
  [[ "$job" == *"uses: ./.github/workflows/service-check.yml"* ]] || fail "backend-checks does not call service-check.yml: $job"
  [[ "$job" == *"service: backend"* ]] || fail "backend-checks does not pass service: backend: $job"
  grep -q '^  workflow_call:$' "$reusable" || fail 'service-check.yml is not a reusable workflow'
  grep -A3 '^      service:$' "$reusable" | grep -q 'required: true' || fail 'service-check.yml does not require a service input'
  grep -A3 '^      service:$' "$reusable" | grep -q 'type: string' || fail 'the service input is not a string'
  grep -q 'runs-on: ubuntu-24.04' "$reusable" || fail 'service-check.yml does not run on ubuntu-24.04'
  grep -q 'timeout-minutes: 10' "$reusable" || fail 'service-check.yml has no 10-minute timeout'
  grep -q 'ref: ${{ github.event.pull_request.head.sha || github.sha }}' "$reusable" || fail 'service-check.yml does not check out the head commit'
  grep -q 'run: bin/check "$SERVICE"' "$reusable" || fail 'service-check.yml does not run bin/check "$SERVICE"'
}

# The lines of <job> in checks.yml, up to the next job.
checks_job() {
  awk -v job="  $1:" '$0 == job { on = 1; print; next } on && /^  [a-z]/ { exit } on' "$ROOT/.github/workflows/checks.yml"
}

# [ci-68ac38] repo-checks runs the expand-only check always, and the immutable
# check against the pull request's base.
test_ci_68ac38_repo_checks_run_the_migration_checks() {
  local step
  step="$(awk '/^      - name: migrations$/ { on = 1; print; next } on && /^      - / { exit } on' "$ROOT/.github/workflows/checks.yml")"
  [ -n "$step" ] || fail 'repo-checks has no migrations step'
  [[ "$step" == *'!cancelled()'* ]] || fail 'the migrations step is skipped after a failure'
  [[ "$step" == *'bin/check-migrations-expand-only.sh'* ]] || fail 'the migrations step does not run the expand-only check'
  [[ "$step" == *'if [ "$GITHUB_EVENT_NAME" = pull_request ]'*'bin/check-migrations-immutable.sh "$BASE_SHA" "$HEAD_SHA"'* ]] ||
    fail 'the immutable check does not run on pull requests against the base'
  [[ "$step" == *'BASE_SHA: ${{ github.event.pull_request.base.sha }}'* ]] || fail 'the migrations step has no base'
}

# [ci-e699ce] A db-migrate-proof job runs the Postgres proof, and a cancelled
# job still removes what it started.
test_ci_e699ce_the_postgres_proof_runs_in_ci() {
  local job
  job="$(checks_job db-migrate-proof)"
  [ -n "$job" ] || fail 'checks.yml has no db-migrate-proof job'
  [[ "$job" == *'runs-on: ubuntu-24.04'* ]] || fail 'db-migrate-proof does not run on ubuntu-24.04'
  [[ "$job" == *'run: bin/tests/db-migrate.e2e.sh'* ]] || fail 'db-migrate-proof does not run the proof'
  [[ "$job" == *'if: always()'*'factory-db-proof-'* ]] || fail 'db-migrate-proof has no always-run cleanup'
}

# [ci-ba1f03] A check-offline-proof job runs bin/check against real Docker,
# and a cancelled job still removes what it started.
test_ci_ba1f03_the_offline_proof_runs_in_ci() {
  local job
  job="$(checks_job check-offline-proof)"
  [ -n "$job" ] || fail 'checks.yml has no check-offline-proof job'
  [[ "$job" == *'runs-on: ubuntu-24.04'* ]] || fail 'check-offline-proof does not run on ubuntu-24.04'
  [[ "$job" == *'timeout-minutes: 10'* ]] || fail 'check-offline-proof has no 10-minute timeout'
  [[ "$job" == *'run: bin/tests/check-offline.e2e.sh'* ]] || fail 'check-offline-proof does not run the proof'
  [[ "$job" == *'if: always()'*'factory-check-'* ]] || fail 'check-offline-proof has no always-run cleanup'
}

# [ci-0ff7ea] The ui's gates run in CI through the reusable workflow.
test_ci_0ff7ea_ui_gates_run_in_ci() {
  local job
  job="$(checks_job ui-checks)"
  [ -n "$job" ] || fail 'checks.yml has no ui-checks job'
  [[ "$job" == *"uses: ./.github/workflows/service-check.yml"* ]] || fail "ui-checks does not call service-check.yml: $job"
  [[ "$job" == *"service: ui"* ]] || fail "ui-checks does not pass service: ui: $job"
}

# A ui-static-proof job proves the ui's runtime image, and a cancelled job still
# removes what it started.
test_ci_runs_the_ui_static_proof() {
  local job
  job="$(checks_job ui-static-proof)"
  [ -n "$job" ] || fail 'checks.yml has no ui-static-proof job'
  [[ "$job" == *'runs-on: ubuntu-24.04'* ]] || fail 'ui-static-proof does not run on ubuntu-24.04'
  [[ "$job" == *'timeout-minutes: 10'* ]] || fail 'ui-static-proof has no 10-minute timeout'
  [[ "$job" == *'run: bin/tests/ui-static.e2e.sh'* ]] || fail 'ui-static-proof does not run the proof'
  [[ "$job" == *'if: always()'*'factory-ui-proof-'* ]] || fail 'ui-static-proof has no always-run cleanup'
}

# A contracts-proof job runs bin/contracts generate on a copy of the
# repository and requires no change.
test_ci_runs_the_contracts_proof() {
  local job
  job="$(checks_job contracts-proof)"
  [ -n "$job" ] || fail 'checks.yml has no contracts-proof job'
  [[ "$job" == *'runs-on: ubuntu-24.04'* ]] || fail 'contracts-proof does not run on ubuntu-24.04'
  [[ "$job" == *'timeout-minutes: 10'* ]] || fail 'contracts-proof has no 10-minute timeout'
  [[ "$job" == *'run: bin/tests/contracts.e2e.sh'* ]] || fail 'contracts-proof does not run the proof'
}

# bin/e2e is a repository script, so CI shellchecks it.
test_shellcheck_covers_bin_e2e() {
  grep -E '^        run: docker run .*shellcheck' "$ROOT/.github/workflows/checks.yml" | grep -qF ' bin/e2e ' \
    || fail 'shellcheck skips bin/e2e'
}

# [ci-fbf59d] The description workflow runs ui-proof and pr-body beside
# review-section, so an edited description reruns them alone.
test_ci_fbf59d_description_workflow_runs_proof_and_body_checks() {
  local workflow="$ROOT/.github/workflows/pr-description.yml" job
  grep -qF 'types: [opened, edited, reopened, synchronize, ready_for_review]' "$workflow" || fail 'wrong pull request events'
  for job in ui-proof pr-body; do
    grep -qE "^  $job:\$" "$workflow" || fail "no $job job"
  done
  sed -n '/^  ui-proof:$/,/^  [a-z-]*:$/p' "$workflow" | grep -qF 'run: bin/ci-ui-proof.sh "$PR"' || fail 'ui-proof does not run its script'
  sed -n '/^  pr-body:$/,$p' "$workflow" | grep -qF 'run: bin/ci-pr-body.sh "$PR"' || fail 'pr-body does not run its script'
  sed -n '/^  pr-body:$/,$p' "$workflow" | grep -qF 'fetch-depth: 0' || fail 'pr-body checks out no history'
  sed -n '/^  pr-body:$/,$p' "$workflow" | grep -qF 'ref: ${{ github.event.pull_request.head.sha }}' || fail "pr-body does not check out the PR's head"
}

# bin/proof-markdown is a repository script, so CI shellchecks it.
test_shellcheck_covers_bin_proof_markdown() {
  grep -E '^        run: docker run .*shellcheck' "$ROOT/.github/workflows/checks.yml" | grep -qF ' bin/proof-markdown ' \
    || fail 'shellcheck skips bin/proof-markdown'
}

# job_block <job>: the job's lines in checks.yml, up to the next job.
job_block() {
  awk -v job="  $1:" '$0 == job { on = 1; print; next } on && /^  [a-z][a-z-]*:$/ { exit } on' "$ROOT/.github/workflows/checks.yml"
}

# [ci-f24772]
test_ci_f24772_e2e_gates_run_in_ci() {
  local job
  job="$(job_block e2e-gates)"
  [ -n "$job" ] || fail 'no e2e-gates job'
  for line in 'runs-on: ubuntu-24.04' 'timeout-minutes: 10' 'run: bin/e2e --gates'; do
    grep -qF "$line" <<<"$job" || fail "e2e-gates lacks: $line"
  done
}

# [ci-3bc641]
test_ci_3bc641_the_suite_runs_in_ci() {
  local job
  job="$(job_block e2e)"
  [ -n "$job" ] || fail 'no e2e job'
  for line in 'runs-on: ubuntu-24.04' 'timeout-minutes: 10' 'run: bin/tests/e2e-stack.e2e.sh'; do
    grep -qF "$line" <<<"$job" || fail "e2e lacks: $line"
  done
  grep -A1 -F 'if: always()' <<<"$job" | grep -F 'tmp/e2e-stack/*/worktree' | grep -qF 'bin/down' \
    || fail 'no always() step runs bin/down in the copied worktrees'
}

# [ci-b611c0]
test_ci_b611c0_a_failure_uploads_the_evidence() {
  local job path
  job="$(job_block e2e)"
  grep -A1 -F 'if: failure()' <<<"$job" | grep -qE 'uses: actions/upload-artifact@[0-9a-f]{40} # v' \
    || fail 'no upload on failure, pinned by SHA'
  for path in 'tmp/e2e-stack/*/report/' 'tmp/e2e-stack/*/logs/' 'tmp/e2e-stack/*/*.log' 'retention-days: 14'; do
    grep -qF "$path" <<<"$job" || fail "the upload lacks: $path"
  done
}

# [ci-384a85]
test_ci_384a85_the_e2e_jobs_build_with_the_cache() {
  local name job
  for name in e2e e2e-gates; do
    job="$(job_block "$name")"
    grep -qF 'FACTORY_BUILD_CACHE: gha' <<<"$job" || fail "$name builds without the cache"
    grep -qE 'uses: docker/setup-buildx-action@[0-9a-f]{40} # v' <<<"$job" || fail "$name sets up no Buildx builder"
    grep -qE 'uses: crazy-max/ghaction-github-runtime@[0-9a-f]{40} # v' <<<"$job" || fail "$name exposes no Actions runtime"
  done
}

# [repo-rules-b0b547] repo-checks runs the equivalent-mutant marker ratchet,
# even after an earlier step failed.
test_repo_rules_b0b547_the_mutation_disables_step_runs_in_repo_checks() {
  local step
  step="$(awk '/^      - name: mutation-disables$/ { on = 1; print; next } on && /^      - / { exit } on' "$ROOT/.github/workflows/checks.yml")"
  [ -n "$step" ] || fail 'repo-checks has no mutation-disables step'
  [[ "$step" == *'!cancelled()'* ]] || fail 'the mutation-disables step is skipped after a failure'
  [[ "$step" == *'run: bin/check-disables.sh mutations'* ]] || fail 'the mutation-disables step does not run the mutations kind'
}

mutation_workflow() { cat "$ROOT/.github/workflows/mutation.yml"; }

# [ci-f3e6f4] The mutation workflow, started by hand, mutates backend and ui on
# GitHub-hosted runners, passes the service to its run steps through env, and
# keeps each run's summary and reports even when the run fails.
test_ci_f3e6f4_mutation_runs_when_started_by_hand() {
  local workflow inline
  workflow="$(mutation_workflow)"
  [[ "$workflow" == *'workflow_dispatch:'* ]] || fail 'the mutation workflow cannot be started by hand'
  [[ "$workflow" == *'service: [backend, ui]'* ]] || fail 'the mutation workflow does not cover backend and ui'
  [[ "$workflow" == *'runs-on: ubuntu-24.04'* ]] || fail 'the mutation workflow is not on GitHub-hosted runners'
  [[ "$workflow" == *'SERVICE: ${{ matrix.service }}'* ]] || fail 'the service does not reach the run steps through env'
  [[ "$workflow" == *'set -o pipefail; bin/mutate "$SERVICE"'* ]] || fail 'the mutation job does not run bin/mutate with pipefail'
  # Every line of a run: script, from its run: key to the step's next key.
  inline="$(awk '
    /^ *(- )?run:/ { in_run = 1; indent = match($0, /[^ -]/); print; next }
    in_run && /^[[:space:]]*$/ { next }
    in_run && match($0, /[^ ]/) <= indent { in_run = 0 }
    in_run { print }
  ' "$ROOT/.github/workflows/mutation.yml" | grep -F '${{ matrix.service }}' || true)"
  [ -z "$inline" ] || fail "a run step expands the matrix inline: $inline"
  [ "$(grep -c 'if: ${{ !cancelled() }}' "$ROOT/.github/workflows/mutation.yml")" -ge 3 ] ||
    fail 'the summary, report and harness logs are not kept after a failure'
  [[ "$workflow" == *'GITHUB_STEP_SUMMARY'* ]] || fail 'the run does not write its summary'
  [[ "$workflow" == *'path: tmp/mutate/${{ matrix.service }}/'* ]] || fail 'the reports are not uploaded'
}

# [ci-4d3abd] The mutation workflow's only trigger is workflow_dispatch: no
# schedule, push or pull request starts it.
test_ci_4d3abd_mutation_never_starts_on_its_own() {
  local file="$ROOT/.github/workflows/mutation.yml" triggers
  ! grep -nE '^[[:space:]]*(schedule|cron):' "$file" || fail 'the mutation workflow runs on a schedule'
  triggers="$(awk '/^on:/ { on = 1; next } on && /^[^ #]/ { on = 0 } on && /^  [a-z_]+:/ { print $1 }' "$file")"
  [ "$triggers" = 'workflow_dispatch:' ] || fail "the mutation workflow has triggers other than workflow_dispatch: $triggers"
}

# [ci-e17078] The mutation workflow runs the Docker-backed proof of bin/mutate
# and keeps its logs.
test_ci_e17078_the_harness_proof_runs_with_each_mutation_run() {
  local workflow
  workflow="$(mutation_workflow)"
  [[ "$workflow" == *'run: bin/tests/mutate.e2e.sh'* ]] || fail 'the mutation workflow does not run the harness proof'
  [[ "$workflow" == *'path: tmp/mutate-proof/'* ]] || fail 'the harness proof logs are not uploaded'
}

# [ci-bebd29] Nothing but the mutation workflow runs mutation testing, and the
# instructions tell agents not to run it.
test_ci_bebd29_nothing_else_runs_mutation_testing() {
  local file
  for file in "$ROOT"/.github/workflows/*.yml "$ROOT"/.githooks/* "$BIN/check"; do
    [ "$file" != "$ROOT/.github/workflows/mutation.yml" ] || continue
    # Linting the script is not running it.
    ! grep -v shellcheck "$file" | grep -qE 'bin/mutate( |$|")|mutate\.e2e\.sh' || fail "$file runs mutation testing"
  done
  grep -q 'Do not run mutation testing (`bin/mutate`) while working' "$ROOT/AGENTS.md" ||
    fail 'AGENTS.md does not say not to run bin/mutate'
  grep -q 'Do not run `bin/mutate`' "$ROOT/.claude/skills/work/SKILL.md" ||
    fail 'the work skill does not say not to run bin/mutate'
  grep -qF 'gh workflow run mutation -R "$(bin/repo)"' "$ROOT/AGENTS.md" ||
    fail 'AGENTS.md does not say how to start a mutation run'
  "$BIN/mutate" --help | grep -qF 'gh workflow run mutation -R "$(bin/repo)"' ||
    fail 'bin/mutate --help does not say how to start a mutation run'
  for file in AGENTS.md bin/mutate bin/tests/mutate.e2e.sh services/backend/AGENTS.md services/ui/AGENTS.md \
    .claude/skills/work/SKILL.md .github/workflows/mutation.yml; do
    ! grep -niE 'nightly|every night' "$ROOT/$file" || fail "$file says mutation testing runs nightly"
  done
}

# [ci-41bb45] [ci-9e7f46] [ci-f9b512] A supply-chain job scans the run's commits
# for secrets and audits every service, each step even after the other failed.
test_ci_supply_chain_job_scans_and_audits() {
  local job
  job="$(awk '/^  supply-chain:$/ { on = 1; print; next } on && /^  [a-z]/ { exit } on' "$ROOT/.github/workflows/checks.yml")"
  [ -n "$job" ] || fail 'checks.yml has no supply-chain job'
  [[ "$job" == *'timeout-minutes: 10'* ]] || fail 'supply-chain has no 10-minute timeout'
  [[ "$job" == *'fetch-depth: 0'* ]] || fail 'supply-chain does not fetch the history it scans'
  [[ "$job" == *'- name: secret-scan'* ]] || fail 'supply-chain has no secret-scan step'
  [[ "$job" == *'run: bin/ci-secret-scan.sh "${BASE_SHA:-$BEFORE}" "${HEAD_SHA:-$GITHUB_SHA}"'* ]] || fail 'secret-scan does not scan the run'\''s range'
  [[ "$job" == *'- name: dependency-audit'* ]] || fail 'supply-chain has no dependency-audit step'
  [[ "$job" == *'run: bin/audit'* ]] || fail 'dependency-audit does not run bin/audit'
  [ "$(grep -c '!cancelled()' <<< "$job")" -ge 2 ] || fail 'a supply-chain step is skipped after the other failed'
}

test_shellcheck_covers_bin_audit() {
  grep -E '^        run: docker run .*shellcheck' "$ROOT/.github/workflows/checks.yml" | grep -qF ' bin/audit ' \
    || fail 'shellcheck skips bin/audit'
}

# [repo-rules-a7ca79] repo-checks runs the image-digests check, even after an
# earlier step failed.
test_repo_rules_image_digests_step_runs_in_repo_checks() {
  local step
  step="$(awk '/^      - name: image-digests$/ { on = 1; print; next } on && /^      - / { exit } on' "$ROOT/.github/workflows/checks.yml")"
  [ -n "$step" ] || fail 'repo-checks has no image-digests step'
  [[ "$step" == *'!cancelled()'* ]] || fail 'the image-digests step is skipped after a failure'
  [[ "$step" == *'run: bin/check-image-digests.sh'* ]] || fail 'the image-digests step does not run the check'
}

# [agent-workflow-caac0e]
test_work_skill_checks_trust_before_claiming() {
  local skill="$ROOT/.claude/skills/work/SKILL.md" trust start
  trust="$(grep -n 'bin/issue-trust <N>' "$skill" | head -1 | cut -d: -f1)"
  start="$(grep -n 'bin/issue-start <N>' "$skill" | head -1 | cut -d: -f1)"
  [ -n "$trust" ] && [ -n "$start" ] && [ "$trust" -lt "$start" ] || fail 'the work skill does not run bin/issue-trust before bin/issue-start'
  grep -qi 'untrusted data' "$skill" || fail 'the work skill does not treat an untrusted issue as data'
  grep -qE 'exits? 4' "$skill" || fail 'the work skill does not branch on exit 4'
}

# auto_section prints the "## Automatic mode" section of the work skill.
auto_section() { sed -n '/^## Automatic mode/,/^## Step/p' "$ROOT/.claude/skills/work/SKILL.md"; }

# [agent-workflow-5a5aad]
test_work_skill_has_an_automatic_mode() {
  local skill="$ROOT/.claude/skills/work/SKILL.md"
  grep -qE '^argument-hint: .*--auto' "$skill" || fail 'the work skill takes no --auto'
  [ -n "$(auto_section)" ] || fail 'the work skill has no Automatic mode section'
  grep -qi 'every mechanical gate' <<< "$(auto_section)" || fail 'automatic mode does not keep every mechanical gate'
  grep -qF '/work-pr <N> --auto' "$skill" || fail 'the work skill does not pass --auto to /work-pr'
}

# [agent-workflow-4bb91f]
test_auto_mode_records_approvals() {
  local section; section="$(auto_section)"
  for phrase in 'Mode: automatic' 'Approved by the agent in automatic mode on' "Agent's call:" 'issue comment'; do
    grep -qF -- "$phrase" <<< "$section" || fail "automatic mode does not record: $phrase"
  done
}

# [agent-workflow-debaf7]
test_auto_mode_refuses() {
  local section; section="$(auto_section)"
  for phrase in 'bin/issue-trust <N> --comments' 'untrusted-comment' 'refused' 'exits 3'; do
    grep -qF -- "$phrase" <<< "$section" || fail "automatic mode lacks: $phrase"
  done
  ! grep -qF -- '--take-over' <<< "$section" || fail 'automatic mode takes an issue over'
}

# An unattended worker never has an untrusted comment in its context: the
# trust check runs before the issue is read, and the read drops those comments.
test_auto_mode_reads_no_untrusted_comment() {
  local section; section="$(auto_section)"
  for phrase in 'before reading the issue' 'never with `--comments`' 'select(.author.login'; do
    grep -qF -- "$phrase" <<< "$section" || fail "automatic mode lacks: $phrase"
  done
}

# [agent-workflow-b160a0]
test_auto_mode_merges_main() {
  local file
  for file in .claude/skills/work/SKILL.md .claude/skills/work-pr/SKILL.md; do
    for phrase in 'git merge origin/main' 'bin/contracts generate' 'bin/check' 'bin/e2e --changed'; do
      grep -qF -- "$phrase" "$ROOT/$file" || fail "$file lacks: $phrase"
    done
    grep -qi 'never rebase' "$ROOT/$file" || fail "$file does not forbid rebasing"
  done
}

# [agent-workflow-8a3cea]
test_auto_mode_escalates() {
  local file
  for file in .claude/skills/work/SKILL.md .claude/skills/work-pr/SKILL.md; do
    grep -qF 'Escalated:' "$ROOT/$file" || fail "$file does not escalate"
    grep -qF 'three fix pushes' "$ROOT/$file" || fail "$file does not bound the fix pushes"
  done
  grep -qF 'only a human can answer' "$ROOT/.claude/skills/work/SKILL.md" || fail 'the work skill does not escalate human-only questions'
}

# [agent-workflow-8955de]
test_pr_skill_stops_at_a_ready_pr() {
  local skill="$ROOT/.claude/skills/work-pr/SKILL.md"
  grep -qE '^argument-hint: .*--auto' "$skill" || fail 'the PR skill takes no --auto'
  grep -qF 'ready: <PR URL>' "$skill" || fail 'the PR skill does not report the ready PR'
  grep -qF 'worker_done' "$skill" || fail 'the PR skill does not report through worker_done'
  grep -qi 'never merges' "$skill" || fail 'the PR skill does not forbid merging'
  sed -n '/^## Step 8/,/^## Step 9/p' "$skill" | grep -qF 'gh pr checks "$(git branch --show-current)" --watch' || fail 'the PR skill reports ready before the checks of the ready PR finish'
}

# [agent-workflow-f2180f]
test_rules_name_the_coordinator_as_the_only_merging_agent() {
  local safety
  safety="$(sed -n '/^## Safety/,/^## Improving/p' "$ROOT/AGENTS.md")"
  grep -qF '/factory' <<< "$safety" || fail 'AGENTS.md Safety does not name /factory'
  grep -qi 'every check is green' <<< "$safety" || fail 'AGENTS.md Safety does not require every check green'
  grep -qi 'workers never merge' <<< "$safety" || fail 'AGENTS.md Safety does not forbid workers to merge'
  grep -qF '/factory' "$ROOT/docs/principles.md" || fail 'the principles do not name /factory'
  grep -qi 'every check is green' "$ROOT/docs/principles.md" || fail 'the principles do not require every check green'
}

FACTORY_SKILL=".claude/skills/factory/SKILL.md"

# expect_phrases <file> <phrase>...: the file holds every phrase.
expect_phrases() {
  local file="$1" phrase
  shift
  [ -f "$ROOT/$file" ] || fail "$file missing"
  for phrase in "$@"; do
    grep -qF -- "$phrase" "$ROOT/$file" || fail "$file lacks: $phrase"
  done
}

# [agent-workflow-e2d3b3]
test_factory_skill_starts_workers() {
  expect_phrases "$FACTORY_SKILL" 'bin/factory-graph <label> --json' 'orca orchestration run-create' 'orca orchestration task-create' '--deps' \
    'orca worktree create' '--agent claude --model sonnet' 'orca orchestration worker-start --task' '/work <N> --auto' \
    'FACTORY_SESSION_SLOTS' 'bin/session list' 'untrusted' 'taken' 'cycle'
}

# A Task Orca reports ready may still wait on an issue that has no Task of the
# run: one taken by someone's /work, untrusted, on a cycle or outside the label.
test_factory_skill_starts_only_what_the_graph_calls_ready() {
  expect_phrases "$FACTORY_SKILL" 'every blocker has a Task of this run' 'the graph shows it `ready`'
}

# [agent-workflow-56ada4]
test_factory_skill_checks_auto_mode_first() {
  local doctor create
  expect_phrases "$FACTORY_SKILL" 'bin/doctor' 'auto permission mode'
  doctor="$(grep -n 'bin/doctor' "$ROOT/$FACTORY_SKILL" | head -1 | cut -d: -f1)"
  create="$(grep -n 'orca worktree create' "$ROOT/$FACTORY_SKILL" | head -1 | cut -d: -f1)"
  [ "$doctor" -lt "$create" ] || fail 'the factory skill creates a workspace before running bin/doctor'
}

# [agent-workflow-2bbde1]
test_factory_skill_merges_through_the_guard() {
  expect_phrases "$FACTORY_SKILL" 'bin/factory-merge' 'main moved' 'orca worktree rm' 'conflicting' 'behind main'
  ! grep -qF 'gh pr merge' "$ROOT/$FACTORY_SKILL" || fail 'the factory skill merges around bin/factory-merge'
}

# [agent-workflow-d7702e]
test_factory_skill_reports_status() {
  expect_phrases "$FACTORY_SKILL" 'status table' 'worker_done' 'Escalated' 'keep its workspace'
}

# [agent-workflow-e2d3b3] worker-start refuses a terminal whose agent is still
# starting (agent_unconfigured), so the skill waits for it in between.
test_factory_skill_waits_for_the_agent_before_binding() {
  local create wait start
  create="$(grep -n 'orca worktree create' "$ROOT/$FACTORY_SKILL" | head -1 | cut -d: -f1)"
  wait="$(grep -n 'orca terminal wait --terminal <handle> --for tui-idle' "$ROOT/$FACTORY_SKILL" | head -1 | cut -d: -f1)"
  start="$(grep -n 'orca orchestration worker-start --task' "$ROOT/$FACTORY_SKILL" | head -1 | cut -d: -f1)"
  [ -n "$wait" ] && [ "$create" -lt "$wait" ] && [ "$wait" -lt "$start" ] || fail 'the factory skill does not wait for the agent between creating and binding it'
  expect_phrases "$FACTORY_SKILL" 'blockedReason' 'agent_unconfigured'
}
