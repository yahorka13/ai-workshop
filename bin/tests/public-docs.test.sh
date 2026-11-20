# shellcheck shell=bash disable=SC2154
# LICENSE, README.md and SECURITY.md at the repository root.

# [repo-rules-b5a737]
test_repo_rules_b5a737_the_licence_is_mit() {
  local licence="$ROOT/LICENSE"
  [ -f "$licence" ] || fail 'no LICENSE'
  [ "$(head -n 1 "$licence")" = 'MIT License' ] || fail "LICENSE does not start with 'MIT License'"
  grep -qF 'Copyright (c) 2026 GOMAN AI' "$licence" || fail 'LICENSE has no copyright line'
  grep -qF 'Permission is hereby granted, free of charge' "$licence" || fail 'LICENSE is not the MIT text'
}

# [repo-rules-5af1ca]
test_repo_rules_5af1ca_the_readme_guides_a_newcomer() {
  local readme="$ROOT/README.md" command heading
  [ -f "$readme" ] || fail 'no README.md'
  for command in bin/doctor bin/setup bin/up bin/down /work; do
    grep -qF "$command" "$readme" || fail "README.md does not name $command"
  done
  for heading in 'The idea' 'How a change flows' 'Installation' 'Your first issue' 'Repository map' 'Study guide'; do
    grep -qx "## $heading" "$readme" || fail "README.md has no '## $heading' section"
  done
}

# Every relative link of README.md points at a file or folder of the repository.
test_readme_links_resolve() {
  local target
  grep -oE '\]\([^)#]+' "$ROOT/README.md" | sed 's/^](//' | grep -vE '^[a-z]+:' | while IFS= read -r target; do
    [ -e "$ROOT/$target" ] || fail "README.md links to a missing $target"
  done
}

# [repo-rules-e58ddd]
test_repo_rules_e58ddd_security_asks_for_private_reports() {
  local policy="$ROOT/SECURITY.md"
  [ -f "$policy" ] || fail 'no SECURITY.md'
  grep -qF 'Report a vulnerability' "$policy" || fail 'SECURITY.md does not point at private reporting'
  grep -qF 'public issue' "$policy" || fail 'SECURITY.md does not ask to avoid a public issue'
}
