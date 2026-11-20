# shellcheck shell=bash disable=SC2154
# The e2e scripts run under `set -o pipefail`. A reader that exits early
# (`grep -q`, `head`) can make curl fail writing to the closed pipe, so a check
# would report FAIL although the match was there. These scripts capture
# curl's output first and match the captured text.

# curl_pipes <file>...: print file:line for every line that pipes curl, or a
# function of that file whose body runs curl, into a grep that stops at a
# match (-q, -m, --quiet) or `head`; fail when it prints any.
curl_pipes() {
  awk '
    FNR == 1 { split("", wraps); fn = ""; held = "" }
    # A line continued with a backslash or a trailing pipe is read as one,
    # reported at its start.
    /\\$/ || (/\|[[:space:]]*$/ && !/\|\|[[:space:]]*$/) {
      if (held == "") start = FNR
      line = $0
      if (line ~ /\\$/) line = substr(line, 1, length(line) - 1)
      held = held line " "
      next
    }
    { at = held == "" ? FNR : start }
    held != "" { $0 = held $0; held = "" }
    # A function definition: name() {, name () { or function name {.
    /^[[:space:]]*(function[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*(\(\))?[[:space:]]*\{/ &&
      (/\(\)/ || /^[[:space:]]*function[[:space:]]/) {
      fn = $0
      sub(/^[[:space:]]*(function[[:space:]]+)?/, "", fn)
      sub(/[[:space:]]*(\(\))?[[:space:]]*\{.*/, "", fn)
      oneline = $0 ~ /}[[:space:]]*$/
    }
    fn != "" && /(^|[^A-Za-z0-9_-])curl([[:space:]]|$)/ { wraps[fn] = 1 }
    {
      line = $0
      gsub(/\|\|/, "  ", line)
      n = split(line, parts, "|")
      producer = 0
      for (i = 1; i <= n; i++) {
        segment = parts[i]
        if (producer && (early_grep(segment) || segment ~ /^[[:space:]]*head([[:space:]]|$)/)) {
          print FILENAME ":" at
          found = 1
          break
        }
        if (segment ~ /(^|[^A-Za-z0-9_-])curl([[:space:]]|$)/) producer = 1
        for (w in wraps) if (segment ~ ("(^|[^A-Za-z0-9_-])" w "([[:space:]]|$)")) producer = 1
      }
    }
    # The function ends at a line of its own closing brace, or with its one line.
    fn != "" && (oneline || /^[[:space:]]*}[[:space:]]*$/) { fn = ""; oneline = 0 }
    END { exit found ? 1 : 0 }
    # grep that stops at a match: -q, -m, --quiet, --silent or --max-count.
    function early_grep(segment) {
      if (segment !~ /^[[:space:]]*grep[[:space:]]/) return 0
      return segment ~ /[[:space:]]-[A-Za-z]*[qm]/ || segment ~ /[[:space:]]--(quiet|silent|max-count)/
    }
  ' "$@"
}

test_a_curl_piped_into_grep_q_is_flagged() {
  printf '%s\n' 'set -euo pipefail' 'curl -fsS http://x/ | grep -qi "<div>" || fail body' > a.e2e.sh
  expect_fail curl_pipes a.e2e.sh
  expect_output "a.e2e.sh:2"
}

test_a_curl_helper_piped_into_head_is_flagged() {
  cat > b.e2e.sh <<'EOF'
cors() {
  local port="$1"
  curl -sS -o /dev/null -D - "http://127.0.0.1:$port/graphql" | tr -d '\r'
}
headers() { curl -fsS -D - -o /dev/null "http://x$1"; }
cors 1 | head -n 1 | grep ' 204' > /dev/null || fail preflight
headers / | grep -Eq '^expires' || fail cached
cors 1 -X OPTIONS \
  -H 'origin: x' | head -n 1 | grep -q ' 204' || fail preflight
EOF
  expect_fail curl_pipes b.e2e.sh
  expect_output "b.e2e.sh:6"
  expect_output "b.e2e.sh:7"
  expect_output "b.e2e.sh:8"
}

test_a_pipe_broken_across_lines_and_other_quiet_greps_are_flagged() {
  cat > d.e2e.sh <<'EOF'
curl -fsS http://x/ |
  grep -q '<div>' || fail body
curl -fsS http://x/ | grep --quiet '<div>' || fail body
curl -fsS http://x/ | grep -m1 '<div>' > /dev/null || fail body
fetch () {
  local url=${1}
  curl -fsS "$url"
}
fetch http://x/ | grep -qi '<div>' || fail body
EOF
  expect_fail curl_pipes d.e2e.sh
  expect_output "d.e2e.sh:1"
  expect_output "d.e2e.sh:3"
  expect_output "d.e2e.sh:4"
  expect_output "d.e2e.sh:9"
}

test_captured_output_passes() {
  cat > c.e2e.sh <<'EOF'
headers() { curl -fsS -D - -o /dev/null "http://x$1"; }
out="$(curl -fsS http://x/)"
grep -q '<div>' <<< "$out" || fail body
out="$(headers /)"
grep -qi '^cache-control' <<< "$out" || fail cached
docker exec x ls | grep -q index.html || fail listing
EOF
  expect_pass curl_pipes c.e2e.sh
}

test_the_e2e_scripts_do_not_pipe_curl_into_an_early_exit() {
  expect_pass curl_pipes "$ROOT"/bin/tests/*.e2e.sh
}
