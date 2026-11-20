# shellcheck shell=bash
# The permission rules in .claude/settings.json: unattended /work --auto
# workers run the flow without a prompt, and the commands that rewrite history,
# merge or delete stay denied (deny beats allow in Claude Code).

settings_list() { jq -r ".permissions.$1[]" "$ROOT/.claude/settings.json"; }

# [agent-workflow-49f622]
test_allowlist_covers_the_flow() {
  local allow entry
  allow="$(settings_list allow)"
  for entry in 'Bash(git *)' 'Bash(gh *)' 'Bash(bin/*)' 'Bash(orca *)' 'Edit(/**)' 'Read(/**)' 'mcp__plugin_playwright_playwright__*'; do
    grep -qxF -- "$entry" <<< "$allow" || fail "allow lacks $entry"
  done
  ! grep -qxE 'Bash|Bash\(\*\)|Bash\(:\*\)|Bash\( ?\*\)' <<< "$allow" || fail 'allow holds an unrestricted Bash entry'
}

# [agent-workflow-49f622]
test_denylist_keeps_dangerous_commands_prompting() {
  local deny entry
  deny="$(settings_list deny)"
  for entry in 'Bash(git push --force*)' 'Bash(git push -f*)' 'Bash(git push * --force*)' 'Bash(git push * -f*)' \
    'Bash(git rebase *)' 'Bash(git push origin main*)' 'Bash(gh pr merge *)' 'Bash(gh repo delete *)' \
    'Bash(gh pr merge)' 'Bash(gh api *merge*)' 'Bash(git push *--no-verify*)' 'Bash(git -c *)' \
    'Bash(git pull *--rebase*)' 'Bash(git pull -r*)' 'Bash(git pull * -r*)'; do
    grep -qxF -- "$entry" <<< "$deny" || fail "deny lacks $entry"
  done
}

test_plugins_stay_declared() {
  jq -e '.enabledPlugins["superpowers@claude-plugins-official"]' "$ROOT/.claude/settings.json" > /dev/null || fail 'the plugins are no longer declared'
}

# Installing a plugin rewrites the file with enabledPlugins last; committed in
# any other order, every bin/setup leaves the worktree dirty.
test_plugins_are_the_last_key() {
  [ "$(jq -r 'keys_unsorted | last' "$ROOT/.claude/settings.json")" = enabledPlugins ] || fail 'enabledPlugins is not the last key of .claude/settings.json'
}
