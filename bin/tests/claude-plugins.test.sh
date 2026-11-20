# shellcheck shell=bash disable=SC2016 # literal backticks of markdown skill references
# Tests for .claude/settings.json, bin/check-claude-plugins.sh and
# bin/setup-claude-plugins.sh. Stub claude, orca and npx on a restricted PATH
# stand in for the real tools; each logs its arguments to $STUBS/<tool>.log.

plugins_fixture() {
  local tool file
  PROJ="$REPO/proj"
  STUBS="$REPO/stubs"
  TOOLS="$REPO/tools"
  mkdir -p "$PROJ/bin" "$PROJ/.claude" "$STUBS" "$TOOLS"
  for tool in bash sh cat grep sed awk tr cut find dirname mkdir cmp rm touch cp; do
    ln -s "$(command -v "$tool")" "$TOOLS/$tool"
  done
  for file in check-claude-plugins.sh setup-claude-plugins.sh; do
    [ ! -e "$ROOT/bin/$file" ] || cp "$ROOT/bin/$file" "$PROJ/bin/$file"
  done
  cp "$ROOT/.claude/settings.json" "$PROJ/.claude/"
  # claude: `plugin list --json` prints $STUBS/plugins.json; `plugin install`
  # fails when $STUBS/install-fails exists.
  cat > "$STUBS/claude" <<'STUB'
#!/bin/bash
dir="$(cd "$(dirname "$0")" && pwd)"
echo "claude $*" >> "$dir/claude.log"
case "$1 $2" in
  "plugin list") cat "$dir/plugins.json" 2> /dev/null || echo '[]' ;;
  "plugin install") [ ! -f "$dir/install-fails" ] ;;
esac
STUB
  # orca: `skills installed --json` prints $STUBS/skills.json; `skills install`
  # fails when $STUBS/orca-install-fails exists.
  cat > "$STUBS/orca" <<'STUB'
#!/bin/bash
dir="$(cd "$(dirname "$0")" && pwd)"
echo "orca $*" >> "$dir/orca.log"
case "$1 $2" in
  "skills installed") cat "$dir/skills.json" 2> /dev/null || echo '{"ok":true,"result":{"skills":[]}}' ;;
  "skills install") [ ! -f "$dir/orca-install-fails" ] ;;
esac
STUB
  printf '#!/bin/bash\n' > "$STUBS/npx"
  chmod +x "$STUBS/claude" "$STUBS/orca" "$STUBS/npx"
  PATH="$STUBS:$TOOLS"
}

# installed_plugins <id>:<enabled>[:<project path>]... writes what `claude plugin
# list --json` prints: a user-scope install, or a project-scope one for that path.
installed_plugins() {
  local entry id enabled path scope sep=''
  {
    echo '['
    for entry in "$@"; do
      IFS=: read -r id enabled path <<< "$entry"
      scope="$([ -n "$path" ] && echo project || echo user)"
      printf '%s  {\n    "id": "%s",\n    "scope": "%s",\n    "enabled": %s,\n    "installPath": "/cache/%s",\n' "$sep" "$id" "$scope" "$enabled" "$id"
      [ -z "$path" ] || printf '    "projectPath": "%s",\n' "$path"
      printf '    "mcpServers": {\n      "x": {\n        "command": "npx"\n      }\n    },\n    "projectEnabled": %s\n  }' "$enabled"
      sep=$',\n'
    done
    printf '\n]\n'
  } > "$STUBS/plugins.json"
}

# [agent-workflow-99ba94]
test_required_plugins_are_enabled() {
  local settings="$ROOT/.claude/settings.json" plugin
  for plugin in superpowers playwright frontend-design; do
    grep -qE "^    \"$plugin@claude-plugins-official\": true,?\$" "$settings" || fail "$plugin not enabled"
  done
  ! grep -q 'extraKnownMarketplaces' "$settings" || fail 'settings.json declares a local marketplace'
}

# [agent-workflow-e0c58f]
test_undeclared_plugin_skill_fails_the_check() {
  plugins_fixture
  printf '# Agents\n\nReview with `reviewer:deep-review` first.\n' > "$PROJ/AGENTS.md"
  expect_fail "$PROJ/bin/check-claude-plugins.sh" "$PROJ"
  expect_output 'AGENTS.md:3:'
  expect_output 'reviewer:deep-review'
}

# [agent-workflow-d0a2c7]
test_repository_names_only_declared_plugins() {
  expect_pass "$ROOT/bin/check-claude-plugins.sh" "$ROOT"
  plugins_fixture
  mkdir -p "$PROJ/openspec/schemas/factory" "$PROJ/.claude/skills/work"
  echo 'Invoke **superpowers:writing-plans**.' > "$PROJ/openspec/schemas/factory/schema.yaml"
  echo 'Sized like `superpowers:brainstorming`.' > "$PROJ/.claude/skills/work/SKILL.md"
  expect_pass "$PROJ/bin/check-claude-plugins.sh" "$PROJ"
}

# [agent-workflow-ae1460]
test_package_scripts_are_not_skills() {
  plugins_fixture
  mkdir -p "$PROJ/services/api"
  echo 'Run `test:unit` before pushing.' > "$PROJ/services/api/AGENTS.md"
  printf '{\n  "scripts": {\n    "test:unit": "bun test"\n  }\n}\n' > "$PROJ/services/api/package.json"
  expect_pass "$PROJ/bin/check-claude-plugins.sh" "$PROJ"
}

# [agent-workflow-5e93fb]
test_plugin_help_needs_nothing() {
  plugins_fixture
  rm "$STUBS/claude" "$STUBS/orca"
  expect_pass "$PROJ/bin/check-claude-plugins.sh" --help
  expect_output 'Usage: bin/check-claude-plugins.sh'
  expect_pass "$PROJ/bin/setup-claude-plugins.sh" --help
  expect_output 'Usage: bin/setup-claude-plugins.sh'
}

# [agent-workflow-8c99e3]
test_missing_plugins_are_installed() {
  plugins_fixture
  installed_plugins superpowers@claude-plugins-official:true
  cp "$PROJ/.claude/settings.json" "$REPO/settings.before"
  expect_pass "$PROJ/bin/setup-claude-plugins.sh"
  grep -qx 'claude plugin install playwright@claude-plugins-official --scope project' "$STUBS/claude.log" || fail 'playwright not installed'
  grep -qx 'claude plugin install frontend-design@claude-plugins-official --scope project' "$STUBS/claude.log" || fail 'frontend-design not installed'
  [ "$(grep -c 'plugin install' "$STUBS/claude.log")" = 2 ] || fail 'installed more than the missing plugins'
  cmp -s "$REPO/settings.before" "$PROJ/.claude/settings.json" || fail 'settings.json changed'
}

# Claude Code lists a project-scope install for every
# project; only one for this checkout counts.
# [agent-workflow-8c99e3]
test_plugin_installed_for_another_project_is_installed() {
  local here
  plugins_fixture
  here="$(cd "$PROJ" && pwd -P)"
  installed_plugins superpowers@claude-plugins-official:true:/elsewhere/worktree playwright@claude-plugins-official:true:"$here" frontend-design@claude-plugins-official:true
  expect_pass "$PROJ/bin/setup-claude-plugins.sh"
  grep -qx 'claude plugin install superpowers@claude-plugins-official --scope project' "$STUBS/claude.log" || fail 'superpowers not installed'
  [ "$(grep -c 'plugin install' "$STUBS/claude.log")" = 1 ] || fail 'installed a plugin this project has'
  [[ "$OUT" != *'loads twice'* ]] || fail "warned about another project's install"$'\n'"$OUT"
}


# [agent-workflow-9bbfb8]
test_second_run_installs_nothing() {
  plugins_fixture
  installed_plugins superpowers@claude-plugins-official:true playwright@claude-plugins-official:true frontend-design@claude-plugins-official:true
  expect_pass "$PROJ/bin/setup-claude-plugins.sh"
  ! grep -q 'plugin install' "$STUBS/claude.log" || fail 'reinstalled a plugin'
}

# [agent-workflow-3cc03d]
test_failed_install_fails_setup() {
  plugins_fixture
  touch "$STUBS/install-fails"
  expect_fail "$PROJ/bin/setup-claude-plugins.sh"
  expect_output 'superpowers@claude-plugins-official'
}

# [agent-workflow-f249f7]
test_no_claude_skips_the_plugins() {
  plugins_fixture
  rm "$STUBS/claude"
  expect_pass "$PROJ/bin/setup-claude-plugins.sh"
  expect_output 'skipping the Claude Code plugins'
}

# [agent-workflow-3a769a]
test_missing_host_binary_fails_with_the_fix() {
  plugins_fixture
  rm "$STUBS/npx"
  expect_fail "$PROJ/bin/setup-claude-plugins.sh"
  expect_output 'npx'
  expect_output 'playwright'
  expect_output 'Node.js'
  ! grep -q 'plugin install' "$STUBS/claude.log" || fail 'installed before checking host binaries'
}

# [agent-workflow-f0ecca]
test_plugin_from_another_marketplace_is_reported() {
  plugins_fixture
  installed_plugins superpowers@superpowers-marketplace:true superpowers@claude-plugins-official:true playwright@claude-plugins-official:true frontend-design@claude-plugins-official:true
  expect_pass "$PROJ/bin/setup-claude-plugins.sh"
  expect_output 'superpowers loads twice'
  expect_output 'claude plugin disable superpowers@superpowers-marketplace'
}

# [agent-workflow-17906d]
test_orca_cli_is_installed_when_missing() {
  plugins_fixture
  expect_pass "$PROJ/bin/setup-claude-plugins.sh"
  grep -qx 'orca skills install --skill orca-cli' "$STUBS/orca.log" || fail 'orca-cli not installed'
}

# [agent-workflow-7665e4]
test_installed_orca_cli_is_left_alone() {
  plugins_fixture
  printf '{\n  "ok": true,\n  "result": {\n    "skills": [\n      {\n        "id": "1a2b",\n        "name": "orca-cli"\n      }\n    ]\n  }\n}\n' > "$STUBS/skills.json"
  expect_pass "$PROJ/bin/setup-claude-plugins.sh"
  ! grep -q 'skills install ' "$STUBS/orca.log" || fail 'reinstalled orca-cli'
}

# [agent-workflow-f136ea]
test_no_orca_no_orca_cli() {
  plugins_fixture
  rm "$STUBS/orca"
  expect_pass "$PROJ/bin/setup-claude-plugins.sh"
  [[ "$OUT" != *orca-cli* ]] || fail "mentioned orca-cli without Orca"$'\n'"$OUT"
}

# [agent-workflow-b5d608]
test_failed_orca_cli_install_only_warns() {
  plugins_fixture
  touch "$STUBS/orca-install-fails"
  expect_pass "$PROJ/bin/setup-claude-plugins.sh"
  expect_output 'orca-cli is not installed'
}
