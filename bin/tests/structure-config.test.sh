# shellcheck shell=bash disable=SC2154,SC2153
# Every service with a checks target carries the same duplication, unused-code
# and import settings: a whole file, or the block between two markers of it.

# The shared part of <root>/services/<service>/<file>: the whole file, or the
# lines from the line containing <start> to the line containing <end>.
shared_part() {
  local root="$1" service="$2" file="$3" start="${4:-}" end="${5:-}"
  local path="$root/services/$service/$file"
  [ -f "$path" ] || return 0
  if [ -z "$start" ]; then cat "$path"; return; fi
  awk -v start="$start" -v end="$end" 'index($0, start) { on = 1 } on { print } on && index($0, end) { exit }' "$path"
}

# Prints "<service>: <file> ..." for each service of <root> with a checks
# target whose shared part is missing or differs from backend's.
config_differences() {
  local root="$1" file="$2" start="${3:-}" end="${4:-}" reference dockerfile service part
  reference="$(shared_part "$root" backend "$file" "$start" "$end")"
  [ -n "$reference" ] || { echo "backend: no shared part in $file"; return; }
  for dockerfile in "$root"/services/*/Dockerfile; do
    grep -qE '^FROM .* AS checks$' "$dockerfile" || continue
    service="${dockerfile%/Dockerfile}"
    service="${service##*/}"
    part="$(shared_part "$root" "$service" "$file" "$start" "$end")"
    if [ -z "$part" ]; then
      echo "$service: no shared part in $file"
    elif [ "$part" != "$reference" ]; then
      echo "$service: $file differs from backend's"
    fi
  done
}

# Copies the repository's checks services' configs into $REPO.
copy_services() {
  local file dockerfile service
  for dockerfile in "$ROOT"/services/*/Dockerfile; do
    service="${dockerfile%/Dockerfile}"
    service="${service##*/}"
    mkdir -p "$REPO/services/$service"
    cp "$dockerfile" "$REPO/services/$service/"
    for file in "$@"; do
      [ ! -f "$ROOT/services/$service/$file" ] || cp "$ROOT/services/$service/$file" "$REPO/services/$service/"
    done
  done
}

# [service-checks-c5bf46]
test_service_checks_c5bf46_duplication_settings_are_identical() {
  local differences
  differences="$(config_differences "$ROOT" .jscpd.json)"
  [ -z "$differences" ] || fail "$differences"
  copy_services .jscpd.json
  sed -i.bak 's/"minTokens": 50/"minTokens": 30/' "$REPO/services/ui/.jscpd.json"
  differences="$(config_differences "$REPO" .jscpd.json)"
  [[ "$differences" == *"ui: .jscpd.json differs from backend's"* ]] || fail "a changed threshold passed: $differences"
  rm "$REPO/services/ui/.jscpd.json"
  differences="$(config_differences "$REPO" .jscpd.json)"
  [[ "$differences" == *"ui: no shared part in .jscpd.json"* ]] || fail "a missing config passed: $differences"
}

# [service-checks-09dab7]
test_service_checks_09dab7_unused_rules_are_identical() {
  local differences
  differences="$(config_differences "$ROOT" knip.config.ts unused-rules:start unused-rules:end)"
  [ -z "$differences" ] || fail "$differences"
  copy_services knip.config.ts
  sed -i.bak 's/ignoreExportsUsedInFile: false/ignoreExportsUsedInFile: true/' "$REPO/services/ui/knip.config.ts"
  differences="$(config_differences "$REPO" knip.config.ts unused-rules:start unused-rules:end)"
  [[ "$differences" == *"ui: knip.config.ts differs from backend's"* ]] || fail "a changed rule passed: $differences"
  sed -i.bak '/unused-rules:start/d' "$REPO/services/ui/knip.config.ts"
  differences="$(config_differences "$REPO" knip.config.ts unused-rules:start unused-rules:end)"
  [[ "$differences" == *"ui: no shared part in knip.config.ts"* ]] || fail "a missing block passed: $differences"
}

# [service-checks-396ebd]
test_service_checks_396ebd_shared_import_rules_are_identical() {
  local differences
  differences="$(config_differences "$ROOT" .dependency-cruiser.mjs import-rules:start import-rules:end)"
  [ -z "$differences" ] || fail "$differences"
  copy_services .dependency-cruiser.mjs
  sed -i.bak 's/name: "src-not-to-tests"/name: "src-to-tests"/' "$REPO/services/ui/.dependency-cruiser.mjs"
  differences="$(config_differences "$REPO" .dependency-cruiser.mjs import-rules:start import-rules:end)"
  [[ "$differences" == *"ui: .dependency-cruiser.mjs differs from backend's"* ]] || fail "a changed rule passed: $differences"
  rm "$REPO/services/ui/.dependency-cruiser.mjs"
  differences="$(config_differences "$REPO" .dependency-cruiser.mjs import-rules:start import-rules:end)"
  [[ "$differences" == *"ui: no shared part in .dependency-cruiser.mjs"* ]] || fail "a missing config passed: $differences"
}

# [service-checks-c5bf46] [service-checks-09dab7] [service-checks-396ebd]: the
# gate scripts carry the scan scope, the config path and the fix hint, so they
# are the same in every service too.
test_gate_scripts_are_identical() {
  local root="$ROOT" gate dockerfile service reference script
  for gate in duplicates unused imports; do
    reference="$(grep "\"$gate\":" "$root/services/backend/package.json")"
    [ -n "$reference" ] || fail "backend has no $gate script"
    for dockerfile in "$root"/services/*/Dockerfile; do
      grep -qE '^FROM .* AS checks$' "$dockerfile" || continue
      service="${dockerfile%/Dockerfile}"
      service="${service##*/}"
      script="$(grep "\"$gate\":" "$root/services/$service/package.json" || true)"
      [ "$script" = "$reference" ] || fail "$service: its $gate script differs from backend's"
    done
  done
}
